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
@export var ackermann := 0.15
@export var front_brake_bias := 0.6
@export var steer_speed := 5.0
@export var max_brake_force := 20000.0
@export var max_handbrake_torque := 3000.0
@export var brake_effective_radius := 0.25

@export var fuel_tank_size := 40.0 #Liters
@export var fuel_percentage := 100.0 # % of full tank

######### Engine variables #########
@export var max_torque := 250.0
@export var max_engine_rpm := 8000.0
@export var rpm_idle := 900.0
@export var torque_curve := Curve.new()
@export var throttle_model := Curve.new()
@export var engine_brake := 10.0
@export var engine_moment := 0.25
@export var engine_bsfc := 0.3
@export var engine_sound: AudioStream
@export var clutch_friction := 500.0

######### Drivetrain variables #########
@export var drivetrain_params: DriveTrainParameters

######### Aero #########
@export var cd = 0.3
@export var air_density = 1.225
@export var frontal_area = 2.0

@export var wheel_params_fl: WheelSuspensionParameters
@export var wheel_params_fr: WheelSuspensionParameters
@export var wheel_params_bl: WheelSuspensionParameters
@export var wheel_params_br: WheelSuspensionParameters
