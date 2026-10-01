#!/usr/bin/env python3
"""v83-6.2 isolated regression checks including corps, formation and rotation."""
import run_v83_6_1_runtime_checks as previous
runner = previous.runner
runner.DEVELOPMENT_STEP = 'v83-6.2'
runner.TESTS.update({
    'V8362FieldSafetySmokeTest.gd': 'v8362_field_safety',
    'V8362InvasionSmokeTest.gd': 'v8362_invasion',
    'V8362FormationDisplaySmokeTest.gd': 'v8362_formation_display',
    'V8362LayoutSmokeTest.gd': 'v8362_layout',
})
if __name__ == '__main__':
    raise SystemExit(runner.main())
