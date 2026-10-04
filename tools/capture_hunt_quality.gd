extends SceneTree
## Linux review fixture. Run with temporary XDG data/config/cache directories.
var game: Node
var out: String
func _init() -> void:run.call_deferred()
func settle() -> void:
 for i in 8:await process_frame
func run() -> void:
 root.content_scale_size=Vector2i(1280,720);root.size=Vector2i(1280,720)
 out=OS.get_environment('HUNT_CAPTURE_DIR');
 if out.is_empty():out=ProjectSettings.globalize_path('res://checks/hunt-quality/captures')
 DirAccess.make_dir_recursive_absolute(out)
 game=preload('res://scenes/PortraitMain.tscn').instantiate();game.save_state_path='user://hunt-quality-preview-'+str(Time.get_ticks_usec())+'.json';game._offline_checked=true
 root.add_child(game);await settle();game.set_process(false);game.set_physics_process(false)
 game._offline_checked=true;game.selected_faction='aurelia';game.idle_stage=1;game.loot_rng.seed=83067
 var count:=int(OS.get_environment('HUNT_CAPTURE_COUNT'))
 if count<=0:count=3
 game.party_slot_legacy_cap=count
 var ids:Array[String]=[]
 for hero in preload('res://scripts/HeroRosterCatalog.gd').roster('aurelia'):
  if ids.size()<count:ids.append(str(hero.id))
 game._restore_deployed_heroes(ids);game.sound_effects_enabled=false;game.combat_effects_enabled=true
 if OS.get_environment('HUNT_CAPTURE_SMALL_SCREEN')=='1':
  root.size=Vector2i(720,405)
 game._build_combat_screen();await settle();game.combat_running=true
 if OS.get_environment('HUNT_CAPTURE_SMALL_SCREEN')=='1':root.size=Vector2i(720,405);await settle()
 for n in 220:
  game._advance_auto_hunt(.1)
  await create_timer(.1).timeout
  if n in [5,65,130,200]:
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(out.path_join('hunt-%03d.png'%n))
   print('CAPTURE ',n,' camera=',game.combat_labels.terrain.camera.size,' alive=',game._enemy_wave_alive_count())
 game.presentation_runtime.audio.shutdown();game.queue_free();await create_timer(.4).timeout;quit()
