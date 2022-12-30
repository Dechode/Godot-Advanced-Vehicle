extends RigidBody

class_name BaseCar


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


export (float) var max_steer = 0.3
export (float, 0.0, 1.0) var front_brake_bias = 0.6
export (float) var Steer_Speed = 5.0
export (float) var max_brake_force = 500
export (float) var fuel_tank_size = 40.0 #Liters
export (float) var fuel_percentage = 100 # % of full tank

######### Engine variables #########
export (float) var max_torque = 250
export (float) var max_engine_rpm = 8000.0
export (float) var rpm_clutch_out = 1500
export (float) var rpm_idle = 900
export (Curve) var torque_curve = null
export (float) var engine_drag = 0.03
export (float) var engine_brake = 10.0
export (float) var engine_moment = 0.25
export (float) var engine_bsfc = 0.3
export (AudioStream) var engine_sound

######### Drivetrain variables #########
export (DRIVE_TYPE) var drivetype = DRIVE_TYPE.RWD
export (Array) var gear_ratios = [ 3.1, 2.61, 2.1, 1.72, 1.2, 1.0 ] 
export var automatic := true
export (float) var final_drive = 3.7
export (float) var reverse_ratio = 3.9
export (float) var gear_inertia = 0.02
export (DIFF_TYPE) var rear_diff = DIFF_TYPE.LIMITED_SLIP
export (DIFF_TYPE) var front_diff = DIFF_TYPE.LIMITED_SLIP
export (float) var rear_diff_preload = 50
export (float) var front_diff_preload = 50
export var rear_diff_power_ratio: float = 3.5
export var front_diff_power_ratio: float = 3.5
export var rear_diff_coast_ratio: float = 1
export var front_diff_coast_ratio: float = 1
export (float, 0, 1) var center_split_f_r = 0.4 # AWD torque split front / rear
export (float) var clutch_friction = 500

######### Aero #########
export (float) var cd = 0.3
export (float) var air_density = 1.225
export (float) var frontal_area = 2.0

######## CONSTANTS ########
const PETROL_KG_L: float = 0.7489
const NM_2_KW: int = 9549
const AV_2_RPM: float = 60 / TAU

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

var rear_brake_force: float = 0.0
var front_brake_force: float = 0.0
var selected_gear: int = 0

var drive_inertia: float = 0.0 #includes every inertia after engine and before wheels (wheels include brakes inertia)

var r_split: float = 0.5
var f_split: float = 0.5

var steering_amount: float = 0.0

var speedo: float = 0.0
var wheel_radius: float = 0.0
var susp_comp: Array = [0.5, 0.5, 0.5, 0.5]

var avg_rear_spin = 0.0
var avg_front_spin = 0.0

var local_vel: Vector3 = Vector3.ZERO
var prev_pos: Vector3 = Vector3.ZERO
var z_vel: float = 0.0
var x_vel: float = 0.0

var last_shift_time = 0

onready var wheel_fl = $Wheel_fl
onready var wheel_fr = $Wheel_fr
onready var wheel_bl = $Wheel_bl
onready var wheel_br = $Wheel_br
onready var audioplayer = $EngineSound


func _ready() -> void:
	wheel_radius = wheel_fl.tire_radius
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
	
	drive_inertia = engine_moment + pow(abs(gearRatio()), 2) * gear_inertia
	
	front_brake_force = max_brake_force * brake_input * front_brake_bias * 0.5 # Per wheel
	
	var rear_brake_input = max(brake_input, handbrake_input)
	rear_brake_force = max_brake_force * rear_brake_input * (1 - front_brake_bias) * 0.5 # Per wheel
	
	if automatic:
		var reversing = false
		
		var shift_time = 700
		var next_gear_rpm = 0
		
		if selected_gear + 1 < gear_ratios.size():
			next_gear_rpm = gear_ratios[selected_gear + 1] * final_drive
		
		if selected_gear == -1:
			reversing = true
		
		# if torque is bigger in next gear change gear up
#		if engineTorque(next_gear_rpm) > engine_net_torque:
		# if rpm is bigger in next gear change gear up
		if rpm > 0.85 * max_engine_rpm:
			if selected_gear >= 0:
				if Time.get_ticks_msec() - last_shift_time > shift_time:
					shiftUp()
		
		elif selected_gear > 1 and rpm < 0.3 * max_engine_rpm:
			if Time.get_ticks_msec() - last_shift_time > shift_time:
				shiftDown()
				
		elif abs(selected_gear) <= 1 and abs(z_vel) < 0.5 and brake_input > 0.2:
			if not reversing:
				if Time.get_ticks_msec() - last_shift_time > shift_time:
					shiftDown()
			else:
				if Time.get_ticks_msec() - last_shift_time > shift_time:
					shiftUp()

