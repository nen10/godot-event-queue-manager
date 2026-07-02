#!/usr/bin/env python3
"""Contract coverage gate (EQM-110).

Verifies docs/design/EVENT_MODEL_CONTRACT_COVERAGE.md against the repo and the
implementation queue, so a frozen contract cannot silently stay unimplemented
(the v1.0 drift found by the 2026-07-02 audit):

  - status=implemented rows: every path in `implementation` and `tests` exists.
  - status=reserved rows: FAIL when ALL owning tasks are COMPLETE(_WITH_BACKLOG)
    in IMPLEMENTATION_QUEUE.md (the row must be flipped before closing the task).
  - owning tasks must exist in the queue (typo guard).

Exit codes: 0 ok, 1 violation. `--self-test` validates the detectors.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
COVERAGE_MD = REPO_ROOT / "docs/design/EVENT_MODEL_CONTRACT_COVERAGE.md"
QUEUE_MD = REPO_ROOT / "docs/plan/2026-06-09_event_queue_manager/IMPLEMENTATION_QUEUE.md"

DONE_STATUSES = {"COMPLETE", "COMPLETE_WITH_BACKLOG"}
VALID_STATUSES = {"implemented", "reserved"}
HEADER = ["contract", "SEM", "owning task", "status", "implementation", "tests"]


def log(msg: str) -> None:
    print(f"[contract-coverage] {msg}")


def parse_coverage_rows(text: str) -> list[dict]:
    rows = []
    in_table = False
    for line in text.splitlines():
        stripped = line.strip()
        if not stripped.startswith("|"):
            in_table = False
            continue
        cells = [c.strip() for c in stripped.strip("|").split("|")]
        if [c.lower() for c in cells] == [h.lower() for h in HEADER]:
            in_table = True
            continue
        if not in_table:
            continue
        if set(cells[0]) <= {"-", " "}:  # separator row
            continue
        if len(cells) != len(HEADER):
            raise ValueError(f"coverage row has {len(cells)} cells (want {len(HEADER)}): {stripped!r}")
        rows.append(dict(zip(HEADER, cells)))
    return rows


def parse_queue_statuses(text: str) -> dict[str, str]:
    statuses: dict[str, str] = {}
    for line in text.splitlines():
        m = re.match(r"^\|\s*(EQM-[\d.]+)\s*\|\s*([A-Z_]+)\s*\|", line.strip())
        if m:
            statuses[m.group(1)] = m.group(2)
    return statuses


def split_paths(cell: str) -> list[str]:
    if cell in ("—", "-", ""):
        return []
    return [p.strip() for p in re.split(r"<br\s*/?>", cell) if p.strip()]


def split_tasks(cell: str) -> list[str]:
    return [t.strip() for t in cell.split(",") if t.strip()]


def check(rows: list[dict], queue: dict[str, str], root: Path) -> list[str]:
    violations: list[str] = []
    for row in rows:
        name, status = row["contract"], row["status"]
        if status not in VALID_STATUSES:
            violations.append(f"{name}: unknown status {status!r}")
            continue
        tasks = split_tasks(row["owning task"])
        if not tasks:
            violations.append(f"{name}: no owning task")
        for t in tasks:
            if t not in queue:
                violations.append(f"{name}: owning task {t} not found in IMPLEMENTATION_QUEUE.md")
        if status == "implemented":
            paths = split_paths(row["implementation"]) + split_paths(row["tests"])
            if not split_paths(row["implementation"]):
                violations.append(f"{name}: implemented but no implementation path")
            if not split_paths(row["tests"]):
                violations.append(f"{name}: implemented but no test path")
            for p in paths:
                if not (root / p).exists():
                    violations.append(f"{name}: path does not exist: {p}")
        else:  # reserved
            known = [t for t in tasks if t in queue]
            if known and all(queue[t] in DONE_STATUSES for t in known):
                violations.append(
                    f"{name}: reserved but owning task(s) {', '.join(known)} are complete "
                    f"— flip the row to implemented (with real paths) before closing the task"
                )
    return violations


def self_test() -> int:
    queue = {"EQM-001": "COMPLETE", "EQM-111": "READY", "EQM-113": "COMPLETE"}
    ok_rows = [
        {"contract": "a", "SEM": "§3", "owning task": "EQM-001", "status": "implemented",
         "implementation": "tools/check_contract_coverage.py", "tests": "tools/test.sh"},
        {"contract": "b", "SEM": "§5", "owning task": "EQM-111", "status": "reserved",
         "implementation": "—", "tests": "—"},
    ]
    if check(ok_rows, queue, REPO_ROOT):
        log("self-test FAIL: valid rows reported violations")
        return 1
    bad_missing = [{"contract": "c", "SEM": "§3", "owning task": "EQM-001", "status": "implemented",
                    "implementation": "tools/does_not_exist.py", "tests": "tools/test.sh"}]
    if not check(bad_missing, queue, REPO_ROOT):
        log("self-test FAIL: missing implemented path not detected")
        return 1
    bad_reserved = [{"contract": "d", "SEM": "§6", "owning task": "EQM-113", "status": "reserved",
                     "implementation": "—", "tests": "—"}]
    if not check(bad_reserved, queue, REPO_ROOT):
        log("self-test FAIL: complete-but-reserved not detected")
        return 1
    header_probe = parse_coverage_rows(COVERAGE_MD.read_text(encoding="utf-8"))
    if not header_probe:
        log("self-test FAIL: coverage table not parseable")
        return 1
    log("self-test ok")
    return 0


def main(argv: list[str]) -> int:
    if "--self-test" in argv:
        return self_test()
    rows = parse_coverage_rows(COVERAGE_MD.read_text(encoding="utf-8"))
    queue = parse_queue_statuses(QUEUE_MD.read_text(encoding="utf-8"))
    if not rows:
        log("FAIL: no coverage rows parsed")
        return 1
    violations = check(rows, queue, REPO_ROOT)
    for v in violations:
        log(f"FAIL: {v}")
    implemented = sum(1 for r in rows if r["status"] == "implemented")
    log(f"rows={len(rows)} implemented={implemented} reserved={len(rows) - implemented} violations={len(violations)}")
    return 1 if violations else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
