class_name DriveTrain
extends Node

enum DIFF_TYPE{
	LIMITED_SLIP,
	OPEN_DIFF,
	LOCKED,
}

enum DIFF_STATE {
	LOCKED,
	SLIPPING,
	OPEN,
}

enum DRIVE_TYPE{
	FWD,
	RWD,
	AWD,
}

@export var drivetype = DRIVE_TYPE.RWD
@export var gear_ratios = [ 3.1, 2.61, 2.1, 1.72, 1.2, 1.0 ] 
@export var final_drive = 3.7
@export var reverse_ratio = 3.9
@export var gear_inertia = 0.10
@export var automatic := true

@export var rear_diff = DIFF_TYPE.LIMITED_SLIP
@export var front_diff = DIFF_TYPE.LIMITED_SLIP

@export var rear_diff_preload = 50.0
@export var front_diff_preload = 50.0

@export var rear_diff_power_ratio: float = 2.0
@export var front_diff_power_ratio: float = 2.0

@export var rear_diff_coast_ratio: float = 1.0
@export var front_diff_coast_ratio: float = 1.0

@export var center_split_fr = 0.4 # AWD torque split front / rear

var selected_gear := 0
var _diff_clutch = null
var _engine_inertia := 0.0
var _diff_split := 0.5


func _ready():
	_diff_clutch = Clutch.new()
	_diff_clutch.friction = rear_diff_preload
#	print(diff_clutch)


func set_selected_gear(gear):
	gear = clamp(gear, -1, gear_ratios.size())
	selected_gear = gear


func get_gearing() -> float:
	if selected_gear > gear_ratios.size():
		return 0.0
	if selected_gear > 0:
		return gear_ratios[selected_gear - 1] * final_drive
	if selected_gear == -1:
		return -reverse_ratio * final_drive
	return 0.0


func set_input_inertia(value):
	_engine_inertia =  value


func differential(torque, wheels, diff_preload, power_ratio, coast_ratio, diff_type, delta: float):
	var diff_state = DIFF_STATE.LOCKED
	
	var delta_torque = wheels[0].get_reaction_torque() - wheels[1].get_reaction_torque()
	var t1 = torque * 0.5
	var t2 = torque * 0.5
	var drive_inertia = _engine_inertia + pow(abs(get_gearing()), 2) * gear_inertia
	
	var ratio = power_ratio
	if torque * sign(get_gearing()) < 0:
		ratio = coast_ratio
	
	if diff_type == DIFF_TYPE.OPEN_DIFF:
		diff_state = DIFF_STATE.OPEN
	elif diff_type == DIFF_TYPE.LOCKED:
		diff_state = DIFF_STATE.LOCKED
	else:
		if abs(delta_torque) > diff_preload * ratio:
			diff_state = DIFF_STATE.OPEN
	
#	print("Diff state = %d" % diff_state)
	
	match diff_state:
		DIFF_STATE.OPEN:
			var diff_sum := 0.0
			diff_sum += wheels[0].apply_torque(t1 * _diff_split, drive_inertia, delta)
			diff_sum -= wheels[1].apply_torque(t2 * (1 - _diff_split), drive_inertia, delta)
	
			_diff_split = 0.5 * (clamp(diff_sum, -1.0, 1.0) + 1.0)
		
		DIFF_STATE.SLIPPING:
			_diff_clutch.friction = diff_preload
			var diff_torques = _diff_clutch.get_reaction_torques(torque, wheels[0].get_spin(), wheels[1].get_spin(), 0.0)
			t1 += diff_torques.x
			t2 += diff_torques.y
			
			var diff_sum := 0.0
			diff_sum += wheels[0].apply_torque(t1, drive_inertia, delta)
			diff_sum -= wheels[1].apply_torque(t2, drive_inertia, delta)
			_diff_split = 0.5 * (clamp(diff_sum, -1.0, 1.0) + 1.0)
			
		
		DIFF_STATE.LOCKED:
			var net_torque = wheels[0].get_reaction_torque() + wheels[1].get_reaction_torque()
			net_torque += t1 + t2
			var spin: float
			var avg_spin = (wheels[0].get_spin() + wheels[1].get_spin()) * 0.5
			#	if abs(avg_spin) < 5.0 and brake_force > abs(t1 + t2):
			#	if 	spin = 0.0
			#	if else:
			var rolling_resistance = wheels[0].rolling_resistance + wheels[1].rolling_resistance
			#	net_torque -= (brake_force + rolling_resistance) * sign(avg_spin)
			net_torque -= rolling_resistance * sign(avg_spin)
			spin = avg_spin + (delta * net_torque / (wheels[0].wheel_inertia + drive_inertia + wheels[1].wheel_inertia))
			wheels[0].set_spin(spin)
			wheels[1].set_spin(spin)
				
			_diff_split = 0.5


func drivetrain(torque: float, wheels: Array, delta: float):
	var rear_wheels = [wheels[0], wheels[1]]
	var front_wheels = [wheels[2], wheels[3]]

	#print_debug("torque = %d" % int(torque))
	var drive_torque = torque * get_gearing()
	#print_debug("drive_torque = %d" % int(drive_torque))

	if drivetype == DRIVE_TYPE.RWD:
		differential(drive_torque, rear_wheels, rear_diff_preload,
					rear_diff_coast_ratio, rear_diff_power_ratio, rear_diff, delta)

	elif drivetype == DRIVE_TYPE.FWD:
		differential(drive_torque, rear_wheels, rear_diff_preload,
					rear_diff_coast_ratio, rear_diff_power_ratio, rear_diff, delta)
		
	elif drivetype == DRIVE_TYPE.AWD:
		var rear_drive = drive_torque * (1 - center_split_fr)
		var front_drive = drive_torque * center_split_fr
		
		differential(rear_drive, rear_wheels, rear_diff_preload,
					rear_diff_coast_ratio, rear_diff_power_ratio, rear_diff, delta)
		
		differential(front_drive, front_wheels, front_diff_preload,
					front_diff_coast_ratio, front_diff_power_ratio, front_diff, delta)

