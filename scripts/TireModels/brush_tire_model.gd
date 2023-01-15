class_name BrushTireModel
extends BaseTireModel

export (float) var contact_patch = 0.2


func update_tire_forces(slip: Vector2, normal_load: float, surface_mu: float = 1.0) -> Vector3:
	var stiffness = 1000000 + 8000000 * tire_stiffness
	var cornering_stiffness = 0.5 * stiffness * pow(contact_patch, 2)
	
	var wear_mu = TIRE_WEAR_CURVE.interpolate_baked(tire_wear)
	load_sensitivity = update_load_sensitivity(normal_load)
	var mu = surface_mu * load_sensitivity * wear_mu
	var friction = mu * normal_load
	
	var critical_slip = friction / (2 * cornering_stiffness)
	var critical_length = 0
	if slip.x:
		critical_length = friction / (stiffness * contact_patch * tan(abs(slip.x)))
	
	var force_vector := Vector3.ZERO
	
	# Self aligning moment
	if critical_length >= contact_patch: # Adhesion region
		force_vector.z = cornering_stiffness * contact_patch * slip.x / 6
	else: # Sliding region
		if slip.x:
			var idk = (mu * pow(normal_load, 2) / (12 * contact_patch * stiffness * tan(slip.x)))
			force_vector.z = idk * (3 - ((2 * friction) / (pow(contact_patch, 2) * stiffness * tan(slip.x))))
	
	var deflect = sqrt(pow(cornering_stiffness * slip.y, 2) + pow(cornering_stiffness * tan(slip.x), 2))
	if deflect == 0:
		return Vector3.ZERO

	if deflect <= 0.5 * friction * (1 - slip.y):
		force_vector.y = cornering_stiffness * -slip.y / (1 - slip.y)
		force_vector.x = cornering_stiffness * tan(slip.x) / (1 - slip.y)
	else:
		var brushy = (1 - friction * (1 - slip.y) / (4 * deflect)) / deflect
		force_vector.y = -friction * cornering_stiffness * -slip.y * brushy
		force_vector.x = friction * cornering_stiffness * tan(slip.x) * brushy
	return force_vector


#func get_tire_forces(slip: Vector2, normal_load: float, mu: float = 1.0) -> Vector3:
#	var stiffness = 1000000 + 8000000 * (1 - tire_softness)
#	var cornering_stiffness = 0.5 * stiffness * pow(contact_patch, 2)
#	var friction = mu * normal_load
#
#	var lambda = 0.04
#
#	var lat_critical_slip = friction / (2 * cornering_stiffness)
#	var long_critical_slip = friction / (stiffness * contact_patch * (contact_patch + lambda))
#	var lat_critical_length = 0
#	var long_critical_length = 0
#	if slip.x:
#		lat_critical_length = friction / (stiffness * contact_patch * tan(abs(slip.x)))
#
#	var force_vector := Vector3.ZERO
	
	# Self aligning moment
#	if lat_critical_length >= contact_patch:
#		force_vector.x = cornering_stiffness * slip.x
#		force_vector.z = cornering_stiffness * contact_patch * slip.x / 6
#	else:
#		if slip.x:
#			force_vector.x = friction - (pow(friction,2) / (4 * cornering_stiffness * tan(slip.x)))
#			var idk = (mu * pow(normal_load, 2) / (12 * contact_patch * stiffness * tan(slip.x)))
#			force_vector.z = idk * (3 - ((2 * friction) / (pow(contact_patch, 2) * stiffness * tan(slip.x))))
#	print(force_vector.z)
	
	# Longitudinal forces
#	if abs(slip.y) < long_critical_slip:
#		long_critical_length = contact_patch
#		force_vector.y = stiffness * contact_patch * (lambda + 0.5 * contact_patch) * slip.y
#	else:
#		long_critical_length = friction / (contact_patch * stiffness * slip.y) - lambda
#		force_vector.y = stiffness * slip.y * long_critical_length * (lambda + 0.5 * long_critical_length) + friction * (1 - long_critical_length / contact_patch)
#	return force_vector
