"""Fails on control characters and CRLF in tracked text files.

Agents writing Windows paths turn backslash sequences into control characters
(a backspace, a vertical tab, a tab); see 02_TECH_ARCHITECTURE.md section 6.
"""
import re
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
EXTENSIONS = {"md", "gd", "json", "ps1", "py", "cfg", "tscn", "gdshader", "godot", "csv", "txt", "tres", "uid"}
SKIP_PREFIX = "game/addons/gut/"
BAD = re.compile(rb"[\x00-\x08\x0b\x0c\x0e-\x1f]|\r\n")
MD_TAB = re.compile(rb"[^\t\n]\t")
MAX_SHOWN = 50


def scan(name: str, data: bytes) -> list[str]:
    hits = [(m.start(), m.group()) for m in BAD.finditer(data)]
    if name.endswith(".md"):
        hits += [(m.start() + 1, b"\t") for m in MD_TAB.finditer(data)]
    out = []
    for pos, raw in sorted(hits):
        line = data.count(b"\n", 0, pos) + 1
        col = pos - (data.rfind(b"\n", 0, pos) + 1) + 1
        out.append(f"{name}:{line}:{col} {raw!r}")
    return out


def tracked_text_files() -> list[str]:
    out = subprocess.run(["git", "ls-files", "-z"], cwd=ROOT, capture_output=True, check=True).stdout
    names = [n for n in out.decode("utf-8").split("\0") if n]
    return [n for n in names if n.rsplit(".", 1)[-1] in EXTENSIONS and not n.startswith(SKIP_PREFIX)]


class TextHygieneTest(unittest.TestCase):
    def test_scanner(self):
        self.assertEqual(len(scan("a.md", b"x\x08y\x0bz\r\nab\tc\n")), 4)
        self.assertEqual(scan("a.md", b"\tindent\n\t\tmore\nplain\n"), [])

    def test_tracked_files_are_clean(self):
        hits = []
        for name in tracked_text_files():
            path = ROOT / name
            if path.is_file():
                hits += scan(name, path.read_bytes())
        shown = "\n".join(hits[:MAX_SHOWN])
        self.assertFalse(hits, f"{len(hits)} control character / CRLF hits (write paths with / or chr(92)):\n{shown}")


if __name__ == "__main__":
    unittest.main()