func _physics_process(delta):
	local_vel = global_transform.basis.xform_inv((global_transform.origin - prev_pos) / delta)
	prev_pos = global_transform.origin
	z_vel = -local_vel.z
	x_vel = local_vel.x
#	prints("z velocity =", z_vel)
	dragForce()
	##### AntiRollBar #####
	var prev_comp = susp_comp
	susp_comp[2] = wheel_bl.apply_forces(prev_comp[3], delta)
	susp_comp[3] = wheel_br.apply_forces(prev_comp[2], delta)
	susp_comp[0] = wheel_fr.apply_forces(prev_comp[1], delta)
	susp_comp[1] = wheel_fl.apply_forces(prev_comp[0], delta)
	
	##### Steerin with steer speed #####
	if (steering_input < steering_amount):
		steering_amount -= Steer_Speed * delta
		if (steering_input > steering_amount):
			steering_amount = steering_input
	
	elif (steering_input > steering_amount):
		steering_amount += Steer_Speed * delta
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
	var torque_factor = torque_curve.interpolate_baked(rpm_factor)
	return torque_factor * max_torque
	

func freewheel(delta):
	clutch_reaction_torque = 0.0
	avg_front_spin = 0.0
	wheel_bl.apply_torque(0.0, 0.0, rear_brake_force, delta)
	wheel_br.apply_torque(0.0, 0.0, rear_brake_force, delta)
	wheel_fl.apply_torque(0.0, 0.0, front_brake_force, delta)
	wheel_fr.apply_torque(0.0, 0.0, front_brake_force, delta)
	avg_front_spin += (wheel_fl.spin + wheel_fr.spin) * 0.5
	speedo = avg_front_spin * wheel_radius * 3.6
	
	
func engage(delta):
	avg_rear_spin = 0.0
	avg_front_spin = 0.0

	avg_rear_spin += (wheel_bl.spin + wheel_br.spin) * 0.5
	avg_front_spin += (wheel_fl.spin + wheel_fr.spin) * 0.5
	
	var gearbox_shaft_speed: float
	
	if drivetype == DRIVE_TYPE.RWD:
		gearbox_shaft_speed = avg_rear_spin * gearRatio() 
	elif drivetype == DRIVE_TYPE.FWD:
		gearbox_shaft_speed = avg_front_spin * gearRatio() 
	elif drivetype == DRIVE_TYPE.AWD:
		gearbox_shaft_speed = (avg_front_spin + avg_rear_spin) * 0.5 * gearRatio()
		
#	var speed_error = engine_angular_vel - gearbox_shaft_speed 
#	var speed_error_scaled = speed_error * AV_2_RPM / max_engine_rpm

	var clutch_torque: float = clutch_friction * (1 - clutch_input)# * (1 - speed_error_scaled)
	
	if engine_angular_vel > gearbox_shaft_speed:
		clutch_reaction_torque = -clutch_torque
		drive_reaction_torque = clutch_torque
	else:
		clutch_reaction_torque = clutch_torque
		drive_reaction_torque = -clutch_torque
	
	net_drive = drive_reaction_torque * gearRatio() * (1 - clutch_input) 
	
	if drivetype == DRIVE_TYPE.RWD:
#		if avg_rear_spin * sign(gearRatio()) < 0: # Should these still be in here? works better without
#			net_drive += drag_torque * gearRatio()
		
		rwd(net_drive, delta)
		wheel_fl.apply_torque(0.0, 0.0, front_brake_force, delta)
		wheel_fr.apply_torque(0.0, 0.0, front_brake_force, delta)
		
	elif drivetype == DRIVE_TYPE.AWD:
		awd(net_drive, delta)
	
	elif drivetype == DRIVE_TYPE.FWD:
		
#		if avg_front_spin * sign(gearRatio()) < 0: # Should these still be in here? works better without
#			net_drive += drag_torque * gearRatio()
		
		fwd(net_drive, delta)
		wheel_bl.apply_torque(0.0, 0.0, rear_brake_force, delta)
		wheel_br.apply_torque(0.0, 0.0, rear_brake_force, delta)
		
	speedo = avg_front_spin * wheel_radius * 3.6


func gearRatio():
	if selected_gear > 0:
		return gear_ratios[selected_gear - 1] * final_drive
	elif selected_gear == -1:
		return -reverse_ratio * final_drive
	else:
		return 0.0


