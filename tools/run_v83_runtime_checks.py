#!/usr/bin/env python3
"""v83 focused engine suite; reuses the isolated v82 runner, not a copied runner.
No release archive or player's save is written. The runner creates disposable
project/user-data copies and treats engine errors/timeouts as failures.
"""
import run_v82_runtime_checks as runner
runner.DEVELOPMENT_STEP = "v83-1"
runner.TESTS.update({
    "V83DomainParitySmokeTest.gd": "v83_domain_parity",
    "V83NavigationSmokeTest.gd": "v83_navigation",
    "V27GrowthEconomySmokeTest.gd": "v27_growth_economy_smoke_test",
    "V27PersistenceIntegrationSmokeTest.gd": "v27_persistence_integration_smoke_test_ok",
    "V27SaveRecoverySmokeTest.gd": "v27_save_recovery_smoke_test_ok",
    "V54EquipmentIntegrationSmokeTest.gd": "v54_equipment_integration",
    "V54EquipmentPersistenceSmokeTest.gd": "v54_equipment_persistence_smoke_test",
    "V65GuardianSmokeTest.gd": "v65_guardian",
})
if __name__ == "__main__":
    raise SystemExit(runner.main())
