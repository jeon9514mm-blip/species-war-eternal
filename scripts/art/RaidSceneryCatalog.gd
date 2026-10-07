extends RefCounted
## One independently painted background for each encounter; load only active art.
const THEMES := {
	'gray_meadow': {'title':'천공 수호 유적', 'accent':Color('#8bdddf'), 'texture':'res://assets/maps/raid-painted/sky-court.png'},
	'forgotten_mine': {'title':'호박빛 심층 광산', 'accent':Color('#edbb75'), 'texture':'res://assets/maps/raid-painted/amber-quarry.png'},
	'moonrest_forest': {'title':'월광의 성소', 'accent':Color('#c6aff4'), 'texture':'res://assets/maps/raid-painted/lunar-sanctum.png'},
}
static func profile(zone: String) -> Dictionary: return THEMES.get(zone, THEMES.gray_meadow)
