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

@export var drivetrain_params: DriveTrainParameters

var selected_gear := 0
var _diff_clutch := Clutch.new() 
var _engine_inertia := 0.0
var _diff_split := 0.5


func set_selected_gear(gear):
	gear = clamp(gear, -1, drivetrain_params.gear_ratios.size())
	selected_gear = gear


func get_gearing() -> float:
	if selected_gear > drivetrain_params.gear_ratios.size():
		return 0.0
	if selected_gear > 0:
		return drivetrain_params.gear_ratios[selected_gear - 1] * drivetrain_params.final_drive
	if selected_gear == -1:
		return -drivetrain_params.reverse_ratio * drivetrain_params.final_drive
	return 0.0


func set_input_inertia(value):
	_engine_inertia =  value


func differential(torque: float, brake_torque, wheels, diff: DiffParameters, delta: float):
	var diff_state = DIFF_STATE.LOCKED
	var tr1 = abs(wheels[0].get_reaction_torque())
	var tr2 = abs(wheels[1].get_reaction_torque())
	
	var delta_torque := 0.0
	var bias := 0.0
	
	if tr1 >= tr2:
		bias = tr1 / tr2
		delta_torque = tr1 - tr2
	else:
		bias = tr2 / tr1
		delta_torque = tr2 - tr1
	
#	print_debug(delta_torque)
	
	var t1 := torque * 0.5
	var t2 := torque * 0.5
	var drive_inertia := _engine_inertia + pow(abs(get_gearing()), 2) * drivetrain_params.gear_inertia
	
	var ratio = diff.power_ratio
	if torque * sign(get_gearing()) < 0:
		ratio = diff.coast_ratio
	
	if diff.diff_type == DIFF_TYPE.OPEN_DIFF:
		diff_state = DIFF_STATE.OPEN
	elif diff.diff_type == DIFF_TYPE.LOCKED:
		diff_state = DIFF_STATE.LOCKED
	else:
#		print_debug(bias)
		if abs(delta_torque) > diff.diff_preload and bias <= ratio:
			diff_state = DIFF_STATE.SLIPPING
#			print_debug("Slipping")
	
#	print_debug(diff_state)
	
	match diff_state:
		DIFF_STATE.OPEN:
			var diff_sum := 0.0
			t2 *= _diff_split
			t1 *= (1 - _diff_split)
			
			diff_sum += wheels[0].apply_torque(t1, brake_torque * 0.5, drive_inertia, delta)
			diff_sum -= wheels[1].apply_torque(t2, brake_torque * 0.5, drive_inertia, delta)
			_diff_split = 0.5 * (clamp(diff_sum, -1.0, 1.0) + 1.0)
		
		DIFF_STATE.SLIPPING:
			_diff_clutch.friction = diff.diff_preload
			var diff_torques = _diff_clutch.get_reaction_torques(wheels[0].get_spin(), wheels[1].get_spin(), 0.0, 0.0)
#			print_debug("diff internal torques = " +  str(diff_torques))
			t1 += diff_torques.x
			t2 += diff_torques.y
			
			wheels[0].apply_torque(t1, brake_torque * 0.5, drive_inertia, delta)
			wheels[1].apply_torque(t2, brake_torque * 0.5, drive_inertia, delta)
			
		DIFF_STATE.LOCKED:
			var net_torque = wheels[0].get_reaction_torque() + wheels[1].get_reaction_torque()
			net_torque += t1 + t2
			var spin: float
			var avg_spin = (wheels[0].get_spin() + wheels[1].get_spin()) * 0.5
			var rolling_resistance = wheels[0].rolling_resistance + wheels[1].rolling_resistance
#			if abs(avg_spin) < 5.0 and brake_torque > abs(t1 + t2):
			if abs(avg_spin) < 5.0 and brake_torque > abs(net_torque):
				spin = 0.0
			else:
				net_torque -= (brake_torque + rolling_resistance) * sign(avg_spin)
			spin = avg_spin + delta * net_torque / (wheels[0].wheel_inertia + drive_inertia + wheels[1].wheel_inertia)
			wheels[0].set_spin(spin)
			wheels[1].set_spin(spin)
			
