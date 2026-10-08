extends SceneTree
## Isolated CPU microbenchmark; this is not a renderer FPS measurement.
const FUR=preload('res://scripts/art/PaintedFurLayers.gd')
const CATALOG=preload('res://scripts/art/HuntFrameCatalog.gd')
func _init() -> void:run.call_deferred()
func run() -> void:
	var entry: Dictionary=CATALOG.new().load_entry('wild_dog')
	var texture: Texture2D=load(entry.motion.atlas)
	var fur:=FUR.new();root.add_child(fur);fur.configure(false,'wild_dog')
	for i in 32:fur.present(entry.motion if i%2==0 else entry.attack,i%8,texture,0,4)
	var samples: Array[float]=[]
	for repeat in 5:
		var start:=Time.get_ticks_usec()
		for i in 20000:fur.present(entry.motion if i%2==0 else entry.attack,i%8,texture,float(i)*.016,4)
		samples.append(float(Time.get_ticks_usec()-start)/20000.0)
	print('FUR_CACHE_BENCH '+JSON.stringify({'iterations_per_sample':20000,'samples_usec_per_present':samples,'native_instances':fur.multimesh.instance_count,'geometry_nodes':fur.get_child_count()}))
	fur.present(entry.motion,0,texture,1,4);var idle: Mesh=fur.multimesh.mesh
	fur.present(entry.attack,0,texture,1,4);var attack: Mesh=fur.multimesh.mesh
	fur.present(entry.motion,0,texture,1,4)
	var valid:=idle==fur.multimesh.mesh and idle!=attack
	print('FUR_CACHE_REUSE '+str(idle==fur.multimesh.mesh)+' DISTINCT_ATTACK '+str(idle!=attack))
	fur.free();quit(0 if valid else 1)
