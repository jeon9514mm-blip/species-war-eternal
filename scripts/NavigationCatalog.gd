extends RefCounted
## One navigation definition for portrait and compatibility views.
## All presenters share the palette; menu groups and routes are canonical.
const DOCK: Array = [
	{"id":"home", "label":"홈", "portrait_icon":"home", "legacy_icon":"home", "method":"_build_lobby_screen"},
	{"id":"heroes", "label":"영웅", "portrait_icon":"heroes", "legacy_icon":"hero", "method":"_open_hero_menu"},
	{"id":"battle", "label":"전투", "portrait_icon":"battle", "legacy_icon":"compass", "method":"_lobby_start_hunt"},
	{"id":"bag", "label":"가방", "portrait_icon":"bag", "legacy_icon":"bag", "method":"_build_inventory_screen"},
	{"id":"more", "label":"메뉴", "portrait_icon":"settings", "legacy_icon":"growth", "method":"_show_main_menu"}]
const MENU: Array = [
	{"id":"camp", "group":"전투와 탐험", "label":"원정 캠프", "method":"_build_lobby_screen"},
	{"id":"growth", "group":"영웅과 성장", "label":"성장 · 던전", "method":"_build_meta_hub_screen"},
	{"id":"world", "group":"전투와 탐험", "label":"사냥터", "method":"_open_world_menu"},
	{"id":"summon", "group":"영웅과 성장", "label":"소환", "method":"_build_summon_screen"},
	{"id":"war", "group":"전투와 탐험", "label":"종의전쟁", "method":"_open_faction_war_menu"},
	{"id":"codex", "group":"영웅과 성장", "label":"영웅 도감", "method":"_build_codex_screen"},
	{"id":"rewards", "group":"보상과 계정", "label":"보상 센터", "method":"_build_bm_screen"},
	{"id":"faction", "group":"보상과 계정", "label":"진영 선택", "method":"_build_faction_screen"},
	{"id":"training", "group":"영웅과 성장", "label":"영웅 훈련", "method":"_build_growth_screen"},
	{"id":"formation", "group":"전투와 탐험", "label":"전투 진형", "method":"_open_battle_formation"},
	{"id":"title", "group":"보상과 계정", "label":"시작 화면", "method":"_build_title_screen"}]

static func dock_entries() -> Array:
	return DOCK.duplicate(true)

static func menu_entries() -> Array:
	return MENU.duplicate(true)

static func active_tab(screen: String) -> String:
	match screen:
		"home", "lobby", "party_ready": return "home"
		"heroes", "hero_select", "hero_detail": return "heroes"
		"battle", "combat", "raid", "world", "world_map", "boss_select": return "battle"
		"bag", "inventory", "equipment_detail", "equipment_workshop", "equipment_stash", "equipment_market", "option_crystal": return "bag"
		_: return "more"
