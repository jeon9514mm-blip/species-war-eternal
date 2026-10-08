extends SceneTree
## Read catalogs only. Never instantiate Main, a player save or a battle.
const ROSTER=preload('res://scripts/heroes/HeroRosterCatalog.gd')
const IDENTITY=preload('res://scripts/heroes/HeroIdentityCatalog.gd')
const OUTPUT='res://docs/hero-catalog-2026-10-08/hero-catalog.json'
const SLOTS: Array[String]=['passive','a1','a2','ultimate']
func _init() -> void:_export.call_deferred()
func _sha256(bytes: PackedByteArray) -> String:
	var context:=HashingContext.new();context.start(HashingContext.HASH_SHA256);context.update(bytes)
	return context.finish().hex_encode()
func _export() -> void:
	var heroes: Array[Dictionary]=[]
	var identity:=IDENTITY.new()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT.get_base_dir()+'/art'))
	for hero_id in ROSTER.HEROES:
		var hero: Dictionary=ROSTER.hero(str(hero_id))
		var ordered: Array[Dictionary]=[]
		for slot in SLOTS:
			var skill: Dictionary=ROSTER.skill(str(hero_id),slot)
			assert(not skill.is_empty() and str(skill.get('skill',''))!='' and str(skill.get('effect',''))!='','Missing skill '+str(hero_id)+':'+slot)
			ordered.append(skill)
		hero.skills=ordered;hero['identity_profile']=identity.profile(str(hero_id))
		var image_path: String='res://assets/art-direction/full-body-v2/'+str(hero_id)+'/frames.json'
		assert(FileAccess.file_exists(image_path),'Missing original frame metadata '+str(hero_id))
		var frames: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(image_path))
		var sheet: Dictionary=frames.motion
		var pose: Dictionary=sheet.frames[0]
		assert(FileAccess.file_exists(str(sheet.atlas)),'Missing original image '+str(hero_id))
		var source:=Image.load_from_file(ProjectSettings.globalize_path(str(sheet.atlas)))
		assert(not source.is_empty() and source.get_format()==Image.FORMAT_RGBA8,'Expected unchanged RGBA8 original '+str(hero_id))
		assert(_sha256(FileAccess.get_file_as_bytes(str(sheet.atlas)))==str(sheet.image_sha256),'Source image hash mismatch '+str(hero_id))
		var bounds:=Rect2i(int(pose.region[0]),int(pose.region[1]),int(pose.region[2]),int(pose.region[3]))
		assert(Rect2i(Vector2i.ZERO,source.get_size()).encloses(bounds),'Standing frame outside source '+str(hero_id))
		# Native sprite-frame extraction only: no resampling, retouching, recolor,
		# new pixels or effects. Original source atlas remains byte-for-byte intact.
		var standing:=source.get_region(bounds)
		var extracted_path: String=OUTPUT.get_base_dir()+'/art/'+str(hero_id)+'.png'
		assert(standing.save_png(extracted_path)==OK,'Cannot export standing frame '+str(hero_id))
		var exported:=Image.load_from_file(ProjectSettings.globalize_path(extracted_path))
		assert(exported.get_size()==bounds.size and exported.get_format()==source.get_format(),'Exported frame format mismatch '+str(hero_id))
		assert(exported.get_data()==standing.get_data(),'Standing-frame RGBA changed during PNG export '+str(hero_id))
		hero['art']={'atlas':sheet.atlas,'atlas_size':sheet.atlas_size,'idle_region':pose.region,
			'anchor':pose.anchor,'source_metadata':image_path,'pose_index':0,'image_sha256':sheet.image_sha256,
			'presentation':'native Godot export of registered standing sprite frame; no pixel changes',
			'extracted_path':extracted_path,'extracted_size':[bounds.size.x,bounds.size.y],
			'extracted_png_sha256':_sha256(FileAccess.get_file_as_bytes(extracted_path)),
			'source_region_rgba_sha256':_sha256(standing.get_data()),'exported_rgba_sha256':_sha256(exported.get_data()),
			'rgba_identical_to_source_region':true,'pixel_format':'RGBA8'}
		heroes.append(hero)
	assert(heroes.size()==30,'Expected all 30 heroes')
	var result: Dictionary={'schema':1,'exported_date':'2026-10-08','engine':Engine.get_version_info().string,
		'sources':['scripts/heroes/HeroRosterCatalog.gd','scripts/heroes/HeroIdentityCatalog.gd','assets/art-direction/full-body-v2/*/frames.json'],
		'values':'registered base values; identity, progression, equipment and runtime modifiers remain separate',
		'hero_count':heroes.size(),'skill_count':heroes.size()*4,'slot_order':SLOTS,'heroes':heroes}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT.get_base_dir()))
	var file:=FileAccess.open(OUTPUT,FileAccess.WRITE)
	assert(file!=null,'Cannot write hero catalog')
	file.store_string(JSON.stringify(result,'\t',false)+'\n');file.close()
	print('HERO_CATALOG_EXPORT heroes=30 skills=120 standing_frame_pngs=30 rgba_pixel_matches=30 saves_loaded=0')
	quit(0)
