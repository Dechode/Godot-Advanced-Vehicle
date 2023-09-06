class_name BaseTireModel
extends Resource

const TIRE_WEAR_CURVE = preload("res://resources/tire_wear_curve.tres")
const TIRE_TEMP_MU = preload("res://scenes/vehicle/tire_models/temp_mu.tres")

@export var tire_radius := 0.3
@export var tire_width := 0.205
@export var tire_rated_load := 5500.0
@export var load_sens0 := 1.7
@export var load_sens1 := 0.9
@export var max_tire_temp := 150.0
@export var opt_tire_temp := 90.0

var tire_wear := 0.0
var load_sensitivity := 1.0
var tire_temp := 20.0


# Override this
func update_tire_forces(_slip: Vector2, _normal_load: float, _surface_mu: float) -> Vector3:
	return Vector3.ZERO


func update_tire_wear(delta: float, slip: Vector2, normal_load: float, mu: float):
	tire_wear += slip.length() * mu * delta * normal_load  / 7000000
	tire_wear = clamp(tire_wear, 0 ,1)
	return tire_wear


func update_load_sensitivity(normal_load: float) -> float:
	var load_factor = clamp(normal_load / tire_rated_load, 0.0, 1.0)
	load_sensitivity = lerp(load_sens0, load_sens1, load_factor)
	return load_sensitivity


func update_tire_temp(slip, normal_load, speed, mu, delta):
	var ambient_temp := 20.0
	var heating_multiplier = 0.0015
	var cooling_multiplier = -0.25 * (tire_temp / ambient_temp)
	var low_speed_mult = clampf(speed / 2.0, 0.0, 1.0)
	
	tire_temp += slip.length() * normal_load * mu * heating_multiplier * low_speed_mult * delta
	tire_temp += cooling_multiplier * delta
	
	tire_temp = clampf(tire_temp, ambient_temp, max_tire_temp)
	
	return tire_temp
