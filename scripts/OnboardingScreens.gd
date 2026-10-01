extends RefCounted
class_name OnboardingScreens

const UI := preload("res://scripts/LandingScreens.gd")
const ICONS := preload("res://scripts/GameUiTheme.gd")

static func faction(main) -> void:
	main._clear_screen()
	main.active_screen = "faction"
	main.faction_cards.clear()
	var root: Control = main.content_root
	var w: float = main._layout_width()
	UI._action(main, root, "돌아가기", Rect2(48, 28, 124, 44), Callable(main, "_build_lobby_screen"))
	UI._text(main, root, "01  진영 선택", Rect2(w - 250, 30, 200, 42), 16, UI.GOLD)
	UI._text(main, root, "어떤 깃발 아래 모일까요?", Rect2(54, 96, w - 108, 48), 34, UI.INK)
	UI._text(main, root, "서로 다른 종족과 전술, 같은 크기의 가능성. 나에게 맞는 원정대를 골라 보세요.", Rect2(56, 151, w - 112, 31), 17, UI.MUTED)
	var card_w := (w - 140.0) / 2.0
	_faction_card(main, root, Rect2(56, 209, card_w, 330), "aurelia", "아우렐리아 연합", "휴먼 · 엘프", "성벽의 맹세, 숲의 지혜", "단단한 전열과 정교한 협공.\n동료를 지키며 흔들림 없이 나아갑니다.", ["수호와 회복", "원거리 협공", "안정적인 전선"], Color("#437e99"), "shield")
	_faction_card(main, root, Rect2(84 + card_w, 209, card_w, 330), "noxfera", "녹스페라 연맹", "뱀파이어 · 늑대인간", "달빛 아래 이어진 결속", "흡혈과 돌진으로 흐름을 바꾸는 사냥꾼.\n빈틈을 포착해 적의 진형을 흔듭니다.", ["흡혈과 기습", "근접 압박", "유연한 역습"], Color("#94657e"), "moon")
	main.selection_hint = UI._text(main, root, "함께할 진영을 선택하세요.", Rect2(56, 558, w - 112, 31), 16, UI.MUTED)
	main.selection_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main.confirm_button = UI._action(main, root, "진영을 선택하세요", Rect2((w - 580.0) / 2.0, 608, 580, 58), Callable(main, "_confirm_faction"), true)
	main.confirm_button.disabled = true
	UI._text(main, root, "진영을 바꾸면 편성이 해제됩니다. 영웅 성장 · 장비 · 재화는 유지됩니다.", Rect2(56, 678, w - 112, 27), 15, UI.MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if str(main.selected_faction) in ["aurelia", "noxfera"]:
		main._select_faction(str(main.selected_faction))

static func _faction_card(main, parent: Control, rect: Rect2, id: String, title: String, species: String, doctrine: String, description: String, traits: Array, accent: Color, icon_name: String) -> void:
	# Preserve PanelContainer for Main._select_faction's selection border updates.
	var card := PanelContainer.new()
	card.name = "FactionCard_" + id
	card.position = rect.position
	card.size = rect.size
	card.add_theme_stylebox_override("panel", main._panel_style(UI.PAPER, UI.BORDER, 20, 1))
	parent.add_child(card)
	main.faction_cards[id] = card
	var margin := MarginContainer.new()
	for edge in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 22)
	card.add_child(margin)
	var canvas := Control.new()
	canvas.custom_minimum_size = Vector2(rect.size.x - 46, rect.size.y - 46)
	margin.add_child(canvas)
	var icon := ICONS.icon(icon_name, Vector2(58, 58), accent)
	icon.position = Vector2(4, 5)
	canvas.add_child(icon)
	UI._text(main, canvas, title, Rect2(82, 0, rect.size.x - 140, 40), 27, UI.INK)
	UI._text(main, canvas, species, Rect2(84, 41, rect.size.x - 140, 26), 16, accent)
	UI._text(main, canvas, doctrine, Rect2(0, 87, rect.size.x - 44, 30), 19, accent)
	UI._text(main, canvas, description, Rect2(0, 126, rect.size.x - 44, 60), 17, UI.MUTED, true)
	var tag_w := (rect.size.x - 58.0) / 3.0
	for index in range(3):
		UI._badge(main, canvas, traits[index], Rect2(index * (tag_w + 7.0), 202, tag_w, 30), UI.SAGE, accent)
	var select := UI._action(main, canvas, "이 진영 선택", Rect2(0, 247, rect.size.x - 46, 43), func(): main._select_faction(id))
	select.name = "SelectFaction_" + id

