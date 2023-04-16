class_name BaseCar
extends RigidBody3D

@export var car_params: CarParameters

######## CONSTANTS ########
const PETROL_KG_L: float = 0.7489
const NM_2_KW: int = 9549
const AV_2_RPM: float = 60 / TAU

#####

var drivetrain: DriveTrain
var clutch = Clutch

######### Controller inputs #########
var throttle_input: float = 0.0
var steering_input: float = 0.0
var brake_input: float = 0.0
var handbrake_input: float = 0.0
var clutch_input: float = 0.0

######### Misc #########
var fuel: float = 0.0
var drag_torque: float = 0.0
var torque_out: float = 0.0
var net_drive: float = 0.0
var engine_net_torque = 0.0

var clutch_reaction_torque = 0.0
var drive_reaction_torque = 0.0

var rpm: float = 0.0
var engine_angular_vel: float = 0.0

var rear_brake_torque: float = 0.0
var front_brake_torque: float = 0.0

var selected_gear: int = 0

var drive_inertia: float = 0.2 #includes every inertia after engine and before wheels

var steering_amount: float = 0.0

var speedo: float = 0.0
var susp_comp: Array = [0.5, 0.5, 0.5, 0.5]

var avg_rear_spin := 0.0
var avg_front_spin := 0.0

var local_vel: Vector3 = Vector3.ZERO
var prev_pos: Vector3 = Vector3.ZERO
var z_vel: float = 0.0
var x_vel: float = 0.0

var last_shift_time = 0

@onready var wheel_fl = $Wheel_fl as RaycastSuspension
@onready var wheel_fr = $Wheel_fr as RaycastSuspension
@onready var wheel_bl = $Wheel_bl as RaycastSuspension
@onready var wheel_br = $Wheel_br as RaycastSuspension
@onready var audioplayer = $EngineSound


func _init() -> void:
	clutch = Clutch.new()
	drivetrain = DriveTrain.new()
	car_params = CarParameters.new()


func _ready() -> void:
	clutch.friction = car_params.clutch_friction

	drivetrain.rear_diff = car_params.rear_diff
	drivetrain.front_diff = car_params.front_diff
	drivetrain.gear_inertia = car_params.gear_inertia
	drivetrain.gear_ratios = car_params.gear_ratios
	drivetrain.reverse_ratio = car_params.reverse_ratio
	drivetrain.final_drive = car_params.final_drive
	drivetrain.front_diff_power_ratio = car_params.front_diff_power_ratio
	drivetrain.rear_diff_power_ratio = car_params.rear_diff_power_ratio
	drivetrain.front_diff_coast_ratio = car_params.front_diff_coast_ratio
	drivetrain.rear_diff_coast_ratio = car_params.rear_diff_coast_ratio
	drivetrain.automatic = car_params.automatic
	drivetrain.drivetype = car_params.drivetype
	drivetrain.set_front_diff_preload(car_params.front_diff_preload)
	drivetrain.set_rear_diff_preload(car_params.rear_diff_preload)
	drivetrain.set_input_inertia(car_params.engine_moment)
	
	wheel_fl.spring_length = car_params.spring_length_fl
	wheel_fl.spring_stiffness = car_params.spring_stiffness_fl
	wheel_fl.bump = car_params.bump_fl
	wheel_fl.rebound = car_params.rebound_fl
	wheel_fl.anti_roll = car_params.anti_roll_front
	wheel_fl.tire_model = car_params.tire_model_fl
	wheel_fl.tire_radius = car_params.tire_radius_fl
	wheel_fl.wheel_mass = car_params.wheel_mass_fl
	wheel_fl.tire_width = car_params.tire_width_fl
	wheel_fl.ackermann = car_params.ackermann_fl
	
	wheel_fr.spring_length = car_params.spring_length_fr
	wheel_fr.spring_stiffness = car_params.spring_stiffness_fr
	wheel_fr.bump = car_params.bump_fr
	wheel_fr.rebound = car_params.rebound_fr
	wheel_fr.anti_roll = car_params.anti_roll_front
	wheel_fr.tire_model = car_params.tire_model_fr
	wheel_fr.tire_radius = car_params.tire_radius_fr
	wheel_fr.wheel_mass = car_params.wheel_mass_fr
	wheel_fr.tire_width = car_params.tire_width_fr
	wheel_fr.ackermann = car_params.ackermann_fr
	
	wheel_bl.spring_length = car_params.spring_length_bl
	wheel_bl.spring_stiffness = car_params.spring_stiffness_bl
	wheel_bl.bump = car_params.bump_bl
	wheel_bl.rebound = car_params.rebound_bl
	wheel_bl.anti_roll = car_params.anti_roll_front
	wheel_bl.tire_model = car_params.tire_model_bl
	wheel_bl.tire_radius = car_params.tire_radius_bl
	wheel_bl.wheel_mass = car_params.wheel_mass_bl
	wheel_bl.tire_width = car_params.tire_width_bl
	wheel_bl.ackermann = car_params.ackermann_bl
	
	wheel_br.spring_length = car_params.spring_length_br
	wheel_br.spring_stiffness = car_params.spring_stiffness_br
	wheel_br.bump = car_params.bump_br
	wheel_br.rebound = car_params.rebound_br
	wheel_br.anti_roll = car_params.anti_roll_rear
	wheel_br.tire_model = car_params.tire_model_br
	wheel_br.tire_radius = car_params.tire_radius_br
	wheel_br.wheel_mass = car_params.wheel_mass_br
	wheel_br.tire_width = car_params.tire_width_br
	wheel_br.ackermann = car_params.ackermann_br
	
	fuel = car_params.fuel_tank_size * car_params.fuel_percentage * 0.01
	self.mass += fuel * PETROL_KG_L


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ShiftUp"):
		shift_up()
	if event.is_action_pressed("ShiftDown"):
		shift_down()


