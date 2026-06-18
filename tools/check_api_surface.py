#!/usr/bin/env python3
"""EQM layer-aware public API surface gate (EQM-023).

Extracts the public API surface of the addon (class_name + non-underscore
members), tags each class by layer (core / L0 / L1 / L2 / L3), and gates:

  * surface diff vs the golden snapshot   -> FAIL (unless --update)
  * a public class with no layer assigned  -> FAIL (assign it in LAYER_MAP)
  * an L3 class leaking into an L0/L1 public signature -> FAIL (roadmap §3.1)

Public/internal convention: public = no leading underscore (func/var); const =
UPPER_CASE; class_name-bearing files only. See docs/design/API_SURFACE.md.

Usage:
  python3 tools/check_api_surface.py             # check (read-only) -> exit 0/1
  python3 tools/check_api_surface.py --update     # re-baseline the golden (explicit)
  python3 tools/check_api_surface.py --self-test   # prove the leak detector
"""
import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
ADDON = REPO / "addons" / "event_queue_manager"
GOLDEN = REPO / "tests" / "golden" / "api_surface.json"

# Authoritative class -> layer assignment (documented in docs/design/API_SURFACE.md).
# A class_name found in the source but absent here fails the gate (assign a layer).
LAYER_MAP = {
    # core foundation
    "EQEntry": "core", "EQOrdering": "core", "EQScheduler": "core",
    "EQBackend": "core", "EQSortedArrayBackend": "core", "EQBinaryHeapBackend": "core",
    "EQSnapshot": "core", "EQTrace": "core",
    "EQError": "core", "EQValidation": "core", "EQVersion": "core", "EQRng": "core",
    "EQEffectRecord": "core", "EQEffectChunk": "core", "EQOrderExplanation": "core",
    # presentation (simulation/presentation split — must not leak into L0/L1)
    "EQPresentationEvent": "presentation",
    "EQPresentationPolicy": "presentation", "EQPresentationBuffer": "presentation",
    # ui (runtime/editor UI projections — must not leak into L0/L1)
    "EQTimelineHud": "ui", "EQDebugOverlay": "ui", "EQTimelineDock": "ui",
    "EQDebugInspector": "ui", "EQTemplateGenerator": "ui",
    # L0 turn order
    "EQRuntime": "L0", "EQActorRegistry": "L0",
    "EQActorState": "L0", "EQActionResult": "L0", "EQManager": "L0", "EQPrediction": "L0",
    "EQSaveAdapter": "L0", "EQNodeBridge": "L0",
    # L1 policy
    "EQConfig": "L1", "EQPolicy": "L1", "EQFixedRoundPolicy": "L1", "EQCTBPolicy": "L1",
    "EQEnergyPolicy": "L1", "EQWaitTurnPolicy": "L1",
    # L2 reservation
    "EQActionDefinition": "L2", "EQReservation": "L2", "EQReservationRuntime": "L2",
    "EQActionResolutionPolicy": "L2", "EQCondition": "L2", "EQTagMatcher": "L2",
    "EQTriggerEngine": "L2", "EQTransaction": "L2", "EQTriggerIndex": "L2",
    # L3 event-line: added later in Phase 5+
}

LAYERS = ["core", "L0", "L1", "L2", "L3", "presentation", "ui"]
L01_LAYERS = {"L0", "L1"}

_RE_CLASS = re.compile(r"^class_name\s+(\w+)", re.M)
_RE_FUNC = re.compile(r"^(?:@\w+\s+)?(?:static\s+)?func\s+([a-z]\w*)\s*\(([^)]*)\)\s*(->\s*[\w\.]+)?", re.M)
_RE_VAR = re.compile(r"^(?:@export\s+)?var\s+([a-z]\w*)\s*(:\s*[\w\.]+)?", re.M)
_RE_CONST = re.compile(r"^const\s+([A-Z]\w*)", re.M)
_RE_ENUM = re.compile(r"^enum\s+(\w+)", re.M)
_RE_SIGNAL = re.compile(r"^signal\s+(\w+)", re.M)


def extract(text):
    """Returns (class_name, public_surface, signature_blob) or None."""
    cm = _RE_CLASS.search(text)
    if not cm:
        return None
    methods = []
    sig_blob = []
    for m in _RE_FUNC.finditer(text):
        params = m.group(2).strip()
        ret = (m.group(3) or "").strip()
        methods.append({"name": m.group(1), "params": params, "returns": ret})
        sig_blob.append(params + " " + ret)
    varz = []
    for m in _RE_VAR.finditer(text):
        varz.append(m.group(1))
        sig_blob.append((m.group(2) or ""))
    consts = sorted(set(m.group(1) for m in _RE_CONST.finditer(text)))
    enums = sorted(set(m.group(1) for m in _RE_ENUM.finditer(text)))
    signals = sorted(set(m.group(1) for m in _RE_SIGNAL.finditer(text)))
    methods.sort(key=lambda x: (x["name"], x["params"]))
    surface = {
        "methods": methods,
        "vars": sorted(set(varz)),
        "consts": consts,
        "enums": enums,
        "signals": signals,
    }
    return cm.group(1), surface, " ".join(sig_blob)


