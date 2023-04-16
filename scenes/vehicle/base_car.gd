class_name BaseCar
extends RigidBody3D


enum DIFF_TYPE{
	LIMITED_SLIP,
	OPEN_DIFF,
	LOCKED,
}

enum DRIVE_TYPE{
	FWD,
	RWD,
	AWD,
}

@export var max_steer := 0.3
@export var front_brake_bias := 0.6
@export var steer_speed := 5.0
@export var max_brake_force := 500.0
@export var fuel_tank_size := 40.0 #Liters
@export var fuel_percentage := 100.0 # % of full tank

######### Engine variables #########
@export var max_torque = 250.0
@export var max_engine_rpm = 8000.0
@export var rpm_clutch_out = 1500.0
@export var rpm_idle = 900.0
@export var torque_curve: Curve = null
@export var engine_drag = 0.03
@export var engine_brake = 10.0
@export var engine_moment = 0.25
@export var engine_bsfc = 0.3
@export var engine_sound: AudioStream
@export var clutch_friction = 500.0

######### Drivetrain variables #########
@export var drivetype = DRIVE_TYPE.RWD
@export var gear_ratios = [ 3.1, 2.61, 2.1, 1.72, 1.2, 1.0 ] 
@export var automatic := true
@export var final_drive = 3.7
@export var reverse_ratio = 3.9
@export var gear_inertia = 0.12
@export var rear_diff = DIFF_TYPE.LIMITED_SLIP
@export var front_diff = DIFF_TYPE.LIMITED_SLIP
@export var rear_diff_preload = 50.0
@export var front_diff_preload = 50.0
@export var rear_diff_power_ratio: float = 3.5
@export var front_diff_power_ratio: float = 3.5
@export var rear_diff_coast_ratio: float = 1.0
@export var front_diff_coast_ratio: float = 1.0
@export var center_split_fr = 0.4 # AWD torque split front / rear

######### Aero #########
@export var cd = 0.3
@export var air_density = 1.225
@export var frontal_area = 2.0

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

var avg_rear_spin = 0.0
var avg_front_spin = 0.0

var local_vel: Vector3 = Vector3.ZERO
var prev_pos: Vector3 = Vector3.ZERO
var z_vel: float = 0.0
var x_vel: float = 0.0

var last_shift_time = 0

@onready var wheel_fl = $Wheel_fl
@onready var wheel_fr = $Wheel_fr
@onready var wheel_bl = $Wheel_bl
@onready var wheel_br = $Wheel_br
@onready var audioplayer = $EngineSound


func _init() -> void:
	clutch = Clutch.new()
	drivetrain = DriveTrain.new()


func _ready() -> void:
	clutch.friction = clutch_friction

	drivetrain.rear_diff = rear_diff
	drivetrain.front_diff = front_diff
	drivetrain.gear_inertia = gear_inertia
	drivetrain.gear_ratios = gear_ratios
	drivetrain.reverse_ratio = reverse_ratio
	drivetrain.final_drive = final_drive
	drivetrain.front_diff_power_ratio = front_diff_power_ratio
	drivetrain.rear_diff_power_ratio = rear_diff_power_ratio
	drivetrain.front_diff_coast_ratio = front_diff_coast_ratio
	drivetrain.rear_diff_coast_ratio = rear_diff_coast_ratio
	drivetrain.automatic = automatic
	drivetrain.drivetype = drivetype
	drivetrain.set_front_diff_preload(front_diff_preload)
	drivetrain.set_rear_diff_preload(rear_diff_preload)
	drivetrain.set_input_inertia(engine_moment)

	fuel = fuel_tank_size * fuel_percentage * 0.01
	self.mass += fuel * PETROL_KG_L


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ShiftUp"):
		shiftUp()
	if event.is_action_pressed("ShiftDown"):
		shiftDown()


func _process(delta: float) -> void:
	brake_input = Input.get_action_strength("Brake")
	steering_input = Input.get_action_strength("SteerLeft") - Input.get_action_strength("SteerRight")
	throttle_input = Input.get_action_strength("Throttle")
	handbrake_input = Input.get_action_strength("Handbrake")
	clutch_input = Input.get_action_strength("Clutch")
	
	var brakes_torques = get_brake_torques(brake_input, delta)
	front_brake_torque = brakes_torques.x
	rear_brake_torque = brakes_torques.y
	
	if automatic:
		var reversing = false
		var shift_time = 700
		var next_gear_rpm = 0
		if selected_gear < gear_ratios.size():
			next_gear_rpm = gear_ratios[selected_gear] * final_drive * avg_front_spin * AV_2_RPM
		
		var prev_gear_rpm = 0
		if selected_gear - 1 > 0:
			prev_gear_rpm = gear_ratios[selected_gear - 1] * final_drive * avg_front_spin * AV_2_RPM
		
		if selected_gear == -1:
			reversing = true

		var torque_bigger_next_gear = engineTorque(next_gear_rpm) > torque_out - drag_torque
		if torque_bigger_next_gear and selected_gear >= 0:
			if rpm > 0.85 * max_engine_rpm:
				if Time.get_ticks_msec() - last_shift_time > shift_time:
					shiftUp()
		var torque_bigger_prev_gear = engineTorque(prev_gear_rpm) > torque_out - drag_torque
		if selected_gear > 1 and rpm < 0.5 * max_engine_rpm and torque_bigger_prev_gear:
			if Time.get_ticks_msec() - last_shift_time > shift_time:
				shiftDown()
		if abs(selected_gear) <= 1 and abs(z_vel) < 3.0 and brake_input > 0.2:
			if not reversing:
				if Time.get_ticks_msec() - last_shift_time > shift_time:
					shiftDown()
			else:
				if Time.get_ticks_msec() - last_shift_time > shift_time:
					shiftUp()


