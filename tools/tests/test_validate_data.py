import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from validate_data import ROOT, validate  # noqa: E402

EXAMPLE = ROOT / "game" / "data" / "enemies" / "enemy_swarmer_01.json"
CAMERA = ROOT / "game" / "data" / "camera" / "camera_default.json"
RENDER = ROOT / "game" / "data" / "render" / "render_default.json"
BENCH = ROOT / "game" / "data" / "bench" / "bench_m1.json"


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
        doc = json.loads(BENCH.read_text(encoding="utf-8"))
        self.assertEqual(self.check(doc, "bench_m1", "bench"), [])
        doc["scenarios"][0]["surprise"] = 1
        self.assertTrue(any("surprise" in e for e in self.check(doc, "bench_m1", "bench")))


if __name__ == "__main__":
    unittest.main()
