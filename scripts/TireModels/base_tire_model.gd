class_name BaseTireModel
extends Resource

const TIRE_WEAR_CURVE = preload("res://resources/tire_wear_curve.tres")

export(float, 0.0 ,1.0) var tire_stiffness = 0.5

# Possible input parameters for tire model
#export var tire_rated_pressure := 2.0
#export var tire_width := 0.25
#export var tire_radius := 0.3


var tire_wear := 0.0
var load_sensitivity := 1.0

# Possible variables for force calculations
#var tire_temperature := 280.0 # Kelvin
#var tire_pressure := 2.0
#var tire_ratio := 0.5
#var tire_rim_size := 16.0
#var pneumatic_trail = 0.03


# Override this
func update_tire_forces(slip: Vector2, normal_load: float, surface_mu: float) -> Vector3:
	return Vector3.ZERO


func update_tire_wear(delta: float, slip: Vector2, normal_load: float, mu: float):
	var larger_slip = max(abs(slip.x), abs(slip.y))
	tire_wear += larger_slip * mu * delta * normal_load  / (5000000 + tire_stiffness * 10000000)
	tire_wear = clamp(tire_wear, 0 ,1)
	return tire_wear
#	print("Tire Wear = %f" % tire_wear)


func update_load_sensitivity(normal_load: float) -> float:
	var max_mu = 3.0
	var min_mu = 0.5
	var average_load = 5000
	var load_factor = normal_load / average_load
	load_sensitivity = clamp(min_mu + (1 - load_factor) * (max_mu - min_mu), min_mu, max_mu)
	return load_sensitivity