def build(layer_map=LAYER_MAP):
    """Returns (surface_by_layer, untagged, sig_blobs_by_class)."""
    surface = {}
    untagged = []
    sig_blobs = {}
    for path in sorted(ADDON.rglob("*.gd")):
        r = extract(path.read_text())
        if r is None:
            continue
        name, public, sig = r
        layer = layer_map.get(name)
        if layer is None:
            untagged.append(name)
            continue
        surface.setdefault(layer, {})[name] = public
        sig_blobs[name] = (layer, sig)
    return surface, sorted(untagged), sig_blobs


def find_leaks(sig_blobs, layer_map=LAYER_MAP):
    """L3 class names appearing in an L0/L1 class's public signatures."""
    l3 = {c for c, l in layer_map.items() if l == "L3"}
    leaks = []
    for name, (layer, sig) in sig_blobs.items():
        if layer not in L01_LAYERS:
            continue
        for l3c in l3:
            if re.search(r"\b" + re.escape(l3c) + r"\b", sig):
                leaks.append((name, l3c))
    return sorted(leaks)


def serialize(surface):
    return json.dumps(surface, indent=2, sort_keys=True, ensure_ascii=False) + "\n"


def self_test():
    """Prove the leak detector flags an L3 symbol in an L0 signature, and is
    quiet on a clean surface. Uses synthetic data (never touches real source)."""
    fake_map = {"EQFakeLine": "L3", "EQFakeFacade": "L0"}
    # leak: an L0 facade method takes an L3 type
    leak_blobs = {"EQFakeFacade": ("L0", "x: EQFakeLine")}
    if find_leaks(leak_blobs, fake_map) != [("EQFakeFacade", "EQFakeLine")]:
        print("[api-surface] SELF-TEST FAIL: leak not detected", file=sys.stderr)
        return 1
    # clean: no L3 reference
    clean_blobs = {"EQFakeFacade": ("L0", "x: int")}
    if find_leaks(clean_blobs, fake_map) != []:
        print("[api-surface] SELF-TEST FAIL: false leak", file=sys.stderr)
        return 1
    print("[api-surface] self-test ok (leak detector verified)")
    return 0


def main(argv):
    if "--self-test" in argv:
        return self_test()

    surface, untagged, sig_blobs = build()
    ok = True

    if untagged:
        print("[api-surface] FAIL: public class(es) with no layer assigned: %s" % ", ".join(untagged), file=sys.stderr)
        print("  -> add them to LAYER_MAP in tools/check_api_surface.py and docs/design/API_SURFACE.md", file=sys.stderr)
        ok = False

    leaks = find_leaks(sig_blobs)
    if leaks:
        for cls, l3c in leaks:
            print("[api-surface] FAIL: L3 symbol '%s' leaked into %s public surface (roadmap §3.1)" % (l3c, cls), file=sys.stderr)
        ok = False

    rendered = serialize(surface)

    if "--update" in argv:
        GOLDEN.parent.mkdir(parents=True, exist_ok=True)
        GOLDEN.write_text(rendered)
        print("[api-surface] golden re-baselined: %s (record the diff in self-review)" % GOLDEN.relative_to(REPO))
        return 0 if ok else 1

    if not GOLDEN.exists():
        print("[api-surface] FAIL: golden missing (%s). Create with --update." % GOLDEN.relative_to(REPO), file=sys.stderr)
        return 1
    want = GOLDEN.read_text()
    if rendered != want:
        print("[api-surface] FAIL: public API surface differs from golden.", file=sys.stderr)
        print("  -> intended? re-baseline: python3 tools/check_api_surface.py --update (note the diff in self-review)", file=sys.stderr)
        _print_diff(want, rendered)
        ok = False

    if ok:
        print("[api-surface] ok (surface matches golden; no untagged class; no L3 leak)")
    return 0 if ok else 1


def _print_diff(want, got):
    import difflib
    diff = difflib.unified_diff(want.splitlines(), got.splitlines(), "golden", "current", lineterm="")
    for line in list(diff)[:60]:
        print("  " + line, file=sys.stderr)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
