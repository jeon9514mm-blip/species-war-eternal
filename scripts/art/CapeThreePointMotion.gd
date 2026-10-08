extends RefCounted
## Five pinned-chain controls for a painted cape strip. Offsets stay in screen pixels.
## Capsule and nonadjacent-point collision are analytic, not a full cloth surface solver.
const POINT_COUNT:=5
const STIFFNESS:=.12
const DAMPING:=.88
const WIND:=.12
const REST_LENGTH:=2.2
const BODY_CENTER:=Vector2(-.85,2.2)
const BODY_RADIUS:=.72
const SELF_RADIUS:=.40
var points: Array[Vector2]=[Vector2.ZERO,Vector2.ZERO,Vector2.ZERO,Vector2.ZERO,Vector2.ZERO]
var velocities: Array[Vector2]=[Vector2.ZERO,Vector2.ZERO,Vector2.ZERO,Vector2.ZERO,Vector2.ZERO]
var collision_corrections:=0
func advance(delta: float,time: float,movement: float,seed: float) -> Array[Vector2]:
	var dt:=minf(.04,maxf(0,delta))
	if dt<=0:return points
	var chain: Array[Vector2]=[]
	for i in POINT_COUNT:chain.append(Vector2(0,float(i)*REST_LENGTH)+points[i])
	chain[0]=Vector2.ZERO;points[0]=Vector2.ZERO;velocities[0]=Vector2.ZERO
	for i in range(1,POINT_COUNT):
		var weight:=float(i)/float(POINT_COUNT-1)
		var target:=Vector2(sin(time*2.3+seed-weight*2.2)*(1.25+movement*.6)*weight+sin(time*1.1+seed)*WIND*weight,cos(time*1.6+seed-weight*1.6)*.18*weight)
		velocities[i]+=(target-points[i])*(STIFFNESS*240.0)*dt
		velocities[i]*=pow(DAMPING,dt*60.0)
		chain[i]+=velocities[i]*dt
	for _pass_index in 3:
		chain[0]=Vector2.ZERO
		for i in range(1,POINT_COUNT):
			var link:=chain[i]-chain[i-1];var length:=link.length()
			if length>.00001:
				var correction:=link*(1.0-REST_LENGTH/length)
				chain[i]-=correction*(1.0 if i==1 else .5)
				if i>1:chain[i-1]+=correction*.5
			# A small torso capsule keeps the anchored strip from passing through its root.
			var from_body:=chain[i]-BODY_CENTER
			if from_body.length()<BODY_RADIUS:
				chain[i]=BODY_CENTER+(from_body.normalized() if from_body.length()>.00001 else Vector2.RIGHT)*BODY_RADIUS;collision_corrections+=1
		for i in range(1,POINT_COUNT):
			for j in range(i+2,POINT_COUNT):
				var apart:=chain[j]-chain[i];var length:=apart.length()
				if length<SELF_RADIUS*2.0:
					var correction:=(apart.normalized() if length>.00001 else Vector2.DOWN)*(SELF_RADIUS*2.0-length)*.5
					chain[j]+=correction;chain[i]-=correction;collision_corrections+=1
	for i in range(1,POINT_COUNT):
		var previous:=points[i]
		points[i]=(chain[i]-Vector2(0,float(i)*REST_LENGTH)).limit_length(2.6)
		velocities[i]=(points[i]-previous)/dt
	return points
