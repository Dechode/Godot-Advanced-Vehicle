class_name PacejkaTireModel
extends BaseTireModel


func pacejka(slip, B, C, D, E, normal_load):
	return normal_load * D * sin(C * atan(B * slip - E * (B * slip - atan(B * slip))))


func update_tire_forces(slip: Vector2, normal_load: float, surface_mu: float):
	var wear_mu = TIRE_WEAR_CURVE.interpolate_baked(tire_wear)
	load_sensitivity = update_load_sensitivity(normal_load)
	var mu = surface_mu * load_sensitivity * wear_mu
	
	var peak_sr := 0.1
	var peak_sa := 0.1
	var normalised_sr = slip.y / peak_sr
	var normalised_sa = slip.x / peak_sa
	var resultant_slip = sqrt(pow(normalised_sr, 2) + pow(normalised_sa, 2))
#
	var sr_modified = resultant_slip * peak_sr
	var sa_modified = resultant_slip * peak_sa
	
	var force_vec := Vector3.ZERO
	force_vec.x = pacejka(slip.x, 10, 1.35, mu, 0, normal_load)
	force_vec.y = pacejka(slip.y, 10, 1.6, mu, 0, normal_load)
	if resultant_slip != 0:
		force_vec.x = force_vec.x * abs(normalised_sa / resultant_slip)
		force_vec.y = force_vec.y * abs(normalised_sr / resultant_slip)
	return force_vec
