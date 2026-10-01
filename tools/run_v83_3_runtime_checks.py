#!/usr/bin/env python3
"""v83-3 practice, presets and save-safety; isolated Godot execution."""
import run_v83_2_runtime_checks as previous
runner=previous.runner
runner.DEVELOPMENT_STEP='v83-3'
runner.TESTS.update({
 'V83UpgradeRulesSmokeTest.gd':'v83_upgrade_rules',
 'V83LoadoutSmokeTest.gd':'v83_loadout',
 'V83PracticeBattleSmokeTest.gd':'v83_practice_battle',
 'V83PracticeUiSmokeTest.gd':'v83_practice_ui',
})
if __name__=='__main__': raise SystemExit(runner.main())
