extends Control


# Declare member variables here. Examples:
# var a: int = 2
# var b: String = "text"


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	$Panel/VBoxContainer/ThrottleInput.value = Input.get_action_strength("Throttle") * 100
	$Panel/VBoxContainer/BrakeInput.value = Input.get_action_strength("Brake") * 100
	$Panel/VBoxContainer/ClutchInput.value = Input.get_action_strength("Clutch") * 100
	$Panel/VBoxContainer/SteeringInput.value = (Input.get_action_strength("SteerRight") - Input.get_action_strength("SteerLeft")) * 100
	
	#print((Input.get_action_strength("SteerRight") - Input.get_action_strength("SteerLeft")) * 100)


