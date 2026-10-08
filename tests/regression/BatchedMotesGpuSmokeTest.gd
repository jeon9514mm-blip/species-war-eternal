extends SceneTree
## Render changing active counts against a larger cache; this caught a native
## index-buffer overwrite that parsing and static particle counts could not.
const BATCH=preload('res://scripts/presentation/BatchedMotes.gd')
class MoteCanvas:
	extends Control
	var batch:=BATCH.new()
	var active:=1
	func _draw() -> void:
		batch.begin(272)
		for i in active:batch.add(Vector2(12+(i%34)*16,12+(i/34)*18),2+float(i%3),Color(.7,.85,.7,.3))
		batch.draw(self)
func _init() -> void:run.call_deferred()
func run() -> void:
	if DisplayServer.get_name()=='headless':
		var batch:=BATCH.new();batch.begin(272)
		for active in [1,272,2,180,0,41,80,271,7]:
			batch.begin(272)
			for i in active:batch.add(Vector2(i,0),2,Color.WHITE)
			assert(batch._amount==active)
			for index in batch.indices.slice(0,active*36*3):assert(index>=0 and index<active*25)
		print('BATCHED_MOTES_GPU_OK headless_native_render_skipped=true failures=[]');quit();return
	root.content_scale_size=Vector2i(640,360);root.size=Vector2i(640,360)
	var canvas:=MoteCanvas.new();root.add_child(canvas);canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for frame in 90:
		canvas.active=[1,272,2,180,0,41,80,271,7][frame%9]
		canvas.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
		assert(canvas.batch.points.size()==272*25)
		assert(canvas.batch._amount==canvas.active)
	canvas.free();await process_frame
	print('BATCHED_MOTES_GPU_OK frames=90 varying_active_counts=true failures=[]');quit()
