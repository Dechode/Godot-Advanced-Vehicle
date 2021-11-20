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
export (float) var bump = 1500
export (float) var rebound = 3000
export (float) var anti_roll = 0.0

############# Tire stuff #############

export (float) var wheel_mass = 15
export (float) var tire_radius = 0.3
export (float) var tire_width = 0.2
export (float) var ackermann = 0.15


export (Curve) var lateral_force = null
export (Curve) var longitudinal_force = null
export (float) var tire_mu = 0.9



var mu = 1.0
var y_force: float = 0.0
var braketorque: float = 0.0

var wheel_moment: float = 0.0
var spin: float = 0.0
var z_vel = 0.0

var force_vec = Vector2.ZERO
var slip_vec: Vector2 = Vector2.ZERO
var prev_pos: Vector3 = Vector3.ZERO

var prev_compress: float = 0.0
var spring_curr_length: float = spring_length


onready var car = $'..' #Get the parent node as car
onready var wheelbodycollider = $WheelBody/CollisionShape
onready var wheelbody = $WheelBody
onready var wheelmesh = $WheelBody/MeshInstance


func _ready() -> void:
	wheel_moment = 0.5 * wheel_mass * pow(tire_radius, 2)
	set_cast_to(Vector3.DOWN * (spring_length + tire_radius))
	wheelbodycollider.shape.radius = tire_radius - 0.02
	wheelbodycollider.shape.height = tire_width
		

func _process(delta: float) -> void:
	wheelmesh.rotate_x(wrapf(-spin * delta,0, TAU))

func _physics_process(delta: float) -> void:
	wheelbody.transform.origin = Vector3.DOWN * spring_curr_length

func apply_forces(opposite_comp, delta):
	############# Local forward velocity #############
	
	var local_vel = global_transform.basis.xform_inv((global_transform.origin - prev_pos) / delta)
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
	
	############### Slip #######################
	
	slip_vec.x = asin(clamp(-planar_vect.x, -1, 1)) # X slip is lateral slip
	slip_vec.y = 0.0 # Y slip is the longitudinal Z slip
	
	if is_colliding() and z_vel != 0:
		slip_vec.y = (z_vel - spin * tire_radius) / abs(z_vel)
		
	############### Spin and net torque ###############
	
	var net_torque = force_vec.y * tire_radius
	if spin < 5 and braketorque > abs(net_torque):
		spin = 0
	else:
		net_torque -= braketorque  * sign(spin)
		spin += delta * net_torque / wheel_moment

	############### Apply the forces #######################
	
	if tire_formula_to_use == TIRE_FORMULAS.BRUSH_TIRE_FORMULA:
		force_vec = brush_formula(slip_vec, y_force)
		
	elif tire_formula_to_use == TIRE_FORMULAS.CURVE_BASED_FORMULA:
		force_vec = tireForce(slip_vec, y_force)
		
	elif tire_formula_to_use == TIRE_FORMULAS.SIMPLE_PACEJKA:
		force_vec.x = pacejka(slip_vec.x, 10, 1.35, mu, 0 ,y_force)
		force_vec.y = pacejka(slip_vec.y, 10, 1.65, mu, 0 ,y_force)
	
	
	if is_colliding():
		var contact = get_collision_point() - car.global_transform.origin
		var normal = get_collision_normal()
		var surface

		if get_collider().get_groups().size() > 0:
			surface = get_collider().get_groups()[0]
		if surface:
			if surface == "Tarmac":
				mu = 0.8 * tire_mu
			elif surface == "Grass":
				mu = 0.55 * tire_mu
			elif surface == "Gravel":
				mu = 0.6 * tire_mu
			elif surface == "Snow":
				mu = 0.4 * tire_mu
		else:
			mu = 1
#		print(mu)
		car.add_force(normal * y_force, contact)
		car.add_force(global_transform.basis.x * force_vec.x, contact)
		car.add_force(global_transform.basis.z * force_vec.y, contact)
		
		### Return suspension compress info for the car bodys antirollbar calculations
		if compress !=0:
			compress = 1 - (spring_curr_length / spring_length)
			y_force += anti_roll * (compress - opposite_comp)
		return compress
	else:
		return 0.0


func apply_torque(drive, drive_inertia, brake_torque, delta):
	braketorque = brake_torque
	var prev_spin = spin

	var net_torque = force_vec.y * tire_radius
	net_torque += drive
	
	if spin < 5 and brake_torque > abs(net_torque):
		spin = 0
	else:
		net_torque -= brake_torque * sign(spin)
		spin += delta * net_torque / (wheel_moment + drive_inertia)

	if drive * delta == 0:
		return 0.5
	else:
		return (spin - prev_spin) * (wheel_moment + drive_inertia) / (drive * delta)


func tireForce(slip, normal_load):
	var friction = normal_load * mu
	var vec = Vector2.ZERO
	var slip_ratio = slip.y
	var slip_angle = slip.x
	vec.x = lateral_force.interpolate_baked(abs(slip_angle)) * friction * sign(slip_angle)
	vec.y = longitudinal_force.interpolate_baked(abs(slip_ratio)) * friction * sign(slip_ratio)
	return vec


func pacejka(slip, B, C, D, E, yforce):
	return yforce * D * sin(C * atan(B * slip - E * (B * slip - atan(B * slip))))
	

func brush_formula(slip, yforce):
	### Make these two export variables if you want to change them on a car basis
	var tire_stiffness = 10
	var contact_patch = 0.2
	###########################
	
	var stiffness = 500000 * tire_stiffness * contact_patch
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
