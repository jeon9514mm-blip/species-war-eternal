"""Exercise discovery boundaries and filename compatibility without Godot."""
from pathlib import Path
import tempfile
import unittest

from project_paths import regression_tests, resource_path, select_tests, source_scripts, test_resource


class ProjectPathsTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        for name in ['tests/regression/OneSmokeTest.gd', 'tests/regression/nested/OtherRegressionTest.gd',
                     'tests/support/FixtureTestBase.gd', 'scripts/app/Main.gd',
                     '.godot/imported/Cached.gd']:
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text('extends SceneTree\n')

    def test_discovery_includes_nested_regressions_but_excludes_support(self):
        self.assertEqual({path.name for path in regression_tests(self.root)},
                         {'OneSmokeTest.gd', 'OtherRegressionTest.gd'})

    def test_existing_filename_and_resource_cli_are_equivalent(self):
        for name in ['OneSmokeTest.gd', 'tests/regression/OneSmokeTest.gd',
                     'res://tests/regression/OneSmokeTest.gd']:
            self.assertEqual(test_resource(self.root, name), 'res://tests/regression/OneSmokeTest.gd')

    def test_rejects_support_traversal_and_unknown_entrypoints(self):
        for name in ['../scripts/app/Main.gd', 'tests/support/FixtureTestBase.gd', 'MissingTest.gd']:
            with self.assertRaises(ValueError):
                select_tests(self.root, [name])

    def test_repeated_selection_runs_once(self):
        self.assertEqual(len(select_tests(self.root, ['OneSmokeTest.gd', 'OneSmokeTest.gd'])), 1)

    def test_ambiguous_basename_requires_explicit_relative_path(self):
        second = self.root / 'tests/regression/nested/OneSmokeTest.gd'
        second.write_text('extends SceneTree\n')
        with self.assertRaises(ValueError):
            select_tests(self.root, ['OneSmokeTest.gd'])
        self.assertEqual(select_tests(self.root, ['tests/regression/nested/OneSmokeTest.gd']), [second])

    def test_source_scan_compiles_support_but_ignores_import_cache(self):
        scripts = source_scripts(self.root)
        self.assertEqual(len(scripts), 4)
        self.assertIn('res://tests/support/FixtureTestBase.gd',
                      [resource_path(self.root, path) for path in scripts])

    def test_empty_test_directory_does_not_report_success(self):
        with tempfile.TemporaryDirectory() as empty:
            with self.assertRaises(ValueError):
                select_tests(Path(empty))


if __name__ == '__main__':
    unittest.main()
