class_name CurveTireModel
extends BaseTireModel

const buildup = preload("res://scenes/vehicle/tire_models/buildup_curve.tres")
const falloff = preload("res://scenes/vehicle/tire_models/falloff_curve.tres")

@export_range(0.0, 1.0) var tire_stiffness := 0.5


func update_tire_forces(slip: Vector2, normal_load: float, surface_mu: float = 1.0) -> Vector3:
	var wear_mu := TIRE_WEAR_CURVE.sample_baked(tire_wear)
	var temp_mu := TIRE_TEMP_MU.sample_baked(tire_temp / max_tire_temp)
	load_sensitivity = update_load_sensitivity(normal_load)
	var mu := surface_mu * wear_mu * temp_mu * load_sensitivity
#	var mu := ((surface_mu * wear_mu * temp_mu) + load_sensitivity) * 0.5
	
#	update_tire_temp(slip, normal_load, surface_mu, delta)
	
	print_debug(mu)
	
	var load_factor := normal_load / tire_rated_load
	var peak_sa_deg: float = lerp(12.0, 3.0, tire_stiffness)
	var delta_sa_deg: float = lerp(4.0, 0.8, tire_stiffness)
	
	var sa0 := peak_sa_deg + 0.5 * delta_sa_deg
	var sa1 := peak_sa_deg - 0.5 * delta_sa_deg
	var peak_sa := deg_to_rad(lerp(sa1, sa0, load_factor))
	var peak_sr := peak_sa * 0.7
	
	var normalised_sr := slip.y / peak_sr
	var normalised_sa := slip.x / peak_sa
	var resultant_slip := sqrt(pow(normalised_sr, 2) + pow(normalised_sa, 2))
#
	var sr_modified := resultant_slip * peak_sr
	var sa_modified := resultant_slip * peak_sa
	
	var tire_forces := Vector3.ZERO
	
	if abs(slip.x) < peak_sa:
		tire_forces.x = buildup.sample_baked(resultant_slip) * sign(slip.x)
	else:
		tire_forces.x = falloff.sample_baked(sa_modified - peak_sa) * sign(slip.x)
		
	if abs(slip.y) < peak_sr:
		tire_forces.y = buildup.sample_baked(resultant_slip) * sign(slip.y)
	else:
		tire_forces.y = falloff.sample_baked(sr_modified - peak_sr) * sign(slip.y)
	
	tire_forces *= mu * normal_load
	
	if resultant_slip != 0:
		tire_forces.x *= abs(normalised_sa / resultant_slip)
		tire_forces.y *= abs(normalised_sr / resultant_slip)
	
	return tire_forces
