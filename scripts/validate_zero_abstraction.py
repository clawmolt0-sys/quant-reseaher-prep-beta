#!/usr/bin/env python3
import json, sys
from pathlib import Path

BLACKLIST = [
    "problem-defined variables",
    "random variables defined in the prompt",
    "random variables defined in prompt",
    "solve for the requested quantity",
    "solve for requested quantity",
    "given numerical parameters",
]

REQUIRED_KEYS = [
    "problem_id",
    "name",
    "schema",
    "schema_text",
]
SCHEMA_KEYS = [
    "core_mathematical_domain",
    "problem_setup_entities",
    "invariant_constraints",
    "target_objective",
]

def fail(msg):
    print(f"FAIL: {msg}")
    sys.exit(1)

def main(path):
    p = Path(path)
    if not p.exists():
        fail(f"file not found: {path}")
    data = json.loads(p.read_text(encoding='utf-8-sig'))
    rows = data.get('schemas', []) if isinstance(data, dict) else data
    if not isinstance(rows, list):
        fail("top-level must be a JSON list (or object with 'schemas' list)")

    blob = json.dumps(rows, ensure_ascii=False).lower()
    hits = [x for x in BLACKLIST if x in blob]
    if hits:
        fail(f"blacklisted phrase(s) detected: {hits}")

    for i, r in enumerate(rows):
        if not isinstance(r, dict):
            fail(f"row {i} is not an object")
        for k in REQUIRED_KEYS:
            if k not in r:
                fail(f"row {i} missing key: {k}")
        s = r['schema']
        if not isinstance(s, dict):
            fail(f"row {i} schema is not object")
        for k in SCHEMA_KEYS:
            if k not in s:
                fail(f"row {i} schema missing key: {k}")

    print(f"PASS: {path} ({len(rows)} records)")

if __name__ == '__main__':
    if len(sys.argv) != 2:
        print("usage: validate_zero_abstraction.py <json-file>")
        sys.exit(2)
    main(sys.argv[1])