func rwd(drive, delta):
	var diff_locked = true
	var t_error = wheel_bl.force_vec.y * wheel_bl.tire_radius - wheel_br.force_vec.y * wheel_br.tire_radius
	
	if drive * sign(gearRatio()) > 0: # We are powering
		if abs(t_error) > rear_diff_preload * rear_diff_power_ratio:
			diff_locked = false
	else: # We are coasting
		if abs(t_error) > rear_diff_preload * rear_diff_coast_ratio:
			diff_locked = false
	
	if rear_diff == DIFF_TYPE.LOCKED:
		diff_locked = true
	elif rear_diff == DIFF_TYPE.OPEN_DIFF:
		diff_locked = false
	
	if !diff_locked:
#		print("Unlocked")
		var diff_sum: float = 0.0
		
		diff_sum -= wheel_br.apply_torque(drive * (1 - r_split), drive_inertia, rear_brake_force, delta)
		diff_sum += wheel_bl.apply_torque(drive * r_split, drive_inertia, rear_brake_force, delta)
		
		r_split = 0.5 * (clamp(diff_sum, -1, 1) + 1)
		
	else:
		r_split = 0.5
#		print("Locked")
		# Initialize net_torque with previous frame's friction
		var net_torque = (wheel_bl.force_vec.y * wheel_bl.tire_radius + wheel_br.force_vec.y * wheel_br.tire_radius)# * 0.5
		net_torque += drive
		var axle_spin = 0.0
		# Stop wheel if brakes overwhelm other forces
		if avg_rear_spin < 5 and rear_brake_force > abs(net_torque):
			axle_spin = 0.0
		else:
			var f_rr = (wheel_bl.rolling_resistance + wheel_br.rolling_resistance)
			net_torque -= (2 * rear_brake_force + f_rr)  * sign(avg_rear_spin)
			axle_spin = avg_rear_spin + (delta * net_torque / (wheel_bl.wheel_moment + drive_inertia + wheel_br.wheel_moment ))
				
		wheel_br.applySolidAxleSpin(axle_spin)
		wheel_bl.applySolidAxleSpin(axle_spin)



func fwd(drive, delta):
	var diff_locked = true
	var t_error = wheel_fl.force_vec.y * wheel_fl.tire_radius - wheel_fr.force_vec.y * wheel_fr.tire_radius
	
	if drive * sign(gearRatio()) > 0: # We are powering
		if abs(t_error) > front_diff_preload * front_diff_power_ratio:
			diff_locked = false
	else: # We are coasting
		if abs(t_error) > front_diff_preload * front_diff_coast_ratio:
			diff_locked = false
	
	if front_diff == DIFF_TYPE.LOCKED:
		diff_locked = true
	elif front_diff == DIFF_TYPE.OPEN_DIFF:
		diff_locked = false
	
	if !diff_locked:
#		print("Unlocked")
		var diff_sum: float = 0.0
		
		diff_sum -= wheel_fr.apply_torque(drive * (1 - f_split), drive_inertia, front_brake_force, delta)
		diff_sum += wheel_fl.apply_torque(drive * f_split, drive_inertia, front_brake_force, delta)
		
		f_split = 0.5 * (clamp(diff_sum, -1, 1) + 1)
		
	else:
		f_split = 0.5
#		print("Locked")
		# Initialize net_torque with previous frame's friction
		var net_torque = (wheel_fl.force_vec.y * wheel_fl.tire_radius + wheel_fr.force_vec.y * wheel_fr.tire_radius)# * 0.5
		net_torque += drive
		var axle_spin = 0.0
		# Stop wheel if brakes overwhelm other forces
		if avg_front_spin < 5 and front_brake_force > abs(net_torque):
			axle_spin = 0.0
		else:
			var f_rr = (wheel_fl.rolling_resistance + wheel_fr.rolling_resistance)
			net_torque -= (2 * front_brake_force + f_rr)  * sign(avg_front_spin)
			axle_spin = avg_front_spin + (delta * net_torque / (wheel_fl.wheel_moment + drive_inertia + wheel_fr.wheel_moment ))
			
		wheel_fr.applySolidAxleSpin(axle_spin)
		wheel_fl.applySolidAxleSpin(axle_spin)


