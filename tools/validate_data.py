"""Validate game content data against JSON Schema (D-034).

Each folder game/data/<kind>/ is checked against tools/schemas/<kind>.schema.json.
Usage: python tools/validate_data.py [data_dir]
"""
import json
import sys
from pathlib import Path

from jsonschema import Draft202012Validator

ROOT = Path(__file__).resolve().parent.parent
SCHEMAS = ROOT / "tools" / "schemas"


def validate(data_dir: Path) -> list[str]:
    errors = []
    ids = {}
    for path in sorted(data_dir.rglob("*.json")):
        rel = path.relative_to(data_dir)
        schema_path = SCHEMAS / f"{rel.parts[0]}.schema.json"
        if len(rel.parts) < 2 or not schema_path.exists():
            errors.append(f"{rel}: no schema (expected {schema_path.relative_to(ROOT)})")
            continue
        try:
            doc = json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as e:
            errors.append(f"{rel}: invalid JSON: {e}")
            continue
        validator = Draft202012Validator(json.loads(schema_path.read_text(encoding="utf-8")))
        for err in validator.iter_errors(doc):
            errors.append(f"{rel}: {'/'.join(map(str, err.path)) or '<root>'}: {err.message}")
        doc_id = doc.get("id") if isinstance(doc, dict) else None
        if doc_id is not None:
            if doc_id != path.stem:
                errors.append(f"{rel}: id '{doc_id}' does not match file name")
            if doc_id in ids:
                errors.append(f"{rel}: duplicate id '{doc_id}' (also in {ids[doc_id]})")
            ids[doc_id] = rel
    # ponytail: no cross-file reference or asset-existence checks yet; add them when data files first reference each other / real assets.
    return errors


def main() -> int:
    data_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "game" / "data"
    errors = validate(data_dir)
    for e in errors:
        print(f"ERROR {e}")
    print(f"{'FAIL' if errors else 'OK'}: {len(errors)} error(s) in {data_dir}")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