func _physics_process(delta):
	local_vel = (global_transform.origin - prev_pos) / delta * global_transform.basis
	prev_pos = global_transform.origin
	z_vel = -local_vel.z
	x_vel = local_vel.x
	dragForce()
	
	##### AntiRollBar #####
	var prev_comp = susp_comp
	susp_comp[2] = wheel_bl.apply_forces(prev_comp[3], delta)
	susp_comp[3] = wheel_br.apply_forces(prev_comp[2], delta)
	susp_comp[0] = wheel_fr.apply_forces(prev_comp[1], delta)
	susp_comp[1] = wheel_fl.apply_forces(prev_comp[0], delta)
	
	##### Steerin with steer speed #####
	if (steering_input < steering_amount):
		steering_amount -= steer_speed * delta
		if (steering_input > steering_amount):
			steering_amount = steering_input
	
	elif (steering_input > steering_amount):
		steering_amount += steer_speed * delta
		if (steering_input < steering_amount):
			steering_amount = steering_input
	
	wheel_fl.steer(steering_amount, max_steer)
	wheel_fr.steer(steering_amount, max_steer)
	
	##### Engine loop #####
	drag_torque = engine_brake + rpm * engine_drag
	torque_out = (engineTorque(rpm) + drag_torque ) * throttle_input
	engine_net_torque = torque_out + clutch_reaction_torque - drag_torque
	
	rpm += AV_2_RPM * delta * engine_net_torque / engine_moment
	engine_angular_vel = rpm / AV_2_RPM
	
	if rpm >= max_engine_rpm:
		torque_out = 0
		rpm -= 500 
	
	if rpm <= (rpm_idle + 10) and z_vel <= 2:
		clutch_input = 1.0
	
	if selected_gear == 0:
		freewheel(delta)
	else:
		engage(delta)
		
	rpm = max(rpm , rpm_idle)
	
	if fuel <= 0.0:
		torque_out = 0.0
		rpm = 0.0
		stopEngineSound()
	
	engineSound()
	burnFuel(delta)
	
	
func engineTorque(p_rpm) -> float: 
	var rpm_factor = clamp(p_rpm / max_engine_rpm, 0.0, 1.0)
	var torque_factor = torque_curve.sample_baked(rpm_factor)
	return torque_factor * max_torque


func get_brake_torques(p_brake_input: float, delta):
	var clamping_force := p_brake_input * max_brake_force * 0.5 
	var brake_pad_mu := 0.4
	var effective_radius := 0.25
	var braking_force := 2.0 * brake_pad_mu * clamping_force
	
	var torques := Vector2.ZERO
	
	torques.x = braking_force * effective_radius * front_brake_bias
	torques.y = braking_force * effective_radius * (1 - front_brake_bias)
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
	
	if drivetype == DRIVE_TYPE.RWD:
		gearbox_shaft_speed = avg_rear_spin * drivetrain.get_gearing() 
	elif drivetype == DRIVE_TYPE.FWD:
		gearbox_shaft_speed = avg_front_spin * drivetrain.get_gearing() 
	elif drivetype == DRIVE_TYPE.AWD:
		gearbox_shaft_speed = (avg_front_spin + avg_rear_spin) * 0.5 * drivetrain.get_gearing()
		
	var speed_error = engine_angular_vel - gearbox_shaft_speed
	var clutch_kick = abs(speed_error) * 0.2

	var reaction_torques = clutch.get_reaction_torques(engine_angular_vel, gearbox_shaft_speed, clutch_input, clutch_kick)
	drive_reaction_torque = reaction_torques.x
	clutch_reaction_torque = reaction_torques.y
	
	net_drive = drive_reaction_torque * (1 - clutch_input)
	
	drivetrain.drivetrain(net_drive, rear_brake_torque, front_brake_torque, [wheel_bl, wheel_br, wheel_fl, wheel_fr], delta)

	speedo = avg_front_spin * wheel_fl.tire_radius * 3.6

func dragForce():
	var spd = sqrt(x_vel * x_vel + z_vel * z_vel)
	var cdrag = 0.5 * cd * frontal_area * air_density
	
	# fdrag.y is positive in this case because forward is -z in godot 
	var fdrag: Vector2 = Vector2.ZERO
	fdrag.y = clamp(cdrag * z_vel * spd, -100000, 100000)
	fdrag.x = clamp(-cdrag * x_vel * spd, -100000, 100000)
	
	apply_central_force(global_transform.basis.z.normalized() * fdrag.y)
	apply_central_force(global_transform.basis.x.normalized() * fdrag.x)


func burnFuel(delta):
	var fuel_burned = engine_bsfc * torque_out * rpm * delta / (3600 * PETROL_KG_L * NM_2_KW)
	fuel -= fuel_burned
	self.mass -= fuel_burned * PETROL_KG_L


func shiftUp():
	if selected_gear < gear_ratios.size():
		selected_gear += 1
		last_shift_time = Time.get_ticks_msec()
		drivetrain.set_selected_gear(selected_gear)


func shiftDown():
	if selected_gear > -1:
		selected_gear -= 1
		last_shift_time = Time.get_ticks_msec()
		drivetrain.set_selected_gear(selected_gear)


func engineSound():
	var pitch_scaler = rpm / 1000
	if rpm >= rpm_idle and rpm < max_engine_rpm:
		if audioplayer.stream != engine_sound:
			audioplayer.set_stream(engine_sound)
		if !audioplayer.playing:
			audioplayer.play()
	
	if pitch_scaler > 0.1:
		audioplayer.pitch_scale = pitch_scaler


func stopEngineSound():
	audioplayer.stop()

