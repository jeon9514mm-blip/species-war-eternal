import unittest
from static_validate import local_private_calls

class PrivateCallTests(unittest.TestCase):
    def test_local_missing_still_collected(self):
        self.assertIn("_missing", local_private_calls("_missing()"))
    def test_self_missing_still_collected(self):
        self.assertIn("_missing", local_private_calls("self._missing()"))
    def test_foreign_member_not_main(self):
        self.assertEqual(local_private_calls("CHALLENGE_DRIVER._report_active(self)"), set())
    def test_nested_local_arguments(self):
        self.assertEqual(local_private_calls("SERVICE._apply(_local())"), {"_local"})
    def test_internal_underscore_not_call(self):
        self.assertEqual(local_private_calls("normal_name_call()"), set())
    def test_mixed_calls(self):
        self.assertEqual(local_private_calls("self._a(); _b(); other._c()"), {"_a", "_b"})

if __name__ == "__main__": unittest.main()
