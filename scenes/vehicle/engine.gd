class_name CarEngine
extends Node

const AV_2_RPM: float = 60 / TAU

@export var max_torque := 250.0
@export var rpm_max = 8000.0
@export var rpm_clutch_out = 1500.0
@export var rpm_idle = 900.0
@export var engine_drag = 0.03
@export var engine_brake = 10.0
@export var inertia = 0.25
@export var bsfc = 0.3
@export var torque_curve: Curve = null
@export var sound: AudioStream

var rpm := 0.0
var torque_out := 0.0
var drag_torque := 0.0


func torque_from_curve(p_rpm):
	var rpm_factor = clamp(p_rpm / rpm_max, 0.0, 1.0)
	var torque_factor = torque_curve.sample_baked(rpm_factor)
	return torque_factor * max_torque


func engine_loop(throttle, delta, clutch_reaction_torque):
	drag_torque = engine_brake + rpm * engine_drag
	torque_out = torque_from_curve((rpm) + drag_torque ) * throttle
	var engine_net_torque = torque_out + clutch_reaction_torque - drag_torque
	
	rpm += AV_2_RPM * delta * engine_net_torque / inertia 


