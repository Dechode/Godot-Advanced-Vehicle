class_name Clutch
extends Node

@export var friction := 250.0

func get_reaction_torques(av1: float, av2: float, clutch_input: float, kick := 0.0):
	var clutch_torque := (friction + kick) * (1 - clutch_input)
	var reaction_torques := Vector2.ZERO
	if av1 < av2:
		reaction_torques.x = -clutch_torque
		reaction_torques.y = clutch_torque
	else:
		reaction_torques.x = clutch_torque
		reaction_torques.y = -clutch_torque
	return reaction_torques
	
