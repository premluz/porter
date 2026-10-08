"""Behavior checks for retrieval, stale indexes, and malformed project memory."""
import json
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SOURCE = Path(__file__).resolve().parents[1]


class ProjectMemoryTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name) / 'project'
        shutil.copytree(SOURCE, self.root, ignore=shutil.ignore_patterns('__pycache__', '*.zip'))

    def tearDown(self):
        self.temp.cleanup()

    def run_cli(self, *args):
        result = subprocess.run([sys.executable, str(self.root / 'tools/project_memory.py'), *args],
                                capture_output=True, text=True, check=False)
        return result.returncode, json.loads(result.stdout or result.stderr)

    def test_current_pack_validates(self):
        code, result = self.run_cli('check')
        self.assertEqual(code, 0, result)
        self.assertGreater(result['documents'], 0)
        self.assertGreater(result['tasks'], 0)

    def test_search_filters_and_read_paginates(self):
        code, result = self.run_cli('search', 'account', '--tag', 'area/identity')
        self.assertEqual(code, 0)
        self.assertGreater(result['total'], 0)
        for hit in result['results']:
            self.assertIn('area/identity', hit['tags'])
            self.assertTrue(hit['revision'].startswith('sha256:'))
        code, result = self.run_cli('read', 'DOC-DATA', '--start', '1', '--limit', '5')
        self.assertEqual(code, 0)
        self.assertTrue(result['has_more'])
        self.assertEqual(len(result['content'].splitlines()), 5)

    def test_stale_catalog_rejected_and_rebuilt(self):
        p = self.root / 'PROJECT_STATE.md'
        p.write_text(p.read_text() + '\nAn additional checkpoint.\n')
        code, result = self.run_cli('check')
        self.assertEqual(code, 1)
        self.assertTrue(any('catalog' in err for err in result['errors']))
        self.assertEqual(self.run_cli('index')[0], 0)
        self.assertEqual(self.run_cli('check')[0], 0)

    def test_broken_local_link_rejected(self):
        p = self.root / 'PROJECT_STATE.md'
        p.write_text(p.read_text() + '\n[Missing](missing-document.md)\n')
        self.run_cli('index')
        code, result = self.run_cli('check')
        self.assertEqual(code, 1)
        self.assertTrue(any('missing local link' in err for err in result['errors']))

    def test_duplicate_document_id_rejected(self):
        shutil.copyfile(self.root / 'docs/TECHNICAL_SCOPE.md', self.root / 'docs/duplicate.md')
        code, result = self.run_cli('check')
        self.assertEqual(code, 1)
        self.assertIn('Duplicate document ID', result['error'])

    def test_task_dependency_cycle_rejected(self):
        p = self.root / 'TASKS.md'
        text = p.read_text().replace('| TASK-001 | P0 | M0 | done | assistant | — |',
                                     '| TASK-001 | P0 | M0 | done | assistant | TASK-002 |')
        p.write_text(text)
        self.run_cli('index')
        code, result = self.run_cli('check')
        self.assertEqual(code, 1)
        self.assertTrue(any('cycle' in err for err in result['errors']))

    def test_read_rejects_paths(self):
        code, result = self.run_cli('read', '../../outside.md')
        self.assertEqual(code, 1)
        self.assertIn('paths are not accepted', result['error'])

    def test_symlink_escape_rejected(self):
        outside = Path(self.temp.name) / 'outside.md'
        outside.write_text('private fixture content')
        (self.root / 'docs/outside.md').symlink_to(outside)
        code, result = self.run_cli('check')
        self.assertEqual(code, 1)
        self.assertIn('escapes project root', result['error'])
        self.assertNotIn('private fixture content', str(result))


if __name__ == '__main__':
    unittest.main()
