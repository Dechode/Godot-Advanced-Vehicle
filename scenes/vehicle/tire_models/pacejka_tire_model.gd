class_name PacejkaTireModel
extends BaseTireModel

@export var pacejka_b := 10.0
@export var pacejka_c_lat := 1.35
@export var pacejka_c_long := 1.65
@export var pacejka_d := 1.0
@export var pacejka_e := 0.0

func pacejka(slip, B, C, D, E, normal_load):
	return normal_load * D * sin(C * atan(B * slip - E * (B * slip - atan(B * slip))))


func update_tire_forces(slip: Vector2, normal_load: float, surface_mu: float):
	var wear_mu := TIRE_WEAR_CURVE.sample_baked(tire_wear)
	load_sensitivity = update_load_sensitivity(normal_load)
	var mu := surface_mu * load_sensitivity * wear_mu
	
	var peak_sa := pacejka_b / 20 * 0.5
	var peak_sr := peak_sa * 0.7
	
	var normalised_sr = slip.y / peak_sr
	var normalised_sa = slip.x / peak_sa
	var resultant_slip = sqrt(pow(normalised_sr, 2) + pow(normalised_sa, 2))
#
	var sr_modified = resultant_slip * peak_sr
	var sa_modified = resultant_slip * peak_sa
	
	var force_vec := Vector3.ZERO
	
	force_vec.x = pacejka(abs(sa_modified), pacejka_b, pacejka_c_lat, pacejka_d, pacejka_e, normal_load) * sign(slip.x)
	force_vec.y = pacejka(abs(sr_modified), pacejka_b, pacejka_c_long, pacejka_d, pacejka_e, normal_load) * sign(slip.y)
	force_vec.z = pacejka(slip.x, pacejka_b, 2.0, 0.1 * pacejka_e, -20, normal_load) # 
	
	force_vec *= mu
	
	if resultant_slip != 0:
		force_vec.x = force_vec.x * abs(normalised_sa / resultant_slip)
		force_vec.y = force_vec.y * abs(normalised_sr / resultant_slip)
	return force_vec
