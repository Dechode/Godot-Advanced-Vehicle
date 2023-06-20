class_name BaseTireModel
extends Resource

const TIRE_WEAR_CURVE = preload("res://resources/tire_wear_curve.tres")

@export var tire_radius := 0.3
@export var tire_width := 0.205
@export var tire_rated_load := 5500.0
@export var load_sens0 := 2.0
@export var load_sens1 := 1.0


var tire_wear := 0.0
var load_sensitivity := 1.0


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