func _process(delta: float) -> void:
	brake_input = Input.get_action_strength("Brake")
	steering_input = Input.get_action_strength("SteerLeft") - Input.get_action_strength("SteerRight")
	throttle_input = Input.get_action_strength("Throttle")
	handbrake_input = Input.get_action_strength("Handbrake")
	clutch_input = Input.get_action_strength("Clutch")
	
	var brakes_torques = get_brake_torques(brake_input, delta)
	front_brake_torque = brakes_torques.x
	rear_brake_torque = brakes_torques.y
	
	if car_params.automatic:
		var reversing = false
		var shift_time = 700
		var next_gear_rpm = 0
		if selected_gear < car_params.gear_ratios.size():
			next_gear_rpm = car_params.gear_ratios[selected_gear] * drivetrain.final_drive * avg_front_spin * AV_2_RPM
		
		var prev_gear_rpm = 0
		if selected_gear - 1 > 0:
			prev_gear_rpm = car_params.gear_ratios[selected_gear - 1] * drivetrain.final_drive * avg_front_spin * AV_2_RPM
		
		if selected_gear == -1:
			reversing = true

		var torque_bigger_next_gear = get_engine_torque(next_gear_rpm) > torque_out - drag_torque
		if torque_bigger_next_gear and selected_gear >= 0:
			if rpm > 0.85 * car_params.max_engine_rpm:
				if Time.get_ticks_msec() - last_shift_time > shift_time:
					shift_up()
		var torque_bigger_prev_gear = get_engine_torque(prev_gear_rpm) > torque_out - drag_torque
		if selected_gear > 1 and rpm < 0.5 * car_params.max_engine_rpm and torque_bigger_prev_gear:
			if Time.get_ticks_msec() - last_shift_time > shift_time:
				shift_down()
		if abs(selected_gear) <= 1 and abs(z_vel) < 3.0 and brake_input > 0.2:
			if not reversing:
				if Time.get_ticks_msec() - last_shift_time > shift_time:
					shift_down()
			else:
				if Time.get_ticks_msec() - last_shift_time > shift_time:
					shift_up()


func _physics_process(delta):
	local_vel = (global_transform.origin - prev_pos) / delta * global_transform.basis
	prev_pos = global_transform.origin
	z_vel = -local_vel.z
	x_vel = local_vel.x
	drag_force()
	
	##### AntiRollBar #####
	var prev_comp = susp_comp
	susp_comp[2] = wheel_bl.apply_forces(prev_comp[3], delta)
	susp_comp[3] = wheel_br.apply_forces(prev_comp[2], delta)
	susp_comp[0] = wheel_fr.apply_forces(prev_comp[1], delta)
	susp_comp[1] = wheel_fl.apply_forces(prev_comp[0], delta)
	
	##### Steerin with steer speed #####
	if (steering_input < steering_amount):
		steering_amount -= car_params.steer_speed * delta
		if (steering_input > steering_amount):
			steering_amount = steering_input
	
	elif (steering_input > steering_amount):
		steering_amount += car_params.steer_speed * delta
		if (steering_input < steering_amount):
			steering_amount = steering_input
	
	wheel_fl.steer(steering_amount, car_params.max_steer)
	wheel_fr.steer(steering_amount, car_params.max_steer)
	
	##### Engine loop #####
	drag_torque = car_params.engine_brake + rpm * car_params.engine_drag
	torque_out = (get_engine_torque(rpm) + drag_torque ) * throttle_input
	engine_net_torque = torque_out + clutch_reaction_torque - drag_torque
	
	rpm += AV_2_RPM * delta * engine_net_torque / car_params.engine_moment
	engine_angular_vel = rpm / AV_2_RPM
	
	if rpm >= car_params.max_engine_rpm:
		torque_out = 0
		rpm -= 500 
	
	if rpm <= (car_params.rpm_idle + 10) and z_vel <= 2:
		clutch_input = 1.0
	
	if selected_gear == 0:
		freewheel(delta)
	else:
		engage(delta)
		
	rpm = max(rpm , car_params.rpm_idle)
	
	if fuel <= 0.0:
		torque_out = 0.0
		rpm = 0.0
		stop_engine_sound()
	
	play_engine_sound()
	burn_fuel(delta)
	
	
