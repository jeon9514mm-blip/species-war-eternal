#!/usr/bin/env python3
"""v83-2 gameplay reports. Same isolated engine runner; no release ZIP."""
import run_v83_runtime_checks as previous
runner=previous.runner
runner.DEVELOPMENT_STEP='v83-2'
runner.TESTS.update({
    'V83GameplayLedgerSmokeTest.gd':'v83_gameplay_ledger',
    'V83GameplayBattleSmokeTest.gd':'v83_gameplay_battle',
    'V83GameplayReportUiSmokeTest.gd':'v83_gameplay_report_ui',
    'V83GameplayAbyssSmokeTest.gd':'v83_gameplay_abyss',
})
if __name__=='__main__': raise SystemExit(runner.main())
