class_name Brakes
extends Node

export var max_braking_force: float = 2000

export var wheel_fl_path: NodePath
export var wheel_fr_path: NodePath
export var wheel_bl_path: NodePath
export var wheel_br_path: NodePath


onready var wheel_fl = get_node(wheel_fl_path)
onready var wheel_fr = get_node(wheel_fr_path)
onready var wheel_bl = get_node(wheel_bl_path)
onready var wheel_br = get_node(wheel_br_path)

var brake_input = 0.0
 
# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	Input.get_action_strength("Brake")


func _physics_process(delta):
	var rear_brake_force = brake_input * max_braking_force * 0.5
	var front_brake_force = brake_input * max_braking_force * 0.5
	
	wheel_bl.apply_brakes(rear_brake_force, delta)
	wheel_br.apply_brakes(rear_brake_force, delta)
	wheel_fl.apply_brakes(front_brake_force, delta)
	wheel_fr.apply_brakes(front_brake_force, delta)
