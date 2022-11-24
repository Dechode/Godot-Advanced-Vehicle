extends RayCast
class_name RaycastSuspension

############# Choose what tire formula to use #############
enum TIRE_FORMULAS {
	SIMPLE_PACEJKA,
	BRUSH_TIRE_FORMULA,
	CURVE_BASED_FORMULA,
}
export (TIRE_FORMULAS) var tire_formula_to_use = TIRE_FORMULAS.CURVE_BASED_FORMULA

############# Suspension stuff #############
export (float) var spring_length = 0.2
export (float) var springstiffness = 20000
export (float) var bump = 5000
export (float) var rebound = 3000
export (float) var anti_roll = 0.0

############# Tire stuff #############

export (float) var wheel_mass = 15
export (float) var tire_radius = 0.3
export (float) var tire_width = 0.2
export (float) var ackermann = 0.15
export (float) var tire_mu = 0.9
export (Curve) var tire_wear_mu_curve = null
export (Curve) var tire_rr_vel_curve = null

############# For curve tire formula #############
export (Curve) var lateral_force = null
export (Curve) var longitudinal_force = null

############# For brush tire_formula #############
export (float) var brush_contact_patch = 0.2
export (float) var tire_stiffness = 10 # Also used in tire wear

############# For Pacejka tire formula #############
export (float) var pacejka_C_long = 1.65
export (float) var pacejka_C_lat = 1.35
export (float) var pacejka_E = 0.0


var peak_sr: float = 0.10
var peak_sa: float = 0.10

var tire_wear: float

var mu = 1.0
var y_force: float = 0.0
#var braketorque: float = 0.0

var wheel_moment: float = 0.0
var spin: float = 0.0
var z_vel: float = 0.0
var local_vel

var rolling_resistance: float = 0.0 #Vector2 = Vector2.ZERO
var rol_res_surface_mul: float = 0.02

var force_vec = Vector2.ZERO
var slip_vec: Vector2 = Vector2.ZERO
var prev_pos: Vector3 = Vector3.ZERO

var prev_compress: float = 0.0
var spring_curr_length: float = spring_length


onready var car = $'..' #Get the parent node as car
onready var wheelmesh = $MeshInstance


func _ready() -> void:
	var nominal_load = car.weight * 0.25
	wheel_moment = 0.5 * wheel_mass * pow(tire_radius, 2)
	set_cast_to(Vector3.DOWN * (spring_length + tire_radius))
	
	peak_sa = lateral_force.get_point_position(1).x
	peak_sr = longitudinal_force.get_point_position(1).x

	if tire_formula_to_use == TIRE_FORMULAS.SIMPLE_PACEJKA:
		peak_sa = get_peak_pacejka(nominal_load, tire_stiffness, pacejka_C_lat, mu, pacejka_E)
		peak_sr = get_peak_pacejka(nominal_load, tire_stiffness, pacejka_C_long, mu, pacejka_E)
	print("Peak slip angle = " + str(peak_sa))
	print("Peak slip ratio = " + str(peak_sr))


func get_peak_pacejka(yload, tire_stif, C, friction_coeff, E):
	var done = false

	var unsorted_points: Array = []
	var sorted_points: Array = []

	for i in range(100):
		unsorted_points.append(pacejka(i * 0.01, tire_stif, C, friction_coeff, E ,yload ))
		sorted_points.append(unsorted_points[i])
		if i == 99:
			done = true
#		continue
	if done:
		sorted_points.sort()
#		print(sorted_points)

		for slip in range(100):
			if unsorted_points[slip] == sorted_points[99]:
#				print(rad2deg(r * 0.01))
				return slip * 0.01
	return 0.0



func _process(delta: float) -> void:
	wheelmesh.rotate_x(wrapf(-spin * delta,0, TAU))
	if z_vel > 2.0:
		tireWear(delta, y_force)


# Tire wear calculations are totally made up
func tireWear(delta, yload):
	var larger_slip = max(abs(slip_vec.x), abs(slip_vec.y))
	tire_wear += larger_slip * mu * delta * 0.01 * yload * 0.0001 / tire_stiffness
	tire_wear = clamp(tire_wear, 0 ,1)


func rollingResistance(yload, speed):
	var spd_factor = clamp(abs(speed) / 44.0, 0.0, 1.0)
	var crr = rol_res_surface_mul * tire_rr_vel_curve.interpolate_baked(spd_factor)# * sign(speed)
	return crr * yload


func apply_forces(opposite_comp, delta):
	############# Local forward velocity #############
	
	local_vel = global_transform.basis.xform_inv((global_transform.origin - prev_pos) / delta)
	z_vel = -local_vel.z
	var planar_vect = Vector2(local_vel.x, local_vel.z).normalized()
	prev_pos = global_transform.origin
	
	############# Suspension #################
	
	if is_colliding():
		spring_curr_length = get_collision_point().distance_to(global_transform.origin) - tire_radius
	else:
		spring_curr_length = spring_length
		
	var compress = 1 - spring_curr_length / spring_length
	y_force = springstiffness * compress * spring_length

	if (compress - prev_compress) >= 0:
		y_force += (bump + wheel_mass) * (compress - prev_compress) * spring_length / delta
	else:
		y_force += rebound * (compress - prev_compress) * spring_length  / delta
	
	y_force = max(0, y_force)
	prev_compress = compress
	
	rolling_resistance = rollingResistance(y_force, z_vel)
#	prints("Rolling resistance =", rolling_resistance)
	############### Slip #######################
	
	slip_vec.x = asin(clamp(-planar_vect.x, -1, 1)) # X slip is lateral slip
	slip_vec.y = 0.0 # Y slip is the longitudinal Z slip
	
