extends RefCounted
class_name LongTermGoalCatalog

## Data-driven goals. Stable IDs are save keys; never reuse an ID for a new reward.
## Guide milestones reuse cumulative progress, not a new counter for each step.
const EVENTS: Array[String] = ["hunt_packs", "daily_clear", "tower_clear", "abyss_clear", "raid_clear"]
const METRICS: Array[String] = ["stage", "hero_level", "tower_best"]
const FACTIONS: Array[String] = ["aurelia", "noxfera"]
const GUIDE_COUNT: int = 100
const TITLES: Dictionary = {
	"hunt_100": "길을 여는 자", "daily_10": "원정의 숙련자", "tower_25": "탑의 등반가",
	"abyss_5": "심연의 관찰자", "collection_15": "진영의 기록자", "journey_100": "백의 여정"
}
static var _guide: Array[Dictionary] = []
static var _achievements: Array[Dictionary] = []

static func _goal(id: String, title: String, metric: String, target: int, gold: int, gems: int, route: String) -> Dictionary:
	return {"id": id, "title": title, "metric": metric, "target": target, "gold": gold, "gems": gems, "route": route}

static func guide() -> Array[Dictionary]:
	if not _guide.is_empty():
		return _guide
	# 20 chapters x 5 milestones: hunting, hero growth, stage, daily, tower.
	for chapter in range(1, 21):
		var entries: Array = [
			["hunt_packs", 5 * chapter * chapter, "사냥 무리 %d회 격파", "hunt"],
			["hero_level", chapter * 5, "영웅 한 명 Lv.%d 달성", "growth"],
			["stage", 1 + (chapter - 1) * 5, "사냥 스테이지 %d 도달", "hunt"],
			["daily_clear", chapter * 2, "일일 던전 누적 %d회 완료 · 소탕 포함", "daily"],
			["tower_best", chapter * 5, "무한탑 %d층 돌파", "tower"]]
		# First 20 learning steps permit tower/raid successes, not only daily quota.
		# Long-term daily-clear goals remain in weekly missions and achievements.
		if chapter <= 4:
			entries[3] = ["challenge_clear", chapter * 2, "던전·탑·심연·레이드 누적 %d회 완료", "tower"]
		for entry in entries:
			var number: int = _guide.size() + 1
			var goal: Dictionary = _goal("guide_%03d" % number, str(entry[2]) % int(entry[1]), str(entry[0]), int(entry[1]), 100 + 20 * chapter, 5 if number % 5 == 0 else 2, str(entry[3]))
			goal["chapter"] = chapter
			goal["number"] = number
			_guide.append(goal)
	return _guide

static func daily() -> Array[Dictionary]:
	return [
		_goal("daily_hunt_10", "사냥 무리 10회 격파", "hunt_packs", 10, 100, 1, "hunt"),
		_goal("daily_hunt_30", "사냥 무리 30회 격파", "hunt_packs", 30, 150, 1, "hunt"),
		_goal("daily_hunt_60", "사냥 무리 60회 격파", "hunt_packs", 60, 200, 2, "hunt"),
		_goal("daily_dungeon_1", "일일 던전 1회 완료 · 소탕 포함", "daily_clear", 1, 150, 1, "daily"),
		_goal("daily_dungeon_3", "일일 던전 3회 완료 · 소탕 포함", "daily_clear", 3, 200, 2, "daily"),
		_goal("daily_challenge_3", "던전·탑·심연·레이드 합계 3회 완료", "challenge_clear", 3, 200, 3, "daily")]

static func weekly() -> Array[Dictionary]:
	return [
		_goal("weekly_hunt_300", "사냥 무리 300회 격파", "hunt_packs", 300, 500, 5, "hunt"),
		_goal("weekly_hunt_800", "사냥 무리 800회 격파", "hunt_packs", 800, 700, 5, "hunt"),
		_goal("weekly_daily_6", "일일 던전 6회 완료 · 소탕 포함", "daily_clear", 6, 600, 5, "daily"),
		_goal("weekly_tower_5", "무한탑 5개 층 완료", "tower_clear", 5, 500, 5, "tower"),
		_goal("weekly_raid_3", "레이드 3회 승리", "raid_clear", 3, 600, 5, "raids"),
		_goal("weekly_abyss_1", "주간 심연 1회 완료", "abyss_clear", 1, 600, 5, "weekly")]

static func achievements() -> Array[Dictionary]:
	if not _achievements.is_empty():
		return _achievements
	var groups: Array = [
		["hunt", "hunt_packs", [10, 100, 1000, 5000], "사냥 무리 %d회", "hunt"],
		["daily", "daily_clear", [1, 10, 50], "일일 원정 %d회", "daily"],
		["tower", "tower_best", [5, 25, 100], "무한탑 %d층", "tower"],
		["abyss", "abyss_clear", [1, 5, 20], "심연 원정 %d회", "weekly"],
		["collection", "discovered", [5, 10, 15], "현재 진영 영웅 %d명 발견", "codex"],
		["journey", "guide_claimed", [25, 100], "가이드 %d개 완료", "goals"]]
	for group in groups:
		var tier: int = 0
		for target: int in group[2]:
			tier += 1
			_achievements.append(_goal("%s_%d" % [group[0], target], str(group[3]) % target, str(group[1]), target, 200 * tier, 5 * tier, str(group[4])))
	return _achievements

static func entries(scope: String) -> Array[Dictionary]:
	match scope:
		"guide": return guide()
		"daily": return daily()
		"weekly": return weekly()
		"achievement": return achievements()
	return []

static func find(scope: String, id: String) -> Dictionary:
	for goal: Dictionary in entries(scope):
		if str(goal["id"]) == id:
			return goal
	return {}
