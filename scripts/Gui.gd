extends Control



onready var car = get_parent()
onready var speedlabel = $Panel/VBoxContainer/Speedlabel
onready var gearlabel = $Panel/VBoxContainer/GearLabel
onready var rpmlabel = $Panel/VBoxContainer/RpmLabel
onready var fuellabel = $Panel/VBoxContainer/FuelLabel


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	speedlabel.text = str("Speed = ") + str(int(car.speedo))
	gearlabel.text = str("gear = ") + str(car.selected_gear)
	rpmlabel.text = str("RPM = ") + str(int(car.rpm))
	fuellabel.text = "Fuel = %3.2f" % car.fuel
