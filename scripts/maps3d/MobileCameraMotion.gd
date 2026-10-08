extends RefCounted
## Pixel-defined breath/shake and a bounded punch; never changes battle RNG.
const ZOOM:=1.3
const PERIOD:=10.0
const BREATH_PX:=3.0
const OFFSET_Y_PX:=-20.0
var noise:=FastNoiseLite.new()
var clock:=0.0
var shake_age:=1.0
var shake_strength:=5.0
var shake_duration:=.16
var cooldown:=0.0
var punch_age:=1.0
var critical_cooldown:=0.0
func _init() -> void:
	noise.seed=20261007;noise.noise_type=FastNoiseLite.TYPE_PERLIN;noise.frequency=.7
func impact(critical: bool) -> void:
	if (critical and critical_cooldown>0) or (not critical and cooldown>0):return
	# Keep impacts bounded during 10-member volleys. Crits carry the full punch.
	shake_age=0;shake_strength=10 if critical else 5;shake_duration=.16;cooldown=.75;punch_age=0
	if critical:critical_cooldown=1.5
func zoom_punch(effects: bool) -> float:
	return 1.0+.15*sin(clampf(punch_age/.1,0,1)*PI) if effects and punch_age<.1 else 1.0
func advance(delta: float,active: bool,effects: bool) -> Vector2:
	if active:clock+=maxf(0,delta);shake_age+=maxf(0,delta);punch_age+=maxf(0,delta);cooldown=maxf(0,cooldown-delta);critical_cooldown=maxf(0,critical_cooldown-delta)
	var offset:=Vector2(0,OFFSET_Y_PX)
	if effects:offset.y+=sin(clock*TAU/PERIOD)*BREATH_PX
	if effects and shake_age<shake_duration:
		var fade:=1-shake_age/shake_duration
		offset+=Vector2(noise.get_noise_2d(clock*57,0),noise.get_noise_2d(clock*57,90))*shake_strength*fade
	return offset
