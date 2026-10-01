#!/usr/bin/env python3
"""v83-4 allocation + level-matched practice, isolated Godot suite."""
import run_v83_3_runtime_checks as previous
runner = previous.runner
runner.DEVELOPMENT_STEP = "v83-4"
runner.TESTS.update({
    "V834ResearchSmokeTest.gd": "v834_research",
    "V834PracticeLevelSmokeTest.gd": "v834_practice_level",
    "V834MatchedBattleSmokeTest.gd": "v834_matched_battle",
    "V834GrowthUiSmokeTest.gd": "v834_growth_ui",
})
if __name__ == "__main__": raise SystemExit(runner.main())
