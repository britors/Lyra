"""Testes do job de cópia (PROMPT-CALAMARES-MIGRACAO-WINDOWS.md §8).

Roda com `python -m unittest copy_job.test` a partir deste diretório.
"""

import json
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "winmigrate-copy"))

from jobs import copy_job


class FakeCompletedProcess:
    def __init__(self, returncode=0, stderr=""):
        self.returncode = returncode
        self.stderr = stderr


CHROME_BOOKMARKS_FIXTURE = {
    "roots": {
        "bookmark_bar": {
            "type": "folder",
            "name": "Barra de favoritos",
            "children": [
                {"type": "url", "name": "Exemplo", "url": "https://example.com/"},
                {
                    "type": "folder",
                    "name": "Trabalho",
                    "children": [
                        {"type": "url", "name": "Painel <admin>", "url": "https://work.example.com/?a=1&b=2"},
                    ],
                },
            ],
        },
    },
}


class RsyncCopyTests(unittest.TestCase):
    def test_success(self):
        run = lambda cmd, **kw: FakeCompletedProcess(returncode=0)
        with tempfile.TemporaryDirectory() as tmp:
            ok, error = copy_job.rsync_copy(os.path.join(tmp, "src"), os.path.join(tmp, "dst"), run=run)
        self.assertTrue(ok)
        self.assertIsNone(error)

    def test_failure_reports_stderr(self):
        run = lambda cmd, **kw: FakeCompletedProcess(returncode=23, stderr="rsync: some files vanished")
        with tempfile.TemporaryDirectory() as tmp:
            ok, error = copy_job.rsync_copy(os.path.join(tmp, "src"), os.path.join(tmp, "dst"), run=run)
        self.assertFalse(ok)
        self.assertIn("vanished", error)


class BookmarksConversionTests(unittest.TestCase):
    def test_converts_nested_folders_and_escapes_html(self):
        with tempfile.TemporaryDirectory() as tmp:
            src = os.path.join(tmp, "Bookmarks")
            with open(src, "w", encoding="utf-8") as handle:
                json.dump(CHROME_BOOKMARKS_FIXTURE, handle)
            dest = os.path.join(tmp, "out", "bookmarks.html")

            ok, error = copy_job.convert_bookmarks(src, dest)

            self.assertTrue(ok)
            self.assertIsNone(error)
            with open(dest, encoding="utf-8") as handle:
                content = handle.read()
            self.assertIn("NETSCAPE-Bookmark-file-1", content)
            self.assertIn('HREF="https://example.com/"', content)
            self.assertIn("Painel &lt;admin&gt;", content)
            self.assertIn("Trabalho", content)

    def test_invalid_json_reports_error_without_raising(self):
        with tempfile.TemporaryDirectory() as tmp:
            src = os.path.join(tmp, "Bookmarks")
            with open(src, "w", encoding="utf-8") as handle:
                handle.write("not json")

            ok, error = copy_job.convert_bookmarks(src, os.path.join(tmp, "out.html"))

            self.assertFalse(ok)
            self.assertIsNotNone(error)


class RunCopyTests(unittest.TestCase):
    def _migration_with_items(self, tmp):
        docs_src = os.path.join(tmp, "win", "Documents")
        os.makedirs(docs_src, exist_ok=True)
        pics_src = os.path.join(tmp, "win", "Pictures")
        os.makedirs(pics_src, exist_ok=True)
        return {
            "found": True,
            "profiles": {
                "alice": [
                    {"id": "documents", "source_path": docs_src, "dest": "Documentos/Do Windows",
                     "kind": "directory", "size_bytes": 0, "default": True},
                    {"id": "pictures", "source_path": pics_src, "dest": "Imagens/Do Windows",
                     "kind": "directory", "size_bytes": 0, "default": True},
                ],
            },
        }

    def test_skipped_selection_copies_nothing(self):
        summary = copy_job.run_copy({"found": True}, {"skipped": True}, "/tmp/home/alice")
        self.assertEqual(summary, {"skipped": True, "results": []})

    def test_partial_failure_does_not_abort_remaining_items(self):
        with tempfile.TemporaryDirectory() as tmp:
            migration = self._migration_with_items(tmp)
            selection = {"skipped": False, "profile": "alice", "selectedIds": ["documents", "pictures"]}
            target_home = os.path.join(tmp, "home", "alice")

            calls = []

            def flaky_run(cmd, **kwargs):
                calls.append(cmd)
                if "Documentos/Do Windows" in cmd[-1]:
                    return FakeCompletedProcess(returncode=1, stderr="permission denied")
                return FakeCompletedProcess(returncode=0)

            summary = copy_job.run_copy(migration, selection, target_home, run=flaky_run)

            self.assertFalse(summary["skipped"])
            results_by_id = {r["id"]: r for r in summary["results"]}
            self.assertFalse(results_by_id["documents"]["ok"])
            self.assertTrue(results_by_id["pictures"]["ok"])
            self.assertEqual(len(calls), 2)


if __name__ == "__main__":
    unittest.main()