func awd(drive, delta):
	
	var rear_drive = drive * (1 - center_split_f_r)
	var front_drive = drive * center_split_f_r
	
	var front_diff_locked = true
	var rear_diff_locked = true
	
	var front_t_error = wheel_fl.force_vec.y * wheel_fl.tire_radius - wheel_fr.force_vec.y * wheel_fr.tire_radius
	var rear_t_error = wheel_bl.force_vec.y * wheel_bl.tire_radius - wheel_br.force_vec.y * wheel_br.tire_radius
	
	if drive * sign(gearRatio()) > 0: # We are powering
		if abs(rear_t_error) > rear_diff_preload * rear_diff_power_ratio:
			rear_diff_locked = false
			
		if abs(front_t_error) > front_diff_preload * front_diff_power_ratio:
			front_diff_locked = false
			
	else: # We are coasting
		if abs(rear_t_error) > rear_diff_preload * rear_diff_coast_ratio:
			rear_diff_locked = false
		
		if abs(front_t_error) > front_diff_preload * front_diff_power_ratio:
			front_diff_locked = false
	
	
	if rear_diff == DIFF_TYPE.LOCKED:
		rear_diff_locked = true
	
	if front_diff == DIFF_TYPE.LOCKED:
		front_diff_locked = true
	
	
	if !rear_diff_locked:
		var rear_diff_sum: float = 0.0
		
		rear_diff_sum -= wheel_br.apply_torque(rear_drive * (1 - r_split), drive_inertia, rear_brake_force, delta)
		rear_diff_sum += wheel_bl.apply_torque(rear_drive * r_split, drive_inertia, rear_brake_force, delta)
		
		r_split = 0.5 * (clamp(rear_diff_sum, -1, 1) + 1)
		
	else:
		r_split = 0.5
		
		# Initialize net_torque with previous frame's friction
		var net_torque = (wheel_bl.force_vec.y * wheel_bl.tire_radius + wheel_br.force_vec.y * wheel_br.tire_radius)# * 0.5
		net_torque += rear_drive
		var axle_spin = 0.0
		# Stop wheel if brakes overwhelm other forces
		if avg_rear_spin < 5 and rear_brake_force > abs(net_torque):
			axle_spin = 0.0
		else:
			var f_rr = (wheel_bl.rolling_resistance + wheel_br.rolling_resistance)
			net_torque -= (2 * rear_brake_force + f_rr) * sign(avg_rear_spin)
			axle_spin = avg_rear_spin + (delta * net_torque / (wheel_bl.wheel_moment + drive_inertia + wheel_br.wheel_moment ))
		
		wheel_br.applySolidAxleSpin(axle_spin)
		wheel_bl.applySolidAxleSpin(axle_spin)
	
	if !front_diff_locked:
		
		var front_diff_sum: float = 0.0
		
		front_diff_sum -= wheel_fr.apply_torque(front_drive * (1 - f_split), drive_inertia, front_brake_force, delta)
		front_diff_sum += wheel_fl.apply_torque(front_drive * f_split, drive_inertia, front_brake_force, delta)
		
		f_split = 0.5 * (clamp(front_diff_sum, -1, 1) + 1)
	else:
		f_split = 0.5
		
		# Initialize net_torque with previous frame's friction
		var net_torque = (wheel_fl.force_vec.y * wheel_fl.tire_radius + wheel_fr.force_vec.y * wheel_fr.tire_radius)# * 0.5
		net_torque += front_drive
		var axle_spin = 0.0
		# Stop wheel if brakes overwhelm other forces
		if avg_front_spin < 5 and front_brake_force > abs(net_torque):
			axle_spin = 0.0
		else:
			var f_rr = (wheel_fl.rolling_resistance + wheel_fr.rolling_resistance)
			net_torque -= (2 * front_brake_force + f_rr) * sign(avg_front_spin)
			axle_spin = avg_front_spin + (delta * net_torque / (wheel_fl.wheel_moment + drive_inertia + wheel_fr.wheel_moment ))
			
		wheel_fr.applySolidAxleSpin(axle_spin)
		wheel_fl.applySolidAxleSpin(axle_spin)


func dragForce():
	var spd = sqrt(x_vel * x_vel + z_vel * z_vel)
	var cdrag = 0.5 * cd * frontal_area * air_density
	
	# fdrag.y is positive in this case because forward is -z in godot 
	var fdrag: Vector2 = Vector2.ZERO
	fdrag.y = cdrag * z_vel * spd
	fdrag.x = -cdrag * x_vel * spd
	
#	prints("drag force vector =", fdrag)
	
	add_central_force(global_transform.basis.z * fdrag.y)
	add_central_force(global_transform.basis.x * fdrag.x)


func burnFuel(delta):
	var fuel_burned = engine_bsfc * torque_out * rpm * delta / (3600 * PETROL_KG_L * NM_2_KW)
	fuel -= fuel_burned
	self.mass -= fuel_burned * PETROL_KG_L


func shiftUp():
	if selected_gear < gear_ratios.size():
		selected_gear += 1
		last_shift_time = Time.get_ticks_msec()


func shiftDown():
	if selected_gear > -1:
		selected_gear -= 1
		last_shift_time = Time.get_ticks_msec()


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
