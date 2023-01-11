class_name BrushTireModel
extends BaseTireModel

export (float) var brush_contact_patch = 0.2


func get_tire_forces(slip: Vector2, normal_load: float):
	var spring_rate = 8000000.0 + 25000000.0 * (1 - tire_softness)
#	print("Tire Spring Rate = %d" % spring_rate)
	var stiffness = 0.5 * spring_rate * pow(brush_contact_patch, 2)
	print("Tire stiffness = %d" % stiffness) 
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
		
