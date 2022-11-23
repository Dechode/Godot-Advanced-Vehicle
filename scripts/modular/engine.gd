class_name CarEngine
extends Spatial

#### Engine related stuff ####
export var max_torque = 250.0
export var max_engine_rpm = 8000.0
export var rpm_idle = 900.0
export var torque_curve: Curve = null
export var engine_drag = 0.03
export var engine_brake = 10.0
export var moment_of_inertia = 0.25
export var engine_sound: AudioStream

export var output_path: NodePath

const AV_2_RPM: float = 60 / TAU

var drag_torque: float = 0.0
var torque_out: float = 0.0

var clutch_reaction_torque: float = 0.0

var rpm: float = 750.0
var throttle: float = 0.0 setget set_throttle, get_throttle

var engine_angular_vel: float = 0.0
var net_torque: float = 0.0

var running: bool = true

onready var output = get_node(output_path)
onready var audioplayer = $EngineSound

# Called when the node enters the scene tree for the first time.
func _ready():
	print("Engine ready")
	rpm = rpm_idle


func set_throttle(value):
	throttle = value

func get_throttle():
	return throttle


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	play_engine_sound()


func _physics_process(delta):
	drag_torque = engine_brake + rpm * engine_drag
	torque_out = (engine_torque(rpm) + drag_torque ) * throttle
	net_torque = torque_out + clutch_reaction_torque - drag_torque
	
	rpm += delta * net_torque * AV_2_RPM / moment_of_inertia
	
	if rpm >= max_engine_rpm:
		rpm -= 500
		
	if rpm < 100:
		rpm = 100
		running = false
	
	rpm = clamp(rpm, 10, max_engine_rpm)
	engine_angular_vel = rpm / AV_2_RPM
	clutch_reaction_torque = output.apply_av(engine_angular_vel, moment_of_inertia, delta)
	if rpm < rpm_idle:
		clutch_reaction_torque = max_torque * 0.1
	

func engine_torque(_rpm):
	var rpm_factor = clamp(_rpm / max_engine_rpm, 0.0, 1.0)
	var torque_factor = torque_curve.interpolate_baked(rpm_factor)
	return torque_factor * max_torque


func play_engine_sound():
	var pitch_scaler = rpm / 1000
	if rpm >= rpm_idle and rpm < max_engine_rpm:
		if audioplayer.stream != engine_sound:
			audioplayer.set_stream(engine_sound)
		if not audioplayer.playing:
			audioplayer.play()
	
	if pitch_scaler > 0.1:
		audioplayer.pitch_scale = pitch_scaler
