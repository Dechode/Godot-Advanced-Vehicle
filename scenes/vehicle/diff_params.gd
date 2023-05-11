class_name DiffParameters
extends Resource

enum DIFF_TYPE {
	LIMITED_SLIP,
	OPEN_DIFF,
	LOCKED,
}

@export var diff_preload = 50.0
@export var power_ratio: float = 2.0
@export var coast_ratio: float = 1.0

@export var diff_type = DIFF_TYPE.LIMITED_SLIP
