extends RefCounted
## Original procedural meshes: individual leaves, branches, roots and eroded rocks.
var rng:=RandomNumberGenerator.new()
func triangle(st: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,uv_a:=Vector2.ZERO,uv_b:=Vector2.RIGHT,uv_c:=Vector2.UP) -> void:
	st.set_uv(uv_a);st.add_vertex(a);st.set_uv(uv_b);st.add_vertex(b);st.set_uv(uv_c);st.add_vertex(c)
func rock(seed_value: int) -> ArrayMesh:
	rng.seed=seed_value
	var noise:=FastNoiseLite.new();noise.seed=seed_value;noise.frequency=2.8
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face in 6:
		for y in 7:
			for x in 7:
				var points: Array[Vector3]=[]
				for uv: Vector2 in [Vector2(x,y),Vector2(x+1,y),Vector2(x,y+1),Vector2(x+1,y+1)]:
					var a:=uv.x/7.0*2.0-1;var b:=uv.y/7.0*2.0-1
					var p:=Vector3(1,a,b)
					match face:
						1:p=Vector3(-1,b,a)
						2:p=Vector3(b,1,a)
						3:p=Vector3(a,-1,b)
						4:p=Vector3(a,b,1)
						5:p=Vector3(b,a,-1)
					# Rounded block silhouette with geological ledges and chipped corners.
					p=p.lerp(p.normalized(),.32)
					var erosion:=noise.get_noise_3dv(p)*.18
					p*=1+erosion;p.x+=sin(p.y*15+seed_value)*.035;p.z+=sin(p.y*12+seed_value)*.025
					points.append(p*.5)
				triangle(st,points[0],points[2],points[1]);triangle(st,points[1],points[2],points[3])
	st.generate_normals();return st.commit()
func tube(st: SurfaceTool,points: Array[Vector3],start_radius: float,end_radius: float) -> void:
	var rings: Array=[]
	for j in points.size():
		var direction: Vector3=(points[mini(j+1,points.size()-1)]-points[maxi(j-1,0)]).normalized()
		var side:=direction.cross(Vector3.FORWARD).normalized()
		if side.length()<.1:side=Vector3.RIGHT
		var up:=direction.cross(side).normalized();var ring: Array[Vector3]=[]
		var t:=float(j)/float(points.size()-1);var radius:=lerpf(start_radius,end_radius,t)
		for i in 12:
			var angle:=i*TAU/12.0;var r:=radius*(1.0+.1*sin(i*2.1+j*.3))
			ring.append(points[j]+(side*cos(angle)+up*sin(angle))*r)
		rings.append(ring)
	for j in points.size()-1:
		for i in 12:
			var k: int=(i+1)%12;var a: Vector3=rings[j][i];var b: Vector3=rings[j][k];var c: Vector3=rings[j+1][i];var d: Vector3=rings[j+1][k]
			triangle(st,a,c,b,Vector2(i/12.0,j*.5),Vector2(i/12.0,(j+1)*.5),Vector2((i+1)/12.0,j*.5))
			triangle(st,b,c,d,Vector2((i+1)/12.0,j*.5),Vector2(i/12.0,(j+1)*.5),Vector2((i+1)/12.0,(j+1)*.5))
func leaf(st: SurfaceTool,p: Vector3,dir: Vector3,width: float,length_value: float,tint: Color) -> void:
	var side:=dir.cross(Vector3.UP).normalized()
	if side.length()<.1:side=Vector3.RIGHT
	var tip:=p+dir*length_value
	var mid:=p+dir*length_value*.48+Vector3.UP*width*.16
	st.set_color(tint)
	triangle(st,p,mid-side*width,mid+Vector3.UP*width*.16)
	triangle(st,mid-side*width,tip,mid+Vector3.UP*width*.16)
	triangle(st,p,mid+Vector3.UP*width*.16,mid+side*width)
	triangle(st,mid+side*width,mid+Vector3.UP*width*.16,tip)
func tree(seed_value: int) -> Array[ArrayMesh]:
	rng.seed=seed_value
	var bark:=SurfaceTool.new();bark.begin(Mesh.PRIMITIVE_TRIANGLES)
	var leaves:=SurfaceTool.new();leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
	var trunk: Array[Vector3]=[Vector3.ZERO,Vector3(.14,1,0),Vector3(-.15,2.2,.1),Vector3(.1,3.5,.05),Vector3(.2,4.8,0),Vector3(.1,6,0)]
	tube(bark,trunk,.63,.14)
	for i in 9:
		var a:=i*TAU/9.0;var d:=Vector3(cos(a),0,sin(a))
		var roots: Array[Vector3]=[Vector3(0,.7,0),d*.7+Vector3(0,.2,0),d*1.7+Vector3(0,.10,0),d*2.5]
		tube(bark,roots,.28,.025)
	for i in 12:
		var a:=i*2.4;var d:=Vector3(cos(a),0,sin(a));var y:=2.7+float(i%4)*.7
		var reach:=rng.randf_range(2.0,3.7);var end:=d*reach+Vector3(0,y+1.7,0)
		var limb: Array[Vector3]=[Vector3(0,y,0),d*.7+Vector3(0,y+.2,0),d*(reach*.64)+Vector3(0,y+1.1,0),end]
		tube(bark,limb,.25,.028)
		for j in 210:
			var angle:=rng.randf_range(0,TAU);var v:=rng.randf_range(-1,1);var radial:=pow(rng.randf(),.333)
			var delta:=Vector3(cos(angle)*sqrt(1-v*v)*1.75,v*.85,sin(angle)*sqrt(1-v*v)*1.75)*radial
			var point:=end+delta;var dir:=Vector3(rng.randf_range(-1,1),rng.randf_range(-.2,.7),rng.randf_range(-1,1)).normalized()
			var col:=Color('#44602b').lerp(Color('#9aaa4a'),clampf((delta.y+.9)/1.8,0,1)*rng.randf_range(.45,1))
			leaf(leaves,point,dir,rng.randf_range(.09,.16),rng.randf_range(.28,.49),col)
	bark.generate_normals();leaves.generate_normals()
	return [bark.commit(),leaves.commit()]
func fern() -> ArrayMesh:
	rng.seed=73;var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 9:
		var a:=i*TAU/9;var d:=Vector3(cos(a),0,sin(a))
		for j in 11:
			var t:=float(j)/11.0;var p:=d*t*.95+Vector3(0,sin(t*PI*.9)*.55,0)
			for side in [-1,1]:
				var direction: Vector3=(d*.35+Vector3(-d.z,0,d.x)*side).normalized()
				leaf(st,p,direction,.045,(1-t)*.28+.03,Color('#63813a').lightened(t*.13))
	st.generate_normals();return st.commit()