#	if is_colliding() and z_vel != 0:
	if z_vel != 0:
		slip_vec.y = (z_vel - spin * tire_radius) / abs(z_vel)
	else:
		if spin == 0:
			slip_vec.y = 0.0
#			print("Spin and z vel == 0")
		else:
#			print("Z vel == 0 but some spin")
			slip_vec.y = 0.01 * spin # This is to avoid "getting stuck" if local z velocity is absolute 0
#	print("Spin = " , spin)
	
	############### Apply the forces #######################
	
	var slip_ratio = slip_vec.y 
	var slip_angle = slip_vec.x
	
	var normalised_sr = slip_ratio / peak_sr
	var normalised_sa = slip_angle / peak_sa
	var resultant_slip = sqrt(pow(normalised_sr, 2) + pow(normalised_sa, 2))

	var sr_modified = resultant_slip * peak_sr
	var sa_modified = resultant_slip * peak_sa
	
	var x_force: float = 0.0
	var z_force: float = 0.0
	
	if tire_formula_to_use == TIRE_FORMULAS.CURVE_BASED_FORMULA:
		x_force = TireForceVol2(abs(sa_modified), y_force, lateral_force) * sign(slip_vec.x)
		z_force = TireForceVol2(abs(sr_modified), y_force, longitudinal_force) * sign(slip_vec.y)
		
	elif tire_formula_to_use == TIRE_FORMULAS.SIMPLE_PACEJKA:
		x_force = pacejka(abs(sa_modified), tire_stiffness, pacejka_C_lat, mu, pacejka_E ,y_force) * sign(slip_vec.x)
		z_force = pacejka(abs(sr_modified), tire_stiffness, pacejka_C_long, mu, pacejka_E ,y_force) * sign(slip_vec.y)
		
	if resultant_slip != 0:
		force_vec.x = x_force * abs(normalised_sa / resultant_slip)
		force_vec.y = z_force * abs(normalised_sr / resultant_slip)
	else:
		x_force = 0
		z_force = 0
		
		force_vec.x = x_force
		force_vec.y = z_force
	
	# We dont use the modified slip here because the brush tire formula handles slip combination
	if tire_formula_to_use == TIRE_FORMULAS.BRUSH_TIRE_FORMULA:
		force_vec = brush_formula(slip_vec, y_force)
	
	if is_colliding():
		var contact = get_collision_point() - car.global_transform.origin
		var normal = get_collision_normal()
		var surface
		
		var wear_mu = tire_wear_mu_curve.interpolate_baked(tire_wear)
		
		if get_collider().get_groups().size() > 0:
			surface = get_collider().get_groups()[0]
		if surface:
			if surface == "Tarmac":
				mu = 1.0 * tire_mu * wear_mu
				rol_res_surface_mul = 0.01
			elif surface == "Grass":
				mu = 0.55 * tire_mu * wear_mu
				rol_res_surface_mul = 0.025
			elif surface == "Gravel":
				mu = 0.6 * tire_mu * wear_mu
				rol_res_surface_mul = 0.03
			elif surface == "Snow":
				mu = 0.4 * tire_mu * wear_mu
				rol_res_surface_mul = 0.035
		else:
			mu = 1 * tire_mu * wear_mu
#		prints("Z force =", force_vec.y)
		car.add_force(normal * y_force, contact)
		car.add_force(global_transform.basis.x * force_vec.x, contact)
		car.add_force(global_transform.basis.z * force_vec.y, contact)
		
		### Return suspension compress info for the car bodys antirollbar calculations
		if compress !=0:
			compress = 1 - (spring_curr_length / spring_length)
			y_force += anti_roll * (compress - opposite_comp)
		return compress
	else:
		spin -= sign(spin) * delta * 2 / wheel_moment # stop undriven wheels from spinning endlessly
		return 0.0


func apply_torque(drive, drive_inertia, brake_torque, delta):
	var prev_spin = spin
	var net_torque = force_vec.y * tire_radius
	net_torque += drive
	if spin < 5 and brake_torque > abs(net_torque):
#	if brake_torque > abs(net_torque):
		spin = 0
	else:
		net_torque -= (brake_torque + rolling_resistance) * sign(spin)
		spin += delta * net_torque / (wheel_moment + drive_inertia)

	if drive * delta == 0:
		return 0.5
	else:
		return (spin - prev_spin) * (wheel_moment + drive_inertia) / (drive * delta)


func applySolidAxleSpin(axlespin):
	spin = axlespin


func TireForceVol2(slip: float, normal_load: float, tire_curve: Curve) -> float:
	var friction = normal_load * mu
	return tire_curve.interpolate_baked(abs(slip)) * friction * sign(slip)


func pacejka(slip, B, C, D, E, yforce):
	return yforce * D * sin(C * atan(B * slip - E * (B * slip - atan(B * slip))))
	

func brush_formula(slip, yforce):
	var stiffness = 500000 * tire_stiffness * pow(brush_contact_patch, 2)
	var friction = mu * yforce
	var deflect = sqrt(pow(stiffness * slip.y, 2) + pow(stiffness * tan(slip.x), 2))

	if deflect == 0:
		return Vector2.ZERO
	else:
		var vector = Vector2.ZERO
		if deflect <= 0.5 * friction * (1 - slip.y):
			vector.y = stiffness * -slip.y / (1 - slip.y)
			vector.x = stiffness * tan(slip.x) / (1 - slip.y)
		else:
			var brushy = (1 - friction * (1 - slip_vec.y) / (4 * deflect)) / deflect
			vector.y = -friction * stiffness * -slip.y * brushy
			vector.x = friction * stiffness * tan(slip.x) * brushy
		return vector


func steer(input, max_steer):
	rotation.y = max_steer * (input + (1 - cos(input * 0.5 * PI)) * ackermann)
