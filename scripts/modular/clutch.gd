class_name Clutch
extends Node

export var clutch_friction: float = 400.0
export var moment_of_inertia: float = 0.01
export var output_path: NodePath

var output: GearBox

var clutch_input: float = 0.0

var prev_output_av: float = 0.0

var input_torque: float = 0.0
var output_torque: float = 0.0

# Called when the node enters the scene tree for the first time.
func _ready():
	print("Clutch ready")
	if get_node(output_path) is GearBox:
		output = get_node(output_path)
	else:
		print("Clutch: GearBox not found")

# TODO

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	clutch_input = InputManager.get_clutch_input()


func apply_av(input_av, input_inertia, delta):
	var output_av = prev_output_av
	var output_inertia = input_inertia + moment_of_inertia
	
	var av_error = input_av - output_av
	var kick = abs(av_error) * 0.2
	var clutch_torque: float = (clutch_friction + kick) * (1 - clutch_input)
	
	if input_av > output_av:
		input_torque = -clutch_torque
		output_torque = clutch_torque
	else:
		input_torque = clutch_torque
		output_torque = -clutch_torque
	
	if output.selected_gear == 0:
		input_torque = 0.0
		output_torque = 0.0
		clutch_input = 1.0
	
	prev_output_av = output.apply_torque(output_torque, output_inertia, delta)
	
	return input_torque
