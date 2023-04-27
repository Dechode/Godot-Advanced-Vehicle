class_name RaycastSuspension
extends RayCast3D

############# Choose what tire formula to use #############
var tire_model: BaseTireModel 

############# Suspension stuff #############
var spring_length = 0.2
var spring_stiffness = 45.0
var bump = 3.5
var rebound = 4.0
var anti_roll = 0.0

var spring_load_mm:float = 0
var prev_spring_load_mm:float = 0
var spring_speed_mm_per_seconds:float = 0
var spring_load_newton:float = 0

############# Tire stuff #############
var wheel_mass = 15.0
var tire_radius = 0.3
var tire_width = 0.2
var ackermann = 0.15

var tire_wear: float = 0.0

var surface_mu = 1.0
var y_force: float = 0.0

var wheel_inertia: float = 0.0
var spin: float = 0.0
var z_vel: float = 0.0
var local_vel


var rolling_resistance: float = 0.0 #Vector2 = Vector2.ZERO
var rol_res_surface_mul: float = 0.02

var force_vec = Vector3.ZERO
var slip_vec: Vector2 = Vector2.ZERO
var prev_pos: Vector3 = Vector3.ZERO

var spring_curr_length: float = spring_length


@onready var car = $'..' #Get the parent node as car
@onready var wheelmesh = $MeshInstance3D


func _ready() -> void:
#	var nominal_load = car.weight * 0.25
	wheel_inertia = 0.5 * wheel_mass * pow(tire_radius, 2)
	set_target_position(Vector3.DOWN * (spring_length + tire_radius))

func set_params(params: WheelSuspensionParameters):
	tire_model =  params.tire_model
	spring_length = params.spring_length
	spring_stiffness = params.spring_stiffness
	bump = params.bump
	rebound = params.rebound
	wheel_mass = params.wheel_mass
	tire_radius = params.tire_radius
	tire_width = params.tire_width
	ackermann = params.ackermann
	anti_roll = params.anti_roll
	
	wheel_inertia = 0.5 * wheel_mass * pow(tire_radius, 2)
	set_target_position(Vector3.DOWN * (spring_length + tire_radius))


# Move back to physics process when physics interpolation comes to godot4
func _process(delta: float) -> void:
	wheelmesh.rotate_x(wrapf(-spin * delta,0, TAU))
	wheelmesh.position.y = -spring_curr_length


func _physics_process(delta: float) -> void:
	if abs(z_vel) > 2.0:
		tire_wear = tire_model.update_tire_wear(delta, slip_vec, y_force, surface_mu)


func apply_forces(opposite_comp, delta):
	############# Local forward velocity #############
	force_vec = Vector3.ZERO
	
	local_vel = (global_transform.origin - prev_pos) / delta * global_transform.basis
	z_vel = -local_vel.z
	var planar_vect = Vector2(local_vel.x, local_vel.z).normalized()
	prev_pos = global_transform.origin
	
	var surface
	############# Suspension #################
	if is_colliding():
		if get_collider().get_groups().size() > 0:
			surface = get_collider().get_groups()[0]
		if surface:
			surface_mu = 1.0
			if surface == "Tarmac":
				surface_mu = 1.0 
				rol_res_surface_mul = 0.01
			elif surface == "Gravel":
				surface_mu = 0.6
				rol_res_surface_mul = 0.03
			elif surface == "Grass":
				surface_mu = 0.55  
				rol_res_surface_mul = 0.025
			elif surface == "Snow":
				surface_mu = 0.4
				rol_res_surface_mul = 0.035
		
		spring_curr_length = get_collision_point().distance_to(global_transform.origin) - tire_radius
	else:
		spring_curr_length = spring_length
	
	#
	#Calculate the spring load in mm (absolut)
	spring_load_mm = (spring_length - spring_curr_length) * 1000
	#
	#Calculate spring movement in mm per seconds
	spring_speed_mm_per_seconds = (spring_load_mm - prev_spring_load_mm) / delta
	prev_spring_load_mm = spring_load_mm
	#
	#Calculate the force of the spring in N (mm * N/mm  equals m * kN/m)
	spring_load_newton = spring_load_mm * spring_stiffness
	#
	#Calculate the damping force in N and add it to spring_load_newton
	if spring_speed_mm_per_seconds >= 0:
		spring_load_newton += spring_speed_mm_per_seconds * bump # bump
	else :
		spring_load_newton += spring_speed_mm_per_seconds * rebound # rebound
	
	y_force = spring_load_newton

	y_force = max(0, y_force)
	
	############### Slip #######################
	slip_vec.x = asin(clamp(-planar_vect.x, -1, 1)) # X slip is lateral slip
	slip_vec.y = 0.0 # Y slip is the longitudinal Z slip
	
	if is_colliding():
#		if z_vel != 0:
		if not is_zero_approx(z_vel):
			slip_vec.y = (z_vel - spin * tire_radius) / abs(z_vel)
		else:
			if is_zero_approx(spin):
				slip_vec.y = 0.0
			else:
				slip_vec.y = 0.0001 * spin # This is to avoid "getting stuck" if local z velocity is absolute 0
	
		force_vec = tire_model.update_tire_forces(slip_vec, y_force, surface_mu)
		
		var contact = get_collision_point() - car.global_transform.origin
		var normal = get_collision_normal()
		
#		prints("Z force =", force_vec.y)
		car.apply_force(normal * y_force, contact)
		car.apply_force(global_transform.basis.x * force_vec.x, contact)
		car.apply_force(global_transform.basis.z * force_vec.y, contact)
		
		### Return suspension compress info for the car bodys antirollbar calculations
		#
		#Now calculate the anti roll bar based on mm-difference between left and right
		if spring_load_mm !=0:
			y_force += anti_roll * (spring_load_mm - opposite_comp)
		return spring_load_mm
	else:
		spin -= sign(spin) * delta * 2 / wheel_inertia # stop undriven wheels from spinning endlessly
		return 0.0


func apply_torque(drive_torque, brake_torque, drive_inertia, delta):
	var prev_spin = spin
	var net_torque = force_vec.y * tire_radius
	net_torque += drive_torque
	if abs(spin) < 5 and brake_torque > abs(net_torque):
		spin = 0
	else:
		net_torque -= (brake_torque + rolling_resistance) * sign(spin)
		spin += delta * net_torque / (wheel_inertia + drive_inertia)

	if drive_torque * delta == 0:
		return 0.5
	else:
		return (spin - prev_spin) * (wheel_inertia + drive_inertia) / (drive_torque * delta)


func set_spin(value):
	spin = value 


func get_spin():
	return spin


func get_reaction_torque():
	return force_vec.y * tire_radius


func steer(input, max_steer):
	rotation.y = max_steer * (input + (1 - cos(input * 0.5 * PI)) * ackermann)

