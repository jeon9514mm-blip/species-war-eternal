extends RefCounted
## Root, middle, hem: bounded secondary offsets, updated on the battle clock.
var points: Array[Vector2]=[Vector2.ZERO,Vector2.ZERO,Vector2.ZERO]
var velocities: Array[Vector2]=[Vector2.ZERO,Vector2.ZERO,Vector2.ZERO]
func advance(delta: float,time: float,movement: float,seed: float) -> Array[Vector2]:
	var dt:=minf(.04,maxf(0,delta));points[0]=Vector2.ZERO
	for i in [1,2]:
		var target:=Vector2(sin(time*2.3+seed-i*.55)*(1.0+movement*.4)*i*.65,cos(time*1.6+seed-i*.4)*.12*i)
		velocities[i]+=(target-points[i])*dt*35.0;velocities[i]*=exp(-dt*7.0)
		points[i]=(points[i]+velocities[i]*dt).limit_length(1.8)
	return points
