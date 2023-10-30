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
@export var heating_multiplier := 0.0015
@export var cooling_multiplier := -0.25

var tire_wear := 0.0
var load_sensitivity := 1.0
var tire_temp := 20.0


func _init() -> void:
	var point_pos := TIRE_TEMP_MU.get_point_position(1)
	var new_point_offset := opt_tire_temp / max_tire_temp
	TIRE_TEMP_MU.set_point_offset(1, new_point_offset)


# Override this
func update_tire_forces(_slip: Vector2, _normal_load: float, _surface_mu: float) -> Vector3:
	return Vector3.ZERO


func update_tire_wear(delta: float, slip: Vector2, normal_load: float, mu: float):
	tire_wear += slip.length() * mu * delta * normal_load / 7000000.0
	tire_wear = clampf(tire_wear, 0 ,1)
	return tire_wear


func update_load_sensitivity(normal_load: float) -> float:
	var load_factor := normal_load / tire_rated_load
	load_sensitivity = clampf(lerpf(load_sens0, load_sens1, load_factor), 0.2, load_sens0)
	
	return load_sensitivity


func update_tire_temp(slip, normal_load, speed, mu, ambient_temp, delta):
	var delta_temp := 0.0
	# Heating
	if abs(speed) > 1.0:
		delta_temp += slip.length() * normal_load * mu * heating_multiplier * delta
	# Cooling
	var cooling: float = cooling_multiplier * (tire_temp / ambient_temp)
	delta_temp += cooling * delta
	# Clamp the temps
	var max_delta_temp_per_frame := 0.1
	delta_temp = clamp(delta_temp, -max_delta_temp_per_frame, max_delta_temp_per_frame)
	tire_temp = clampf(tire_temp + delta_temp, ambient_temp, max_tire_temp)
	return tire_temp
