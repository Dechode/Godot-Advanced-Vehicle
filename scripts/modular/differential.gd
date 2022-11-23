class_name Differential
extends Node

enum DIFF_TYPE {
	SPOOL,
	LSD,
	SALISBURY,
	OPEN,
}

export (DIFF_TYPE) var differential_type = DIFF_TYPE.SPOOL

export var shaft1_path: NodePath
export var shaft2_path: NodePath
export var moment_of_inertia: float = 0.05

export var diff_preload: float = 50.0
export var power_ratio: float = 2.0
export var coast_ratio: float = 1.0

export var clutches: int = 2
export var power_ramp_angle: float = 30.0
export var coast_ramp_angle: float = 60.0

export(float, 0, 10) var final_ratio: float = 3.4

var prev_shaft1_av = 0.0
var prev_shaft2_av = 0.0

var prev_shaft1_tr = 0.0
var prev_shaft2_tr = 0.0

var prev_av_error = 0.0

#var spin = 0.0

var input_gearing: float = 1.0 setget set_input_gearing

onready var shaft1 = get_node(shaft1_path)
onready var shaft2 = get_node(shaft2_path)


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


func set_input_gearing(value):
	input_gearing = value


func apply_torque(input_torque = 0.0, input_inertia = 0.0, delta = 0.0):
	var t = input_torque * final_ratio
	var i = input_inertia + pow(final_ratio * input_gearing, 2) * moment_of_inertia
	
	var i_total = shaft1.moment_of_inertia + shaft2.moment_of_inertia + i
	
	if not shaft1 is WheelSusp:
		shaft1.set_input_gearing(input_gearing * final_ratio)
	if not shaft2 is WheelSusp:
		shaft2.set_input_gearing(input_gearing * final_ratio)
	
	var tr1 = shaft1.get_reaction_torque()
	var tr2 = shaft2.get_reaction_torque()
	
	prev_shaft1_tr = tr1
	prev_shaft2_tr = tr2
	
	var net_torque = (tr1 + tr2)
	net_torque += t
	
	var shaft1_av = shaft1.get_spin()
	var shaft2_av = shaft2.get_spin()
	
	var av_error = shaft1_av - shaft2_av
	var t_error = tr1 - tr2
	var t_bias = 0
	
	if tr1 < tr2:
		t_bias = tr1 / tr2 if tr2 != 0 else 0
	else:
		t_bias = tr2 / tr1 if tr1 != 0 else 0
#	print(t_bias)
	
	match differential_type:
		DIFF_TYPE.OPEN:
			var t1 = 0.5 * net_torque + t_error
			var t2 = 0.5 * net_torque - t_error
			prev_shaft1_av = shaft1.apply_torque(t1, i, delta)
			prev_shaft2_av = shaft2.apply_torque(t2, i, delta)
			
		DIFF_TYPE.LSD:
			lsd_drive(net_torque, i, av_error, t_error, t_bias, delta)
			
		DIFF_TYPE.SALISBURY:
			var clutch_packs = clutches * 0.5
			power_ratio = cos(deg2rad(power_ramp_angle)) * (1 + 2 * clutch_packs)
			coast_ratio = cos(deg2rad(coast_ramp_angle)) * (1 + 2 * clutch_packs)
			lsd_drive(net_torque, i, av_error, t_error, t_bias, delta)
			
		DIFF_TYPE.SPOOL:
			solid_axle_drive(net_torque, i_total, delta)
	
	prev_av_error = av_error
	return (prev_shaft1_av + prev_shaft2_av) * 0.5 * final_ratio


func lsd_drive(drive, inertia, av_delta, t_delta, bias, delta):
	var lsd_friction := 1.0 # 0.5
	var ratio := power_ratio if drive > 0.0 else coast_ratio

#	if abs(t_delta) < diff_preload:
	if !abs(t_delta) < diff_preload:
#		lsd_friction = 1
#		print("locking")
#	else:
#		if abs(bias) < ratio:
		if !abs(bias) < ratio:
#			print("locking")
#			lsd_friction = 1
#		else:
#			print("Open")
			lsd_friction = 0.5
	
	var lsd_clutch_torque: float = 0.0
	if drive > 0:
		lsd_clutch_torque = diff_preload * lsd_friction #+ 0.5 * drive * lsd_friction
	else:
		lsd_clutch_torque = diff_preload * lsd_friction * 0.5 #+ 0.5 * -drive * lsd_friction
	
	var t1 := 0.0
	var t2 := 0.0
	
	if av_delta > 0:
		t1 = 0.5 * drive - lsd_clutch_torque 
		t2 = 0.5 * drive + lsd_clutch_torque 
	else:
		t1 = 0.5 * drive + lsd_clutch_torque 
		t2 = 0.5 * drive - lsd_clutch_torque 
	
	prev_shaft1_av = shaft1.apply_torque(t1, inertia, delta)
	prev_shaft2_av = shaft2.apply_torque(t2, inertia, delta)


func solid_axle_drive(drive, inertia, delta):
	var shaft1_av = shaft1.get_spin()
	var shaft2_av = shaft2.get_spin()
	
	var avg_axle_spin = (shaft1_av + shaft2_av) * 0.5 #* (1 / final_ratio)
	var spin = avg_axle_spin + (delta * 0.5 * drive / inertia) * (1 / final_ratio)
	
	if shaft1 is WheelSusp and shaft2 is WheelSusp:
		shaft1.apply_spin(spin)
		shaft2.apply_spin(spin)
#	else:
#		shaft1.apply_torque(drive * 0.5, inertia, delta)
#		shaft2.apply_torque(drive * 0.5, inertia, delta)


func get_spin():
	return (prev_shaft1_av + prev_shaft2_av) * 0.5 * final_ratio


func get_reaction_torque():
	return (prev_shaft1_tr + prev_shaft2_tr) * 0.5 * (1 / final_ratio)
