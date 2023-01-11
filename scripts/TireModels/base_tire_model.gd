class_name BaseTireModel
extends Resource

const TIRE_WEAR_CURVE = preload("res://resources/tire_wear_curve.tres")

export(float, 0.0 ,1.0) var tire_softness = 0.5
export var tire_width := 0.25
export var tire_radius := 0.3

# Possible input parameters for tire model
#export var tire_rated_pressure := 2.0

var tire_wear := 0.0
var force_vec := Vector3.ZERO # x=lateral force, y=longitudinal force, z=self aligning torque
var mu := 1.0

# Possible variables to be used in force calculations
#var load_sensitivity := 1.0
#var tire_temperature := 280.0 # Kelvin
#var tire_pressure := 2.0
#var tire_ratio := 0.5
#var tire_rim_size := 16.0


#func _ready():
#	pass


# Override this
func get_tire_forces(slip: Vector2, normal_load: float) -> Vector3:
	return Vector3.ZERO


func update_tire_wear(delta: float):
	
	pass
