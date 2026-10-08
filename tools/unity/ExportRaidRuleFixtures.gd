extends SceneTree
## Compile only selected production raid functions into a save-free adapter.
## Never instantiate Main, its scene, SaveStore or player economy services.
const DESIGN=preload("res://scripts/raid/RaidBossDesign.gd")
const FIELD=preload("res://scripts/raid/RaidBattlefield.gd")
const BALANCE=preload("res://scripts/raid/RaidBalance.gd")
func _initialize() -> void:
	var text:=FileAccess.get_file_as_string("res://scripts/app/Main.gd")
	var adapter_source:="""extends Node
class Report extends RefCounted:
	func add(_context,_id,_field,_amount): pass
var RAID_REPORT=Report.new()
var raid_running=true
var raid_boss_hp=10000
var raid_boss_max_hp=10000
var raid_boss_attack=100
var raid_phase=1
var raid_encounter_zone="gray_meadow"
var raid_last_mechanic_phase=0
var raid_guard_hp=0
var raid_guard_max_hp=0
var raid_guard_breaks=0
var raid_add_hp=0
var raid_add_max_hp=0
var raid_add_count=0
var raid_add_attack_remaining=0.0
var raid_add_waves_cleared=0
var raid_dps_check_remaining=0.0
var raid_dps_check_target=0
var raid_dps_check_damage=0
var raid_dps_checks_passed=0
var raid_dps_checks_failed=0
var raid_mechanic_rage_stacks=0
var raid_break_gauge=0.0
var raid_break_gauge_max=100.0
var raid_control_immunity=0.0
var raid_interrupt_count=0
var raid_enraged=false
var raid_second_wave_remaining=0.0
var raid_second_wave_profile={}
var raid_second_wave_shape={}
var raid_cast_profile={}
var raid_pattern_shape={}
var raid_boss_attack_remaining=0.0
var raid_damage_dealt=0
var raid_hit_fx_remaining=0.0
var raid_event_text=""
var boss_telegraph_pending=false
var boss_telegraph_remaining=0.0
var boss_telegraph_skill="fixture"
var _stun_seconds=0.0
var _vulnerable_seconds=0.0
var combat_effects_enabled=false
var raid_boss_sprite=null
var combat_fx=null
var content_root=null
var GOLD=Color.YELLOW
var crit_chance=0.0
var loot_rng=RandomNumberGenerator.new()
func _raid_mechanic_profile(_zone="",_phase=-1): return preload("res://scripts/raid/RaidBossDesign.gd").mechanic(raid_encounter_zone,raid_phase)
func _guardian_bonus(_key):return crit_chance
func _select_raid_hero_target(_mode):return ""
func _incoming_damage_to_hero(_target,_amount):return 0
func _hero_short_name(id):return id
func _presentation_event(_name):pass
func _spawn_floating_combat_text(_text,_color,_position):pass
var raid_boss_position=Vector2.ZERO
"""
	var names:=["_raid_activate_phase_mechanic","_raid_record_dps_check","_raid_advance_mechanics","_raid_attack_multiplier","_raid_attack_interval","_raid_control_window","_raid_apply_control","_raid_performance_crystal_bonus","_apply_raid_damage"]
	for name in names:
		var start:=text.find("func "+name+"(")
		if start<0:push_error("Production raid function missing: "+name);quit(1);return
		var end:=text.find("\nfunc ",start+1)
		adapter_source+="\n"+text.substr(start,(end if end>=0 else text.length())-start)+"\n"
	var script:=GDScript.new();script.source_code=adapter_source
	if script.reload()!=OK:push_error("Isolated production raid adapter failed to compile");quit(1);return
	var settlements:=[];var controls:=[];var expiries:=[];var footprints:=[]
	var powers:={"gray_meadow":180,"forgotten_mine":360,"moonrest_forest":620}
	for zone in powers:
		var stats:=BALANCE.stats({"power":powers[zone]})
		for phase in [1,2,3]:
			for raw in [0,1,177,int(stats.max_hp*.04),int(stats.max_hp*.15)+101,stats.max_hp*2]:
				for vulnerable in [false,true]:
					for critical in [false,true]:
						var a=script.new();a.raid_encounter_zone=zone;a.raid_boss_max_hp=stats.max_hp;a.raid_boss_hp=int(stats.max_hp*([.95,.59,.29][phase-1]));a.raid_phase=phase;a._raid_activate_phase_mechanic(phase);a._vulnerable_seconds=1.0 if vulnerable else 0.0;a.crit_chance=1.0 if critical else 0.0
						var first=a._apply_raid_damage(raw,"fixture");var second=a._apply_raid_damage(101,"fixture")
						settlements.append({"zone":zone,"phase":phase,"raw":raw,"vulnerable":vulnerable,"critical":critical,"first":first,"second":second,"state":state(a)})
						a.free()
			if zone=="moonrest_forest" and phase>1:
				var a=script.new();a.raid_encounter_zone=zone;a.raid_phase=phase;a.raid_boss_max_hp=stats.max_hp;a.raid_boss_hp=int(stats.max_hp*(.59 if phase==2 else .29));a._raid_activate_phase_mechanic(phase);a._raid_advance_mechanics(20.0);expiries.append({"phase":phase,"state":state(a)});a.free()
	for warning in [false,true]:
		for low_hp in [false,true]:
			for immune in [false,true]:
				for duration in [.05,.3,1.0,4.0]:
					var a=script.new();a.raid_boss_hp=1000 if low_hp else 10000;a.boss_telegraph_pending=warning;a.raid_control_immunity=6.0 if immune else 0.0
					var window=a._raid_control_window();var accepted=a._raid_apply_control(duration,"fixture")
					controls.append({"warning":warning,"low_hp":low_hp,"immune":immune,"duration":duration,"window":window,"accepted":accepted,"stun":a._stun_seconds,"vulnerable":a._vulnerable_seconds,"immunity":a.raid_control_immunity,"gauge":a.raid_break_gauge,"interrupts":a.raid_interrupt_count,"pending":a.boss_telegraph_pending});a.free()
	for kind in ["aoe","cone","earthquake","curse","moon_mark","front_blast","rear_blast","double_lane","cross"]:
		var shape:=FIELD.footprint(kind,FIELD.ENTRY,[Vector2(340,338),Vector2(532,426)],{})
		var points:=[]
		for x in range(214,825,31):
			for y in range(280,487,17):
				var point:=Vector2(x,y);var escape:=FIELD.escape_position(shape,point)
				points.append({"point":[x,y],"contains":FIELD.contains(shape,point),"escape":[escape.x,escape.y]})
		footprints.append({"kind":kind,"points":points})
	var report:={"source":"Actual extracted Main raid functions + original RaidBattlefield/RaidBalance","main_sha256":text.sha256_text(),"settlements":settlements,"controls":controls,"expiries":expiries,"footprints":footprints}
	DirAccess.make_dir_recursive_absolute("res://Unity/Assets/Game/Editor/Fixtures")
	var file:=FileAccess.open("res://Unity/Assets/Game/Editor/Fixtures/raid-rule-fixtures.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  ",true));file.close()
	print("RAID_FIXTURES_EXPORTED settlements=",settlements.size()," controls=",controls.size()," footprints=",footprints.size());quit()
func state(a) -> Dictionary:
	return {"hp":a.raid_boss_hp,"guard":a.raid_guard_hp,"guard_breaks":a.raid_guard_breaks,"adds":a.raid_add_hp,"add_count":a.raid_add_count,"add_waves":a.raid_add_waves_cleared,"dps_remaining":a.raid_dps_check_remaining,"dps_damage":a.raid_dps_check_damage,"dps_passed":a.raid_dps_checks_passed,"dps_failed":a.raid_dps_checks_failed,"vulnerable":a._vulnerable_seconds,"damage":a.raid_damage_dealt,"rage":a.raid_mechanic_rage_stacks,"enraged":a.raid_enraged}
