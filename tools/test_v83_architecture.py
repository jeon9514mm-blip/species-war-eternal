#!/usr/bin/env python3
"""Unit tests of the structural checker, not gameplay or engine tests."""
import unittest
import tempfile
import shutil
from pathlib import Path
from validate_v83_architecture import canonical, functions, verify, ROOT
class CanonicalTests(unittest.TestCase):
    def test_owner_and_inference(self):
        self.assertEqual(canonical('var n := gold + _count(self)\n'),canonical('var n = main.gold + main._count(main)\n',True))
    def test_comments_not_semantics(self):
        self.assertEqual(canonical('return x + 1 # note'),canonical('return x+1'))
    def test_string_content_not_normalized(self):
        self.assertNotEqual(canonical('return "main.x"'),canonical('return "x"',True))
    def test_operator_change_detected(self):
        self.assertNotEqual(canonical('return x+1'),canonical('return main.x-1',True))
    def test_literal_whitespace_retained(self):
        self.assertNotEqual(canonical('return "a b"'),canonical('return "ab"'))
    def test_member_access_preserved(self):
        self.assertEqual(canonical('return tree.get("level")'),canonical('return tree.get("level")',True))
    def test_constants_outside_function(self):
        f=functions('func a() -> int:\n\treturn 1\n\nconst LIMIT=10\nfunc b() -> int:\n\treturn LIMIT\n')
        self.assertNotIn('const',f['a'][1]);self.assertEqual(set(f),{'a','b'})
    def test_static_function_recognized(self):
        self.assertIn('a',functions('static func a(main: Node) -> int:\n\treturn main.gold\n'))
class CurrentContractsTests(unittest.TestCase):
    def test_current_release(self):
        self.assertTrue(verify(ROOT)['ok'], verify(ROOT)['errors'])
    def check_mutation(self, relative, before, after, expected):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            shutil.copytree(ROOT/'scripts', root/'scripts')
            (root/'tools').mkdir()
            shutil.copy(ROOT/'tools/v83_extraction_map.json', root/'tools/v83_extraction_map.json')
            path = root/relative
            text = path.read_text()
            self.assertIn(before, text)
            path.write_text(text.replace(before, after))
            self.assertTrue(any(expected in e for e in verify(root)['errors']))
    def test_duplicate_economy_owner_rejected(self):
        self.check_mutation('scripts/hunting/HuntFieldService.gd', 'extends RefCounted',
                            'extends RefCounted\nvar wallet_gold = 0', 'duplicate host state')
    def test_field_delegation_required(self):
        self.check_mutation('scripts/app/Main.gd', '_FIELD.finish_hunt_target(self)',
                            'pass', 'field orchestration delegation missing')
    def test_zone_alias_drift_rejected(self):
        self.check_mutation('scripts/equipment/EquipmentRules.gd', 'preload("res://scripts/maps/ZoneCatalog.gd").MEADOW_NAME',
                            '"회색 초원"', 'canonical MEADOW_NAME')
    def test_critical_save_coordination_remains_required(self):
        self.check_mutation('scripts/app/Main.gd',
                            'if is_instance_valid(hunt_autosave): hunt_autosave.before_critical_save()',
                            'pass', '_save_idle_state: compatibility facade changed')
    def test_bulk_preview_remains_required(self):
        self.check_mutation('scripts/app/Main.gd',
                            'preload("res://scripts/equipment/BulkEnhancePreview.gd").show(self)',
                            'pass', '_bulk_enhance_equipped: compatibility facade changed')
if __name__=='__main__':unittest.main()
