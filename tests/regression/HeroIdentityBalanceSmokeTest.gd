extends SceneTree

func _fail(message: String) -> void:
	push_error(message)
	quit(1)

func _init() -> void:
	var catalog = HeroIdentityCatalog.new()
	var aurelia = ["leonhardt","mira","elisia","kairen","orwin","seria","astel","darius","lunea","caelum"]
	var noxfera = ["valeria","morgas","ragna","bron","nyx","fenris","isolde","garm","veyra","ulric"]
	var a_avg = catalog.faction_average(aurelia)
	var n_avg = catalog.faction_average(noxfera)
	var gap = absf(a_avg - n_avg) / maxf(0.01, (a_avg + n_avg) * 0.5)
	if gap > 0.03:
		_fail("V19: 진영 평균 전투 예산 차이가 3% 초과")
		return
	for hero_id in aurelia + noxfera:
		var budget = catalog.balance_budget(hero_id)
		if budget < 0.93 or budget > 1.04:
			_fail("V19: 영웅 개별 전투 예산 범위 초과 %s %.3f" % [hero_id,budget])
			return
		var profile = catalog.profile(hero_id)
		if str(profile.get("identity","")).is_empty() or str(profile.get("ai_style","")).is_empty():
			_fail("V19: 영웅 정체성/AI 성향 누락 %s" % hero_id)
			return
	print("hero_identity_balance_smoke_test_ok faction_gap=%.2f%% all_heroes=balanced" % (gap * 100.0))
	quit(0)