static func intro(main) -> void:
	main._clear_screen()
	main.active_screen = "intro"
	var root: Control = main.content_root
	var w: float = main._layout_width()
	UI._action(main, root, "진영 다시 선택", Rect2(48, 28, 170, 44), Callable(main, "_build_faction_screen"))
	UI._text(main, root, "02  첫 동료와의 만남", Rect2(w - 305, 30, 255, 42), 16, UI.GOLD)
	var is_aurelia: bool = main.selected_faction == "aurelia"
	var ids: Array = ["leonhardt", "mira"] if is_aurelia else []
	var scene := UI._scene(main, root, Rect2(48, 118, w - 635, 530), ids, true)
	UI._badge(main, scene, main._faction_name(), Rect2(24, 24, 242, 39), UI.PAPER, UI.GREEN)
	var panel := UI._panel(main, root, Rect2(w - 554, 118, 506, 530), UI.PAPER, UI.BORDER, 24)
	var icon := ICONS.icon("shield" if is_aurelia else "moon", Vector2(58, 58), UI.GREEN if is_aurelia else Color("#94657e"))
	icon.position = Vector2(34, 33)
	panel.add_child(icon)
	UI._text(main, panel, "새로운 이야기가 시작됩니다", Rect2(34, 115, 438, 30), 16, UI.GOLD)
	UI._text(main, panel, "함께할 동료를\n만날 시간이에요", Rect2(34, 164, 438, 90), 32, UI.INK)
	UI._text(main, panel, "첫 영웅과 회색 초원으로 출발하세요.\n모험을 거듭할수록 더 많은 동료가 합류하고,\n최대 10명이 함께하는 원정대로 성장합니다.", Rect2(34, 279, 438, 89), 17, UI.MUTED, true)
	var next := UI._action(main, panel, "첫 영웅 만나기", Rect2(34, 419, 438, 60), Callable(main, "_build_hero_select_screen"), true)
	next.grab_focus.call_deferred()

static func ready(main, names: Array[String]) -> void:
	main._clear_screen()
	main.active_screen = "party_ready"
	var root: Control = main.content_root
	var w: float = main._layout_width()
	UI._text(main, root, "원정대 준비 완료", Rect2(48, 40, w - 96, 51), 35, UI.INK)
	UI._text(main, root, "%d명의 영웅과 함께 다음 모험으로 떠나세요." % names.size(), Rect2(50, 102, w - 100, 32), 18, UI.MUTED)
	var ids: Array = []
	for hero in main.deployed_heroes.slice(0, 5):
		ids.append(str(hero.get("id", "")))
	var scene := UI._scene(main, root, Rect2(48, 162, 424, 411), ids, true)
	UI._badge(main, scene, "STAGE %02d" % main.idle_stage, Rect2(22, 22, 123, 34), UI.PAPER, UI.GREEN)
	var zone_panel := UI._panel(main, scene, Rect2(22, 77, 380, 84), Color(UI.PAPER, 0.95), Color.TRANSPARENT, 16)
	var zone: Dictionary = main._current_zone()
	UI._text(main, zone_panel, str(zone.get("name", "회색 초원")), Rect2(18, 8, 344, 35), 26, UI.INK)
	UI._text(main, zone_panel, "권장 전투력 %d" % int(zone.get("power", 0)), Rect2(18, 49, 344, 24), 15, UI.MUTED)
	var panel := UI._panel(main, root, Rect2(496, 162, w - 544, 411), UI.PAPER, UI.BORDER, 22)
	UI._text(main, panel, "함께할 영웅", Rect2(23, 17, 370, 34), 22, UI.INK)
	UI._text(main, panel, "전투력 %s" % UI._number(main._calculate_party_power()), Rect2(panel.size.x - 220, 20, 195, 30), 17, UI.GOLD)
	var cell_w := (panel.size.x - 62.0) / 2.0
	for index in range(names.size()):
		var cell := Vector2(23 + (index % 2) * (cell_w + 16), 73 + floori(float(index) / 2.0) * 48)
		var role: String = main._party_slot_name(index)
		UI._text(main, panel, "%02d" % (index + 1), Rect2(cell, Vector2(34, 36)), 17, UI.GREEN)
		UI._text(main, panel, names[index], Rect2(cell + Vector2(43, 0), Vector2(cell_w - 43, 25)), 17, UI.INK)
		UI._text(main, panel, role, Rect2(cell + Vector2(43, 24), Vector2(cell_w - 43, 19)), 13, UI.MUTED)
	var synergy: Dictionary = main._calculate_party_synergy()
	var synergy_panel := UI._panel(main, panel, Rect2(23, 332, panel.size.x - 46, 57), UI.SAGE, Color.TRANSPARENT, 12)
	UI._text(main, synergy_panel, "활성 시너지 · " + str(synergy.get("summary", "")), Rect2(16, 6, synergy_panel.size.x - 32, 46), 16, UI.GREEN, true)
	UI._action(main, root, "영웅 배치 수정", Rect2(48, 602, 210, 56), Callable(main, "_build_hero_select_screen"))
	var start := UI._action(main, root, "%s에서 사냥 시작" % str(zone.get("name", "초원")), Rect2(w - 550, 602, 502, 58), Callable(main, "_build_combat_screen"), true)
	start.grab_focus.call_deferred()
