extends Control



@onready var car = get_parent()
@onready var speedlabel = $Essentials/VBoxContainer/Speedlabel
@onready var gearlabel = $Essentials/VBoxContainer/GearLabel
@onready var rpmlabel = $Essentials/VBoxContainer/RpmLabel
@onready var fuellabel = $Essentials/VBoxContainer/FuelLabel


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	speedlabel.text = str("Speed = ") + str(int(car.speedo))
	gearlabel.text = str("gear = ") + str(car.selected_gear)
	rpmlabel.text = str("RPM = ") + str(int(car.rpm))
	fuellabel.text = "Fuel = %3.2f" % car.fuel
