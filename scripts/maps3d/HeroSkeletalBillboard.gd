extends MeshInstance3D
const TOON=preload('res://shaders/ToonRimLight.gdshader')
## GPU-skinned camera-facing artwork. Shares the 2D rig's joints, bind pose and weights.
## No per-hero viewport or per-frame vertex uploads are required.
var rig: Node2D
var bones_3d: Skeleton3D
var surface: StandardMaterial3D
var receives_environment_light:=false
var toon_surface: ShaderMaterial

func bind(source_rig: Node2D) -> void:
	rig=source_rig;name='HeroSkeletalBillboard'
	mesh=rig.make_3d_mesh()
	cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bones_3d=Skeleton3D.new();bones_3d.name='HeroSkeleton3D';add_child(bones_3d)
	var skin_resource:=Skin.new()
	for i in rig.bone_names.size():
		var key: String=rig.bone_names[i]
		bones_3d.add_bone(key)
		bones_3d.set_bone_parent(i,rig.parents[i])
		bones_3d.set_bone_rest(i,rig.transform_3d(rig.bones[key].rest))
		bones_3d.reset_bone_pose(i)
		skin_resource.add_bind(i,rig.transform_3d(rig.rest_globals[i]).affine_inverse())
	self.skeleton=get_path_to(bones_3d)
	skin=skin_resource
	surface=StandardMaterial3D.new();surface.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	surface.cull_mode=BaseMaterial3D.CULL_DISABLED
	surface.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	surface.alpha_scissor_threshold=.10
	surface.albedo_texture=rig.rest_frame.atlas
	surface.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR
	surface.texture_repeat=false
	material_override=surface
	# Conservative culling bound includes a full weapon swing and death slump.
	custom_aabb=AABB(Vector3(-rig.body_height*2,-rig.body_height,-1),Vector3(rig.body_height*4,rig.body_height*3,2))
	rig.rendered_in_3d=true

func set_environment_lighting(enabled: bool) -> void:
	# Painted faces retain a soft fill while receiving the hunting map's light.
	# The lightless painted raid keeps its established unshaded presentation.
	receives_environment_light=enabled
	surface.shading_mode=BaseMaterial3D.SHADING_MODE_PER_PIXEL if enabled else BaseMaterial3D.SHADING_MODE_UNSHADED
	surface.roughness=1.0
	surface.emission_enabled=enabled
	surface.emission=Color(.12,.12,.12)
	surface.emission_texture=surface.albedo_texture if enabled else null
	if enabled:
		toon_surface=ShaderMaterial.new();toon_surface.shader=TOON
		toon_surface.set_shader_parameter('albedo_texture',surface.albedo_texture)
		material_override=toon_surface
	else:
		toon_surface=null;material_override=surface

func sync(camera: Camera3D, pixel_size: float, tint: Color) -> void:
	if not is_instance_valid(rig):return
	var mirror: float=-1.0 if rig.actor.flip_h else 1.0
	basis=camera.global_basis.scaled_local(Vector3(pixel_size*mirror,pixel_size,pixel_size))
	surface.albedo_color=tint*Color(.78,.78,.78,1) if receives_environment_light else tint
	if toon_surface!=null:toon_surface.set_shader_parameter('tint',tint)
	for i in rig.bone_names.size():
		var bone: Bone2D=rig.bones[rig.bone_names[i]]
		bones_3d.set_bone_pose_position(i,Vector3(bone.position.x,-bone.position.y,0))
		bones_3d.set_bone_pose_rotation(i,Quaternion(Vector3.BACK,-bone.rotation))
