class_name BrushTireModel
extends BaseTireModel

export (float) var brush_contact_patch = 0.2


func get_tire_forces(slip: Vector2, normal_load: float):
	var stiffness = 500000.0 * tire_softness * 20.0 * pow(brush_contact_patch, 2)
	var friction = mu * normal_load
	var deflect = sqrt(pow(stiffness * slip.y, 2) + pow(stiffness * tan(slip.x), 2))

	if deflect == 0:
		return Vector2.ZERO
	else:
		var vector = Vector2.ZERO
		if deflect <= 0.5 * friction * (1 - slip.y):
			vector.y = stiffness * -slip.y / (1 - slip.y)
			vector.x = stiffness * tan(slip.x) / (1 - slip.y)
		else:
			var brushy = (1 - friction * (1 - slip.y) / (4 * deflect)) / deflect
			vector.y = -friction * stiffness * -slip.y * brushy
			vector.x = friction * stiffness * tan(slip.x) * brushy
		return vector
		
