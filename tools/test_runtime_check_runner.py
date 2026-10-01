#!/usr/bin/env python3
"""Python unit tests of the runner only. This does NOT execute Godot."""
import unittest
from run_v80_runtime_checks import evaluate_output, isolate_project_name

class RunnerGuards(unittest.TestCase):
    def test_clean_pass(self):
        self.assertTrue(evaluate_output(0, 'v80_abyss_rules checks=12 failures=[]', 'v80_abyss_rules')[0])
    def test_nonzero(self):
        self.assertFalse(evaluate_output(1, 'marker', 'marker')[0])
    def test_zero_exit_script_error(self):
        self.assertFalse(evaluate_output(0, 'SCRIPT ERROR: bad\nmarker', 'marker')[0])
    def test_generic_engine_error(self):
        self.assertFalse(evaluate_output(0, 'ERROR: resource unavailable\nmarker', 'marker')[0])
    def test_no_marker(self):
        self.assertFalse(evaluate_output(0, 'Godot started but no test completion', 'marker')[0])
    def test_failure_list(self):
        self.assertFalse(evaluate_output(0, 'marker failures=["bad"]', 'marker')[0])
    def test_numeric_zero(self):
        self.assertTrue(evaluate_output(0, 'marker checks=23 failures=0', 'marker')[0])
    def test_numeric_failure(self):
        self.assertFalse(evaluate_output(0, 'marker failures=2', 'marker')[0])
    def test_empty_list_cannot_hide_failure(self):
        self.assertFalse(evaluate_output(0, 'marker failures=["bad"]\nmarker failures=[]', 'marker')[0])
    def test_legacy_count(self):
        self.assertTrue(evaluate_output(0, 'marker: 34 checks, 0 failures', 'marker')[0])
        self.assertFalse(evaluate_output(0, 'marker: 34 checks, 1 failures', 'marker')[0])
    def test_malformed_report(self):
        self.assertFalse(evaluate_output(0, 'marker failures=unknown', 'marker')[0])
    def test_timeout(self):
        self.assertFalse(evaluate_output(None, 'partial log marker', 'marker')[0])
    def test_isolated_name_and_config(self):
        result=isolate_project_name('[application]\nconfig/name="Live"\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="LiveSave"\n', 'Test-unique')
        self.assertIn('config/name="Test-unique"', result)
        self.assertIn('config/use_custom_user_dir=false', result)
        self.assertNotIn('Live', result)

if __name__ == '__main__':
    unittest.main()
