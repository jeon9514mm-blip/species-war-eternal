#!/usr/bin/env python3
"""v83-5 patterns and faction-war checks, isolated real engine execution."""
import run_v83_4_runtime_checks as previous
runner = previous.runner
runner.DEVELOPMENT_STEP = 'v83-5'
runner.TESTS.update({
    'V835WarRulesSmokeTest.gd':'v835_war_rules',
    'V835WarUiSmokeTest.gd':'v835_war_ui',
    'V835PatternRulesSmokeTest.gd':'v835_pattern_rules',
    'V835PatternBattleSmokeTest.gd':'v835_pattern_battle',
    'V50CampaignSmokeTest.gd':'V50CampaignSmokeTest:',
    'V50CampaignUiSmokeTest.gd':'V50CampaignUiSmokeTest:',
    'V51WarAuthoritySmokeTest.gd':'V51WarAuthoritySmokeTest:',
    'V48WarStabilitySmokeTest.gd':'V48WarStabilitySmokeTest:',
    'WorldBattleResolverSmokeTest.gd':'world_battle_resolver_smoke_test_ok',
    'WorldConflictStateSmokeTest.gd':'world_conflict_state_smoke_test_ok',
    'WorldSupplyNetworkSmokeTest.gd':'world_supply_network_smoke_test_ok',
})
if __name__ == '__main__': raise SystemExit(runner.main())
