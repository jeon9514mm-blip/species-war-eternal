extends RefCounted
## Raid UI metadata only; no map design or visual asset.
const THEMES := {
 'gray_meadow':{'title':'레이드 1','accent':Color('#bdd0df')},
 'forgotten_mine':{'title':'레이드 2','accent':Color('#bdd0df')},
 'moonrest_forest':{'title':'레이드 3','accent':Color('#bdd0df')}
}
static func profile(zone: String) -> Dictionary:return THEMES.get(zone,THEMES.gray_meadow)
