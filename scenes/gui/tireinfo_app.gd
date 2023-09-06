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

var wheels := []

func _ready() -> void:
	if wheel_fl_path != null:
		wheel_fl = get_node(wheel_fl_path)
		wheels_init += 1
		wheels.append(wheel_fl)
		
	if wheel_fr_path != null:
		wheel_fr = get_node(wheel_fr_path)
		wheels_init += 1
		wheels.append(wheel_fr)
		
	if wheel_bl_path != null:
		wheel_bl = get_node(wheel_bl_path)
		wheels_init += 1
		wheels.append(wheel_bl)
		
	if wheel_br_path != null:
		wheel_br = get_node(wheel_br_path)
		wheels_init += 1
		wheels.append(wheel_br)

		
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if wheels_init != 4:
		return

	$Panel/VBoxContainer/HBoxContainer/WheelFL/TireWearLabel.text = "%3.1f %% " % float(wheel_fl.tire_wear * 100)
	$Panel/VBoxContainer/HBoxContainer/WheelFR/TireWearLabel.text = "%3.1f %% " % float(wheel_fr.tire_wear * 100)
	$Panel/VBoxContainer/HBoxContainer2/WheelBL/TireWearLabel.text ="%3.1f %% " % float(wheel_bl.tire_wear * 100)
	$Panel/VBoxContainer/HBoxContainer2/WheelBR/TireWearLabel.text ="%3.1f %% " % float(wheel_br.tire_wear * 100)
	
	var colors := []
	for wheel in wheels:
		if wheel.tire_model.tire_temp < wheel.tire_model.opt_tire_temp:
			colors.append(lerp(Color.AQUA, Color.GREEN, wheel.tire_model.tire_temp / wheel.tire_model.opt_tire_temp))
		else:
			var amount: float = (wheel.tire_model.tire_temp - wheel.tire_model.opt_tire_temp) / (wheel.tire_model.max_tire_temp - wheel.tire_model.opt_tire_temp)
			colors.append(lerp(Color.GREEN, Color.FIREBRICK, amount))
			
		
	$Panel/VBoxContainer/HBoxContainer/WheelFL/TireTemp.color = colors[0]
	$Panel/VBoxContainer/HBoxContainer/WheelFR/TireTemp.color = colors[1]
	$Panel/VBoxContainer/HBoxContainer2/WheelBL/TireTemp.color = colors[2]
	$Panel/VBoxContainer/HBoxContainer2/WheelBR/TireTemp.color = colors[3]
	
	$Panel/VBoxContainer/HBoxContainer/WheelFL/TireTemp/Label.text = "%2.1f c" % wheel_fl.tire_model.tire_temp
	$Panel/VBoxContainer/HBoxContainer/WheelFR/TireTemp/Label.text = "%2.1f c" % wheel_fr.tire_model.tire_temp
	$Panel/VBoxContainer/HBoxContainer2/WheelBL/TireTemp/Label.text = "%2.1f c" % wheel_bl.tire_model.tire_temp
	$Panel/VBoxContainer/HBoxContainer2/WheelBR/TireTemp/Label.text = "%2.1f c" % wheel_br.tire_model.tire_temp
	