#			_diff_split = 0.5


func drivetrain(torque: float, rear_brake_torque: float, front_brake_torque: float, wheels: Array, delta: float):
	var rear_wheels = [wheels[0], wheels[1]]
	var front_wheels = [wheels[2], wheels[3]]
	
	var drive_torque = torque * get_gearing()
	
	if drivetrain_params.drivetype == DRIVE_TYPE.RWD:
		differential(drive_torque, rear_brake_torque, rear_wheels, drivetrain_params.rear_diff, delta)
		front_wheels[0].apply_torque(0.0, front_brake_torque * 0.5, 0.0, delta)
		front_wheels[1].apply_torque(0.0, front_brake_torque * 0.5, 0.0, delta)
	
	elif drivetrain_params.drivetype == DRIVE_TYPE.FWD:
		differential(drive_torque, front_brake_torque, front_wheels, drivetrain_params.front_diff, delta)
		rear_wheels[0].apply_torque(0.0, rear_brake_torque * 0.5, 0.0, delta)
		rear_wheels[1].apply_torque(0.0, rear_brake_torque * 0.5, 0.0, delta)
	
	
	elif drivetrain_params.drivetype == DRIVE_TYPE.AWD:
		
#		if drivetrain_params.center_diff.diff_type == DIFF_TYPE.LOCKED:
		match drivetrain_params.center_diff.diff_type:
			DIFF_TYPE.LOCKED:
				var rear_spin = (wheels[0].get_spin() + wheels[1].get_spin()) * 0.5
				var front_spin = (wheels[2].get_spin() + wheels[3].get_spin()) * 0.5 
				var avg_spin = (front_spin + rear_spin) * 0.5
				
				var net_torque := 0.0
				var combined_wheel_inertias := 0.0
				var rolling_resistance := 0.0
				
				for w in wheels:
					net_torque += w.get_reaction_torque()
					combined_wheel_inertias += w.wheel_inertia
					rolling_resistance += w.rolling_resistance
					
				net_torque += drive_torque
	#			print_debug(net_torque)
				var brake_torque := rear_brake_torque + front_brake_torque
				
				var spin := 0.0
				if abs(avg_spin) < 5.0 and brake_torque > abs(net_torque):
					spin = 0.0
				else:
					net_torque -= (brake_torque + abs(rolling_resistance)) * sign(avg_spin)
				
					var drive_inertia = _engine_inertia + pow(abs(get_gearing()), 2) * drivetrain_params.gear_inertia# * 2
					drive_inertia += combined_wheel_inertias
	#				print_debug(avg_spin)
					spin = avg_spin + delta * net_torque / drive_inertia
				
				wheels[0].set_spin(spin)
				wheels[1].set_spin(spin)
				wheels[2].set_spin(spin)
				wheels[3].set_spin(spin)
			
			DIFF_TYPE.LIMITED_SLIP:
				var rear_drive = drive_torque * (1 - drivetrain_params.center_split_fr)
				var front_drive = drive_torque * drivetrain_params.center_split_fr
				
				differential(rear_drive, rear_brake_torque, rear_wheels, drivetrain_params.rear_diff, delta)
				differential(front_drive, front_brake_torque, front_wheels, drivetrain_params.front_diff, delta)
			
			DIFF_TYPE.OPEN_DIFF:
				var rear_drive = drive_torque * (1 - drivetrain_params.center_split_fr)
				var front_drive = drive_torque * drivetrain_params.center_split_fr
				
				differential(rear_drive, rear_brake_torque, rear_wheels, drivetrain_params.rear_diff, delta)
				differential(front_drive, front_brake_torque, front_wheels, drivetrain_params.front_diff, delta)
				pass

