class_name GearBox
extends Node


export var gear_ratios: Array
export var moment_of_inertia = 0.1 # Inertia of the whole gearbox
export var output_path: NodePath

var selected_gear: int = 0

onready var output: Differential = get_node(output_path)

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


#func _process(delta: float) -> void:


func set_gear(value):
	selected_gear = value


func get_gear_ratio():
	if selected_gear > gear_ratios.size():
		selected_gear = gear_ratios.size()
	if selected_gear > 0:
		return gear_ratios[selected_gear - 1]
	elif  selected_gear == 0:
		return 0.0
	else:
		return -gear_ratios[0]


func apply_torque(input_torque, input_inertia, delta):
#	print(selected_gear)
	var output_torque = input_torque * get_gear_ratio()
	var ratio = get_gear_ratio()
	var output_inertia = input_inertia + abs(ratio * ratio) * moment_of_inertia
	output.set_input_gearing(ratio)
	return output.apply_torque(output_torque, output_inertia, delta) * ratio


