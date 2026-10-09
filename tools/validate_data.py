"""Validate game content data against JSON Schema (D-034).

Each folder game/data/<kind>/ is checked against tools/schemas/<kind>.schema.json.
Usage: python tools/validate_data.py [data_dir]
"""
import csv
import json
import re
import sys
from pathlib import Path

from jsonschema import Draft202012Validator

ROOT = Path(__file__).resolve().parent.parent
SCHEMAS = ROOT / "tools" / "schemas"
STRINGS = ROOT / "game" / "loc" / "strings.csv"
ID_REF = re.compile(r"^(enemy|tower|skill|guardian|run)_[a-z0-9_]+$")


def validate(data_dir: Path, strings: Path = STRINGS) -> list[str]:
    errors = []
    ids = {}
    docs = {}
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
            docs[rel] = doc
    errors += check_references(docs, ids)
    errors += check_loc_keys(docs, strings)
    # ponytail: no asset-existence check yet; add it when data first references real assets.
    return errors


def _strings(value):
    if isinstance(value, str):
        yield value
    elif isinstance(value, dict):
        for v in value.values():
            yield from _strings(v)
    elif isinstance(value, list):
        for v in value:
            yield from _strings(v)


def check_references(docs: dict, ids: dict) -> list[str]:
    """Every id-like string must name a known document; run bosses must be boss enemies;
    a run's spawn ring must not be inverted."""
    errors = []
    for rel, doc in docs.items():
        own = doc.get("id")
        for s in _strings(doc):
            if s != own and ID_REF.match(s) and s not in ids:
                errors.append(f"{rel}: unknown reference '{s}'")
        if rel.parts[0] == "runs":
            ring = (doc.get("spawn_ring_min"), doc.get("spawn_ring_max"))
            if all(isinstance(v, (int, float)) for v in ring) and ring[0] > ring[1]:
                errors.append(f"{rel}: spawn_ring_min is greater than spawn_ring_max")
            for boss in [*doc.get("bosses", []), doc.get("final_boss")]:
                if not isinstance(boss, dict):
                    continue  # the schema pass reports it
                enemy = docs.get(ids.get(boss.get("enemy")), {})
                if enemy and enemy.get("archetype") not in ("miniboss", "boss"):
                    errors.append(f"{rel}: boss '{boss['enemy']}' is not a miniboss/boss enemy")
    return errors


def _keyed(value, field=""):
    """(field, value) for every string value of a field named *_key."""
    if isinstance(value, dict):
        for k, v in value.items():
            yield from _keyed(v, k)
    elif isinstance(value, list):
        for v in value:
            yield from _keyed(v, field)
    elif isinstance(value, str) and field.endswith("_key"):
        yield field, value


def check_loc_keys(docs: dict, strings: Path) -> list[str]:
    """Every *_key value must be a key of the localisation CSV (D-063, D-121)."""
    with strings.open(encoding="utf-8", newline="") as f:
        keys = {row["keys"] for row in csv.DictReader(f)}
    return [f"{rel}: {field} '{v}' missing from {strings.name}"
            for rel, doc in docs.items() for field, v in _keyed(doc) if v not in keys]


def main() -> int:
    data_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "game" / "data"
    errors = validate(data_dir)
    for e in errors:
        print(f"ERROR {e}")
    print(f"{'FAIL' if errors else 'OK'}: {len(errors)} error(s) in {data_dir}")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