func get_engine_torque(p_rpm) -> float: 
	var rpm_factor = clamp(p_rpm / car_params.max_engine_rpm, 0.0, 1.0)
	var torque_factor = car_params.torque_curve.sample_baked(rpm_factor)
	return torque_factor * car_params.max_torque


func get_brake_torques(p_brake_input: float, delta):
	var clamping_force := p_brake_input * car_params.max_brake_force * 0.5 
	var brake_pad_mu := 0.4
	var effective_radius := 0.25
	var braking_force := 2.0 * brake_pad_mu * clamping_force
	
	var torques := Vector2.ZERO
	
	torques.x = braking_force * car_params.brake_effective_radius * car_params.front_brake_bias
	torques.y = braking_force * car_params.brake_effective_radius * (1 - car_params.front_brake_bias)
	return torques


func freewheel(delta):
	clutch_reaction_torque = 0.0
	avg_front_spin = 0.0
#	var brakes_torques = get_brake_torques(brake_input, delta)
	wheel_fl.apply_torque(0.0, front_brake_torque, 0.0, delta)
	wheel_fr.apply_torque(0.0, front_brake_torque, 0.0, delta)
	wheel_bl.apply_torque(0.0, rear_brake_torque, 0.0, delta)
	wheel_br.apply_torque(0.0, rear_brake_torque, 0.0, delta)
	avg_front_spin += (wheel_fl.spin + wheel_fr.spin) * 0.5
	speedo = avg_front_spin * wheel_fl.tire_radius * 3.6
	
	
func engage(delta):
	avg_rear_spin = 0.0
	avg_front_spin = 0.0

	avg_rear_spin += (wheel_bl.spin + wheel_br.spin) * 0.5
	avg_front_spin += (wheel_fl.spin + wheel_fr.spin) * 0.5
	
	var gearbox_shaft_speed: float = 0.0
	
	if car_params.drivetype == car_params.DRIVE_TYPE.RWD:
		gearbox_shaft_speed = avg_rear_spin * drivetrain.get_gearing() 
	elif car_params.drivetype == car_params.DRIVE_TYPE.FWD:
		gearbox_shaft_speed = avg_front_spin * drivetrain.get_gearing() 
	elif car_params.drivetype == car_params.DRIVE_TYPE.AWD:
		gearbox_shaft_speed = (avg_front_spin + avg_rear_spin) * 0.5 * drivetrain.get_gearing()
		
	var speed_error = engine_angular_vel - gearbox_shaft_speed
	var clutch_kick = abs(speed_error) * 0.2

	var reaction_torques = clutch.get_reaction_torques(engine_angular_vel, gearbox_shaft_speed, clutch_input, clutch_kick)
	drive_reaction_torque = reaction_torques.x
	clutch_reaction_torque = reaction_torques.y
	
	net_drive = drive_reaction_torque * (1 - clutch_input)
	
	drivetrain.drivetrain(net_drive, rear_brake_torque, front_brake_torque, [wheel_bl, wheel_br, wheel_fl, wheel_fr], delta)

	speedo = avg_front_spin * wheel_fl.tire_radius * 3.6

func drag_force():
	var spd = sqrt(x_vel * x_vel + z_vel * z_vel)
	var cdrag = 0.5 * car_params.cd * car_params.frontal_area * car_params.air_density
	
	# fdrag.y is positive in this case because forward is -z in godot 
	var fdrag: Vector2 = Vector2.ZERO
	fdrag.y = clamp(cdrag * z_vel * spd, -100000, 100000)
	fdrag.x = clamp(-cdrag * x_vel * spd, -100000, 100000)
	
	apply_central_force(global_transform.basis.z.normalized() * fdrag.y)
	apply_central_force(global_transform.basis.x.normalized() * fdrag.x)


func burn_fuel(delta):
	var fuel_burned = car_params.engine_bsfc * torque_out * rpm * delta / (3600 * PETROL_KG_L * NM_2_KW)
	fuel -= fuel_burned
	self.mass -= fuel_burned * PETROL_KG_L


func shift_up():
	if selected_gear < car_params.gear_ratios.size():
		selected_gear += 1
		last_shift_time = Time.get_ticks_msec()
		drivetrain.set_selected_gear(selected_gear)


func shift_down():
	if selected_gear > -1:
		selected_gear -= 1
		last_shift_time = Time.get_ticks_msec()
		drivetrain.set_selected_gear(selected_gear)


func play_engine_sound():
	var pitch_scaler = rpm / 1000
	if rpm >= car_params.rpm_idle and rpm < car_params.max_engine_rpm:
		if audioplayer.stream != car_params.engine_sound:
			audioplayer.set_stream(car_params.engine_sound)
		if !audioplayer.playing:
			audioplayer.play()
	
	if pitch_scaler > 0.1:
		audioplayer.pitch_scale = pitch_scaler


func stop_engine_sound():
	audioplayer.stop()

