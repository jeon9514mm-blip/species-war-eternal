extends RefCounted
## Encounter-only tuning. Zone power still drives hunting, unlocks and rewards.
## Always derive fresh values from the catalog, never from a previous encounter
## or saved state, so retrying and loading cannot compound the multiplier.
const STRENGTH_MULTIPLIER: int = 10
const REVISION: String = "raid-strength-10x-1"

static func stats(zone: Dictionary) -> Dictionary:
	var power: int = int(zone["power"])
	# Preserve the original attack's integer rounding before applying tenfold strength.
	var original_attack: int = maxi(25, power / 3)
	return {
		"max_hp": power * 20 * STRENGTH_MULTIPLIER,
		"attack": original_attack * STRENGTH_MULTIPLIER,
		"recommended_power": power * 3 * STRENGTH_MULTIPLIER,
	}
