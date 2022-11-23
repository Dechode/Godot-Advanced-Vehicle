class_name SteeringManager
extends Node

export var wheel_fl_path: NodePath 
export var wheel_fr_path: NodePath 
export var max_steering: float = 0.3

onready var wheel_fl = get_node(wheel_fl_path)
onready var wheel_fr = get_node(wheel_fr_path)

var steering_input = 0.0

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	Input.get_action_strength("SteerLeft") - Input.get_action_strength("SteerRight") 


func _physics_process(delta):
	wheel_fl.steer(steering_input, max_steering)
	wheel_fr.steer(steering_input, max_steering)
