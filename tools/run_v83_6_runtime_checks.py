#!/usr/bin/env python3
"""v83-6 raid contribution and local SLG frontline; isolated engine regression."""
import run_v83_5_runtime_checks as previous
runner=previous.runner
runner.DEVELOPMENT_STEP='v83-6'
runner.TESTS.update({
 'V836RaidLedgerSmokeTest.gd':'v836_raid_ledger',
 'V836RaidBattleSmokeTest.gd':'v836_raid_battle',
 'V836FrontlineSmokeTest.gd':'v836_frontline',
 'V836UiSmokeTest.gd':'v836_ui',
 'V75RaidMechanicSmokeTest.gd':'V75RaidMechanicSmokeTest:',
 'V76RaidVisualSmokeTest.gd':'V76RaidVisualSmokeTest:',
 'V64RealtimeRaidSmokeTest.gd':'v64_realtime_raid',
})
if __name__=='__main__':raise SystemExit(runner.main())
