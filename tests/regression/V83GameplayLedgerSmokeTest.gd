extends SceneTree
const LEDGER = preload("res://scripts/combat/ChallengeCombatLedger.gd")
const CATALOG = preload("res://scripts/heroes/HeroRosterCatalog.gd")
var checks: int = 0
var failures: Array[String] = []
func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok: failures.append(note); push_error(note)
func _init() -> void: _run.call_deferred()
func _run() -> void:
	for faction in ["aurelia", "noxfera"]:
		var roster: Array = CATALOG.roster(faction)
		roster.resize(10)
		var states: Dictionary = {}
		for i in roster.size():
			var hero: Dictionary = roster[i]
			states[hero.id] = {"slot": i, "hp": 100, "max_hp": 100, "role_group": hero.role_group}
		var ledger = LEDGER.new()
		ledger.begin(roster, states, true, true)
		check(ledger.actors.size() == 10, "ten actors " + faction)
		ledger.begin_wave(1, [{"id":"one","hp":100}, {"id":"two","hp":100}])
		check(ledger.damage(1,"one",100,60,3,false)==40, "effective hit")
		check(ledger.damage(1,"one",100,60,3,false)==0, "duplicate callback ignored")
		check(ledger.damage(0,"one",60,20,3,false)==0, "old wave ignored")
		check(ledger.damage(1,"missing",60,20,3,false)==0, "unregistered enemy ignored")
		check(ledger.damage(1,"one",60,-5,3,false)==0, "negative HP rejected")
		check(ledger.damage(1,"one",60,80,3,false)==0, "HP gain ignored")
		ledger.begin_wave(1,[{"id":"one","hp":100}])
		check(ledger.damage(1,"one",100,60,3,false)==0, "same token cannot reopen HP")
		check(ledger.damage(1,"one",60,0,-1,true)==60, "guardian finishing blow")
		check(ledger.damage(1,"two",100,80,99,false)==20, "unknown source explicit")
		ledger.incoming(str(roster[0].id),100,50,20,2.0)
		ledger.healed(str(roster[0].id),10,60)
		ledger.incoming(str(roster[0].id),60,0,0,5.0)
		states[roster[0].id].hp = 0
		var report: Dictionary = ledger.snapshot({"mode":"tower","reason":"party_defeated","elapsed":10.0,"entry":{"faction":faction,"floor":5}},states)
		check(report.total_damage==120 and report.support_damage==60 and report.unknown_damage==20,"all sources partitioned")
		check(is_equal_approx(report.dps,12.0),"elapsed denominator")
		check(report.alive==9,"survival from actual final HP")
		var first: Dictionary = ledger.actors[roster[0].id]
		check(first.damage_taken==110 and first.healing_received==10 and first.shield_absorbed==20,"taken / received heal / absorbed semantics")
		check(is_equal_approx(first.first_down_at,5.0),"first down timestamp")
		check(ledger.actors[roster[3].id].damage==40,"slot maps correct hero, not first")
		check(ledger.damage(1,"two",80,0,1,false)==0,"closed ledger cannot grow")
		var frozen: int = int(ledger.actors[roster[3].id].damage)
		report.actors[0].damage=999999
		check(int(ledger.actors[roster[3].id].damage)==frozen,"snapshot deep copied")
		check(LEDGER.capabilities(roster+roster).size==10,"duplicate actor filtering")
		ledger.begin(roster,states,false,false)
		ledger.begin_wave(2,[{"id":"same","hp":40}])
		check(ledger.damage(2,"same",40,0,0,false)==40,"fresh session reset")
		ledger.begin_wave(3,[{"id":"same","hp":40}])
		check(ledger.damage(3,"same",40,0,1,false)==40,"new wave separately credited")
		var zero: Dictionary=ledger.snapshot({"mode":"daily","reason":"timeout","elapsed":0.0},states)
		check(zero.dps==0.0,"zero time no division")
		check(zero.advice.size()<=3 and str(zero.advice[0].text).contains("자동"),"actionable manual setting warning")
		var cancelled: Array=LEDGER.advice({"reason":"left_screen"})
		check(cancelled.size()==1 and cancelled[0].action=="none","cancellation no false diagnosis")
	check(LEDGER.capabilities([CATALOG.hero("morgas")]).heal==1,"conditional ally-heal passive included")
	check(LEDGER.capabilities([CATALOG.hero("valeria")]).heal==0,"self lifesteal not classified as allied healer")
	var a: Dictionary={"mode":"daily","variant":"boss_hunt","entry":{"faction":"aurelia","zone":"gray_meadow","run_index":0,"hero_ids":["mira"]}}
	var b: Dictionary=a.duplicate(true)
	b.entry.hero_ids=["leonhardt"]
	check(LEDGER.comparison_key(a)==LEDGER.comparison_key(b),"party changes allowed for same-condition comparison")
	for key in ["faction","zone","run_index"]:
		b=a.duplicate(true); b.entry[key]="different"
		check(LEDGER.comparison_key(a)!=LEDGER.comparison_key(b),"different comparison entry "+key)
	b=a.duplicate(true); b.variant="survival"
	check(LEDGER.comparison_key(a)!=LEDGER.comparison_key(b),"different daily variant")
	a={"mode":"weekly","variant":"abyss","entry":{"faction":"aurelia","zone":"gray_meadow","run_index":0,"week":"2026-39"}}
	b=a.duplicate(true); b.entry.week="2026-40"
	check(LEDGER.comparison_key(a)!=LEDGER.comparison_key(b),"different weekly mutator week")
	print("v83_gameplay_ledger checks=%d failures=%s"%[checks,JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)
