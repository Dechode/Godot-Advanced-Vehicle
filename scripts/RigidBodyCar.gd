extends RigidBody

class_name BaseCar

enum REAR_DIFF_TYPE{
	ONE_WAY_LSD,
	TWO_WAY_LSD,
	OPEN_DIFF,
}


export (float) var max_steer = 0.3 
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
export (Array) var gear_ratios = [ 3.1, 2.61, 2.1, 1.72, 1.2, 1.0 ] 
export (float) var final_drive = 3.7
export (float) var reverse_ratio = 3.9
export (REAR_DIFF_TYPE) var rear_diff = REAR_DIFF_TYPE.ONE_WAY_LSD
export (float) var gear_inertia = 0.02
######## CONSTANTS ########

const PETROL_KG_L: float = 0.7489
const NM_2_KW: int = 9549
const AV_2_RPM: float = 60 / TAU

######### Controller inputs #########
var throttle_input: float = 0.0
var steering_input: float = 0.0
var brake_input: float = 0.0
var handbrake_input: float = 0.0

######### Misc #########
var fuel: float = 0.0
var drag_torque: float = 0.0
var torque_out: float = 0.0
var net_drive: float = 0.0

var rpm: float = 0.0

var brake_torque: float = 0.0
var selected_gear: int = 0


var r_split: float = 0.5

var steering_amount: float = 0.0

var speedo: float = 0.0
var wheel_radius: float = 0.0
var susp_comp: Array = [0.5, 0.5, 0.5, 0.5]

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


func _physics_process(delta):
	brake_torque = max_brake_force * brake_input * 0.25
	
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
	torque_out = (engineTorque(rpm) + drag_torque) * throttle_input
	rpm += AV_2_RPM * delta * (torque_out - drag_torque) / engine_moment
	
	if rpm >= max_engine_rpm:
		torque_out = 0
		rpm -= 500 
		
	if selected_gear == 0:
		freewheel(delta)
	else:
		engage(delta)
		
	var clutch_rpm = rpm_idle
	if abs(selected_gear) == 1: 
		clutch_rpm = rpm_idle
		clutch_rpm += throttle_input * rpm_clutch_out
	rpm = max(rpm , clutch_rpm)
	
	if fuel <= 0.0:
		torque_out = 0.0
		rpm = 0.0
		stopEngineSound()
	
	handBrake(delta)
	engineSound()
	burnFuel(delta)
	
	
func engineTorque(r_p_m) -> float: 
	var rpm_factor = clamp(r_p_m / max_engine_rpm, 0.0, 1.0)
	var torque_factor = torque_curve.interpolate_baked(rpm_factor)
	return torque_factor * max_torque
	

func freewheel(delta):
	var avg_spin: float = 0.0
	wheel_bl.apply_torque(0.0, 0.0, brake_torque, delta)
	wheel_br.apply_torque(0.0, 0.0, brake_torque, delta)
	wheel_fl.apply_torque(0.0, 0.0, brake_torque, delta)
	wheel_fr.apply_torque(0.0, 0.0, brake_torque, delta)
	avg_spin += wheel_fl.spin * 0.5 + wheel_fr.spin * 0.5
	speedo = avg_spin * wheel_radius * 3.6
	
	
func engage(delta):
	var avg_rear_spin = 0.0
	var avg_front_spin = 0.0
	net_drive = (torque_out - drag_torque) * gearRatio()
	
	avg_rear_spin += (wheel_bl.spin + wheel_br.spin) * 0.5
	avg_front_spin += (wheel_fl.spin + wheel_fr.spin) * 0.5
	
	if avg_rear_spin * sign(gearRatio()) < 0:
		net_drive += drag_torque * gearRatio()
		
	speedo = avg_front_spin * wheel_radius * 3.6
	
	rwd(net_drive, delta)
	wheel_fl.apply_torque(0.0, 0.0, brake_torque, delta)
	wheel_fr.apply_torque(0.0, 0.0, brake_torque, delta)
	rpm = avg_rear_spin * gearRatio() * AV_2_RPM


func gearRatio():
	if selected_gear > 0:
		return gear_ratios[selected_gear - 1] * final_drive
	elif selected_gear == -1:
		return -reverse_ratio * final_drive
	else:
		return 0
	
	
func rwd(drive, delta):
	var drivetrain_inertia
#	drivetrain_inertia = engine_moment + pow(abs(gearRatio()), 2) * gear_inertia # This should (?) be physically the most correct way, but i find it has way too much moment of inertia 
#	drivetrain_inertia = engine_moment * abs(gearRatio()) # This is how Wolfe does hes inertia calculation, but again i find it has too much moment of inertia
#	drivetrain_inertia = gear_inertia * abs(gearRatio()) # This one ignores engines moment of inertia alltogether
	drivetrain_inertia = gear_inertia * abs(gearRatio()) + engine_moment # Works best imo

#	print(drivetrain_inertia)
	
	if rear_diff == REAR_DIFF_TYPE.ONE_WAY_LSD and drive * sign(gearRatio()) > 0:
		r_split = 0.5  # Simple 1-way LSD
	if rear_diff == REAR_DIFF_TYPE.TWO_WAY_LSD:
		r_split = 0.5  # Simple 2-way LSD 
		
	var diff_sum: float = 0.0
	
	diff_sum -= wheel_br.apply_torque(drive * (1 - r_split), drivetrain_inertia, brake_torque, delta)
	diff_sum += wheel_bl.apply_torque(drive * r_split, drivetrain_inertia, brake_torque, delta)
	
	r_split = 0.5 * (clamp(diff_sum, -1, 1) + 1)


func burnFuel(delta):
	var fuel_burned = engine_bsfc * torque_out * rpm * delta / (3600 * PETROL_KG_L * NM_2_KW)
	fuel -= fuel_burned
	self.mass -= fuel_burned * PETROL_KG_L


func handBrake(delta):
	var handbrake_torque = handbrake_input * max_brake_force
	wheel_bl.apply_torque(0,0, handbrake_torque, delta)
	wheel_br.apply_torque(0,0, handbrake_torque, delta)


func shiftUp():
	if selected_gear < gear_ratios.size():
		selected_gear += 1


func shiftDown():
	if selected_gear > -1:
		selected_gear -= 1


func engineSound():
	var pitch_scaler = rpm / 1000
	if rpm >= rpm_idle and rpm < max_engine_rpm:
		if audioplayer.stream != engine_sound:
			audioplayer.set_stream(engine_sound)
		if !audioplayer.playing:
			audioplayer.play()
	
	if pitch_scaler > 0:
		audioplayer.pitch_scale = pitch_scaler
func stopEngineSound():
	audioplayer.stop()
