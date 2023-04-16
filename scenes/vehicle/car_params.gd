class_name CarParameters
extends Resource


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
@export var max_brake_force := 20000.0
@export var brake_effective_radius := 0.25

@export var fuel_tank_size := 40.0 #Liters
@export var fuel_percentage := 100.0 # % of full tank

######### Engine variables #########
@export var max_torque = 250.0
@export var max_engine_rpm = 8000.0
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
@export var automatic := false

@export var gear_ratios = [ 3.1, 2.61, 2.1, 1.72, 1.2, 1.0 ] 
@export var final_drive = 3.7
@export var reverse_ratio = 3.9
@export var gear_inertia = 0.12

@export var front_diff = DIFF_TYPE.LIMITED_SLIP
@export var front_diff_preload = 50.0
@export var front_diff_power_ratio: float = 2.0
@export var front_diff_coast_ratio: float = 1.0
@export var rear_diff = DIFF_TYPE.LIMITED_SLIP
@export var rear_diff_preload = 50.0
@export var rear_diff_power_ratio: float = 2.0
@export var rear_diff_coast_ratio: float = 1.0

@export var center_split_fr = 0.4 # AWD torque split front / rear

######### Aero #########
@export var cd = 0.3
@export var air_density = 1.225
@export var frontal_area = 2.0

@export var wheel_params_fl: WheelSuspensionParameters
@export var wheel_params_fr: WheelSuspensionParameters
@export var wheel_params_bl: WheelSuspensionParameters
@export var wheel_params_br: WheelSuspensionParameters

######### Choose what tire formula to use ########
#@export var tire_model_fl: BaseTireModel 
#@export var tire_model_fr: BaseTireModel 
#@export var tire_model_bl: BaseTireModel 
#@export var tire_model_br: BaseTireModel 
#
######### Suspension ########
#@export var spring_length_fl = 0.2
#@export var spring_length_fr = 0.2
#@export var spring_length_bl = 0.2
#@export var spring_length_br = 0.2
#
#@export var spring_stiffness_fl = 45000.0
#@export var spring_stiffness_fr = 45000.0
#@export var spring_stiffness_bl = 45000.0
#@export var spring_stiffness_br = 45000.0
#
#@export var bump_fl = 10000.0
#@export var bump_fr = 10000.0
#@export var bump_bl = 10000.0
#@export var bump_br = 10000.0
#
#@export var rebound_fl = 11000.0
#@export var rebound_fr = 11000.0
#@export var rebound_bl = 11000.0
#@export var rebound_br = 11000.0
#
#@export var anti_roll_front = 50.0
#@export var anti_roll_rear = 50.0
#
######### Tire stuff ########
#@export var wheel_mass_fl = 20.0
#@export var wheel_mass_fr = 20.0
#@export var wheel_mass_bl = 20.0
#@export var wheel_mass_br = 20.0
#
#@export var tire_radius_fl = 0.3
#@export var tire_radius_fr = 0.3
#@export var tire_radius_bl = 0.3
#@export var tire_radius_br = 0.3
#
#@export var tire_width_fl = 0.2
#@export var tire_width_fr = 0.2
#@export var tire_width_bl = 0.2
#@export var tire_width_br = 0.2
#
#@export var ackermann_fl = 0.15
#@export var ackermann_fr = -0.15
#@export var ackermann_bl = 0.0
#@export var ackermann_br = 0.0
