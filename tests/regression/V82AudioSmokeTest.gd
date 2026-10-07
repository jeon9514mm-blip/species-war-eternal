extends SceneTree
var checks: int = 0
var failures: Array[String] = []
func _init() -> void: _run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)
func _run() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://audio/v82/manifest.json"))
	check(manifest["tracks"].size() == 24, "24 supplied audio files")
	for key in manifest["tracks"]:
		var entry: Dictionary = manifest["tracks"][key]
		var stream: AudioStream = load("res://" + entry["file"])
		check(stream != null and stream.get_length() > 0.04, "real audio resource decoded: " + key)
		check(absf(stream.get_length() - float(entry["seconds"])) < 0.10, "duration matches decoded manifest: " + key)
	var audio := GameAudioDirector.new(); root.add_child(audio); audio.set_process(false)
	check(audio.get_child_count() == 11 and audio.voices.size() == 8, "fixed 2 music + ambience + 8 cue players")
	audio.configure({}, true); audio.set_scene("meadow", "ambient_meadow"); audio._process(0.7)
	check(audio.music_players[audio._active_music].playing, "music playback actually started in engine mixer")
	check(audio.music_players[audio._active_music].stream.loop, "music looping")
	check(audio.ambient_player.playing and audio.ambient_player.stream.loop, "ambience looping")
	var loads: int = audio.sample_loads
	for i in 100: audio.set_scene("meadow", "ambient_meadow")
	check(audio.sample_loads == loads, "same scene does not reload or restart streams")
	for scene in ["mine", "forest", "boss", "meadow"]:
		audio.set_scene(scene, ""); audio._process(0.7)
		check(audio._music_key == scene and audio.music_players[1 - audio._active_music].stream == null, "crossfade cleans retired stream: " + scene)
	seed(820); var first: int = randi()
	check(audio.play_cue("sword"), "first sword cue accepted")
	var after: int = randi(); seed(820)
	check(randi() == first and randi() == after, "audio never consumes combat RNG")
	check(not audio.play_cue("sword"), "same frame sound spam throttled")
	for index in 500:
		var names: Array = GameAudioDirector.CUES.keys()
		audio.play_cue(str(names[index % names.size()])); audio._process(0.01)
		# Let the real audio mixer drain queued playback removals between bursts.
		if index % 25 == 24: await process_frame
	check(audio.max_active_voices <= 8 and audio.get_child_count() == 11, "500 bursts remain within fixed pool")
	check(audio.suppressed > 0 and audio._cue_cache.size() <= 17, "throttle and sample cache bounded")
	var count: int = audio.accepted
	audio.set_suspended(true); var clock: float = audio._clock; audio._process(10.0)
	check(audio._clock == clock and not audio.play_cue("victory") and audio.accepted == count, "background no playback or catch-up")
	check(audio.active_voice_count() == 0 and audio.music_players[audio._active_music].stream_paused, "background stops cues and pauses music")
	audio.set_suspended(false); audio._process(1.1)
	check(audio.play_cue("victory"), "resume accepts new cues")
	audio.configure({"music_enabled": false}, false)
	check(not audio.play_cue("ui_click") and audio.active_voice_count() == 0, "SFX mute immediate")
	check(audio._music_key.is_empty() and audio.ambient_player.stream == null, "muted looping streams released")
	audio.configure({"effects_volume": 0.0, "ui_volume": 0.55}, true); audio._process(1.0)
	check(not audio.play_cue("sword") and audio.play_cue("ui_click"), "UI volume independent of combat volume")
	print("AUDIO_DIAGNOSTICS "+JSON.stringify(audio.diagnostics()))
	audio.shutdown()
	check(audio.active_voice_count() == 0 and not audio.play_cue("ui_click"), "shutdown stops and rejects new playback")
	check(audio._cue_cache.is_empty() and audio.ambient_player.stream == null, "shutdown releases references")
	# Audio runs on its own thread, not this synthetic combat clock.
	await create_timer(0.3).timeout
	audio.queue_free()
	await create_timer(0.3).timeout
	print("v82_audio checks=%d failures=%s audible_device_test=false" % [checks, JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)
