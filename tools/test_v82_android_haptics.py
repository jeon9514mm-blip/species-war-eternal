#!/usr/bin/env python3
"""Only temporary preset fixtures: no SDK, device, or real export settings touched."""
import tempfile
import unittest
from pathlib import Path
from configure_android_haptics import configure

BASE = '''[preset.0]
name="Windows Desktop"
platform="Windows Desktop"
[preset.0.options]
permissions/vibrate=false
[preset.1]
name="Android"
platform="Android"
[preset.1.options]
custom_features=PackedStringArray("test")
permissions/vibrate=false
package/unique_name="org.example.unchanged"
'''

class PresetTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name) / 'export_presets.cfg'
        self.path.write_text(BASE)

    def test_missing_file(self):
        self.assertFalse(configure(self.path.with_name('missing'), 'Android')['ok'])

    def test_audit_does_not_mutate(self):
        before = self.path.read_bytes()
        self.assertFalse(configure(self.path, 'Android')['ok'])
        self.assertEqual(before, self.path.read_bytes())
        self.assertFalse(self.path.with_suffix('.cfg.v82.bak').exists())

    def test_explicit_enable_only_target(self):
        result = configure(self.path, 'Android', True)
        self.assertTrue(result['ok'])
        self.assertTrue(result['changed'])
        self.assertEqual(self.path.read_text(), BASE.replace(
            'permissions/vibrate=false\npackage', 'permissions/vibrate=true\npackage'))
        self.assertEqual(Path(result['backup']).read_text(), BASE)
        self.assertTrue(configure(self.path, 'Android')['ok'])

    def test_repeat_idempotent(self):
        configure(self.path, 'Android', True)
        before = self.path.read_bytes()
        self.assertFalse(configure(self.path, 'Android', True)['changed'])
        self.assertEqual(before, self.path.read_bytes())

    def test_wrong_platform_or_name(self):
        self.assertFalse(configure(self.path, 'Windows Desktop', True)['ok'])
        self.assertFalse(configure(self.path, 'Other', True)['ok'])
        self.assertEqual(BASE, self.path.read_text())

    def test_missing_permission_added(self):
        self.path.write_text(BASE.replace('permissions/vibrate=false\npackage', 'package'))
        self.assertTrue(configure(self.path, 'Android', True)['ok'])
        self.assertTrue(configure(self.path, 'Android')['ok'])

    def test_missing_options_added(self):
        self.path.write_text('[preset.0]\nname="Android"\nplatform="Android"\n')
        self.assertTrue(configure(self.path, 'Android', True)['ok'])
        self.assertIn('[preset.0.options]', self.path.read_text())
        self.assertTrue(configure(self.path, 'Android')['ok'])

    def test_duplicate_name_rejected(self):
        self.path.write_text(BASE + '\n[preset.2]\nname="Android"\nplatform="Android"\n')
        before = self.path.read_bytes()
        self.assertFalse(configure(self.path, 'Android', True)['ok'])
        self.assertEqual(before, self.path.read_bytes())

    def test_malformed_file_no_write(self):
        self.path.write_text('this is not an ini')
        self.assertFalse(configure(self.path, 'Android', True)['ok'])
        self.assertEqual('this is not an ini', self.path.read_text())

if __name__ == '__main__':
    unittest.main(verbosity=2)
