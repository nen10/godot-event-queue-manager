#!/usr/bin/env python3
"""UI static audit — Pass B of UI_LAYOUT_METRIC_TEST_POLICY (§2.2).

Fast source-level scan for danger patterns that the headless layout pass (Pass A,
run_ui_metrics.gd) cannot see cheaply: boolean state rendered as text, debug
strings assigned to visible labels, float-tick formatting, generic ResourcePicker
base types. This is a *补助* (auxiliary) pass — never a substitute for Pass A.

Adoption M1-M3: report-only (exit 0). M4/M5 (EQM-094/095) flips to --enforce,
where a P0 finding fails the build. An escape hatch for declared exceptions:
append `# ui-audit-allow: <reason>` to a flagged line.

Scans addons/event_queue_manager/{editor,runtime/ui}/ but skips editor/testing/
(harness code, not shipped UI).
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
SCAN_ROOTS = [
    REPO / "addons/event_queue_manager/editor",
    REPO / "addons/event_queue_manager/runtime/ui",
]
SKIP_DIRS = {"testing"}
ALLOW = "ui-audit-allow"

# (regex, severity, metric, message)
RULES = [
    (re.compile(r'\.text\s*=\s*"(true|false|on|off|yes|no|有効|無効)"', re.IGNORECASE),
     "P0", "modality", "boolean state rendered as text (use icon/checkbox/badge)"),
    (re.compile(r'\.text\s*=\s*"[^"]*(/root/|res://|user://|NodePath\(|@EditorNode|<Object#|\bseq=|\bgen=)'),
     "P0", "debug_leakage", "debug string assigned to a visible label"),
    (re.compile(r'tick.*(%\.\d*f|%f|float\s*\(.*tick)', re.IGNORECASE),
     "P1", "debug_leakage", "tick formatted as float (float ordering must not reach the UI)"),
    (re.compile(r'(base_type|set_base_type)\s*[=(]\s*"Resource"'),
     "P1", "resource_picker", "generic ResourcePicker base_type 'Resource' (use a specific EQ type)"),
]


def gd_files():
    for root in SCAN_ROOTS:
        if not root.exists():
            continue
        for p in sorted(root.rglob("*.gd")):
            if any(part in SKIP_DIRS for part in p.relative_to(root).parts):
                continue
            yield p


def audit():
    findings = []
    scanned = 0
    for path in gd_files():
        scanned += 1
        rel = path.relative_to(REPO)
        for lineno, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            if ALLOW in line:
                continue
            for rx, sev, metric, msg in RULES:
                if rx.search(line):
                    findings.append((sev, str(rel), lineno, metric, msg, line.strip()))
    return scanned, findings


def main(argv):
    enforce = "--enforce" in argv
    scanned, findings = audit()
    p0 = sum(1 for f in findings if f[0] == "P0")
    p1 = sum(1 for f in findings if f[0] == "P1")

    print(f"[ui_static_audit] scanned {scanned} GDScript UI file(s)")
    for sev, rel, lineno, metric, msg, src in findings:
        print(f"[ui_static_audit] {sev} {rel}:{lineno} {metric} — {msg}")
        print(f"    {src}")
    mode = "enforce" if enforce else "report-only (M1-M3)"
    print(f"[ui_static_audit] P0={p0} P1={p1} mode={mode}")

    if enforce and p0 > 0:
        print("[ui_static_audit] FAIL: P0 findings under --enforce")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
