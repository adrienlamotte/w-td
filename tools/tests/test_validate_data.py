import json
import shutil
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from validate_data import ROOT, validate  # noqa: E402

EXAMPLE = ROOT / "game" / "data" / "enemies" / "enemy_swarmer_01.json"
CAMERA = ROOT / "game" / "data" / "camera" / "camera_default.json"
RENDER = ROOT / "game" / "data" / "render" / "render_default.json"
DATA = ROOT / "game" / "data"


class ValidateDataTest(unittest.TestCase):
    def check(self, doc: dict, name: str = "enemy_swarmer_01", kind: str = "enemies") -> list[str]:
        with tempfile.TemporaryDirectory() as tmp:
            (Path(tmp) / kind).mkdir()
            (Path(tmp) / kind / f"{name}.json").write_text(json.dumps(doc), encoding="utf-8")
            return validate(Path(tmp))

    def test_repo_data_is_valid(self):
        self.assertEqual(validate(ROOT / "game" / "data"), [])

    def test_rejects_unknown_field(self):
        doc = json.loads(EXAMPLE.read_text(encoding="utf-8")) | {"surprise": 1}
        self.assertTrue(any("surprise" in e for e in self.check(doc)))

    def test_rejects_bad_value(self):
        doc = json.loads(EXAMPLE.read_text(encoding="utf-8")) | {"hp": -1}
        self.assertTrue(any("hp" in e for e in self.check(doc)))

    def test_rejects_id_not_matching_file(self):
        doc = json.loads(EXAMPLE.read_text(encoding="utf-8"))
        self.assertTrue(any("file name" in e for e in self.check(doc, name="enemy_other")))

    def test_camera_needs_three_zoom_sizes(self):
        doc = json.loads(CAMERA.read_text(encoding="utf-8"))
        self.assertEqual(self.check(doc, "camera_default", "camera"), [])
        doc["zoom_sizes"] = [16, 24]
        self.assertTrue(any("zoom_sizes" in e for e in self.check(doc, "camera_default", "camera")))

    def test_render_rejects_extra_field(self):
        doc = json.loads(RENDER.read_text(encoding="utf-8"))
        self.assertEqual(self.check(doc, "render_default", "render"), [])
        doc["surprise"] = 1
        self.assertTrue(any("surprise" in e for e in self.check(doc, "render_default", "render")))

    def test_bench_rejects_extra_scenario_field(self):
        # bench_m1 references an enemy, so it is checked within a copy of the repo data.
        errors = self.check_repo_with("bench", "bench_m1", lambda d: d["scenarios"][0].update(surprise=1))
        self.assertTrue(any("surprise" in e for e in errors))

    def check_repo_with(self, kind: str, name: str, edit) -> list[str]:
        """Validates a copy of the repo data where one document was changed by edit(doc)."""
        with tempfile.TemporaryDirectory() as tmp:
            shutil.copytree(DATA, tmp, dirs_exist_ok=True)
            path = Path(tmp) / kind / f"{name}.json"
            doc = json.loads(path.read_text(encoding="utf-8"))
            edit(doc)
            path.write_text(json.dumps(doc), encoding="utf-8")
            return validate(Path(tmp))

    def test_rejects_dangling_reference(self):
        errors = self.check_repo_with("runs", "run_m2", lambda d: d["waves"][0]["mix"][0].update(enemy="enemy_nope"))
        self.assertTrue(any("enemy_nope" in e for e in errors))

    def test_rejects_boss_that_is_not_a_boss_enemy(self):
        errors = self.check_repo_with("runs", "run_m2", lambda d: d["final_boss"].update(enemy="enemy_swarmer_01"))
        self.assertTrue(any("not a miniboss/boss" in e for e in errors))

    def test_splash_tower_needs_splash_radius(self):
        errors = self.check_repo_with("towers", "tower_splash_01", lambda d: d.pop("splash_radius"))
        self.assertTrue(any("splash_radius" in e for e in errors))

    def test_shield_skill_needs_absorb(self):
        errors = self.check_repo_with("skills", "skill_shield", lambda d: d.pop("absorb"))
        self.assertTrue(any("absorb" in e for e in errors))

    def test_rejects_enemy_v2(self):
        doc = json.loads(EXAMPLE.read_text(encoding="utf-8")) | {"schema_version": 2}
        self.assertTrue(any("schema_version" in e for e in self.check(doc)))


if __name__ == "__main__":
    unittest.main()
