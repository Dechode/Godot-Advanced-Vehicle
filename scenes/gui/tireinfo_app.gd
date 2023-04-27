extends Control


@export var wheel_fl_path: NodePath
@export var wheel_fr_path: NodePath
@export var wheel_bl_path: NodePath
@export var wheel_br_path: NodePath


var wheel_fl
var wheel_fr
var wheel_bl
var wheel_br

var wheels_init: int = 0


func _ready() -> void:
	if wheel_fl_path != null:
		wheel_fl = get_node(wheel_fl_path)
		wheels_init += 1
		
	if wheel_fr_path != null:
		wheel_fr = get_node(wheel_fr_path)
		wheels_init += 1
		
	if wheel_bl_path != null:
		wheel_bl = get_node(wheel_bl_path)
		wheels_init += 1
		
	if wheel_br_path != null:
		wheel_br = get_node(wheel_br_path)
		wheels_init += 1

		
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if wheels_init != 4:
		return

	$Panel/VBoxContainer/HBoxContainer/WheelFL/TireWearLabel.text = "%3.1f %% " % float(wheel_fl.tire_wear * 100)
	$Panel/VBoxContainer/HBoxContainer/WheelFR/TireWearLabel.text = "%3.1f %% " % float(wheel_fr.tire_wear * 100)
	$Panel/VBoxContainer/HBoxContainer2/WheelBL/TireWearLabel.text ="%3.1f %% " % float(wheel_bl.tire_wear * 100)
	$Panel/VBoxContainer/HBoxContainer2/WheelBR/TireWearLabel.text ="%3.1f %% " % float(wheel_br.tire_wear * 100)

