#!/usr/bin/env python3
"""v83-6.1 stabilization: actual isolated engine checks; no player save writes."""
import run_v83_6_runtime_checks as previous
runner = previous.runner
runner.DEVELOPMENT_STEP = 'v83-6.1'
runner.TESTS.update({
    'V8361OfflineSaveSmokeTest.gd': 'v8361_offline_save',
    'V8361XpSmokeTest.gd': 'v8361_xp',
    'V8361FrontlineNullSmokeTest.gd': 'v8361_frontline_null',
    'V8361ArchiveIntegritySmokeTest.gd': 'v8361_archive_integrity',
})
if __name__ == '__main__':
    raise SystemExit(runner.main())
