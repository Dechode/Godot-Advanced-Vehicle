class_name ModularCar
extends RigidBody

export var cd: float = 0.3
export var frontal_area: float = 2.0
export var air_density: float = 1.3

var local_vel := Vector3.ZERO
var prev_pos := Vector3.ZERO

var susp_comp: Array = [0.5, 0.5, 0.5, 0.5]

var wheels: Array = []
var wings: Array = []

onready var wheel_fl = $RaycastSuspension4
onready var wheel_fr = $RaycastSuspension3
onready var wheel_bl = $RaycastSuspension2
onready var wheel_br = $RaycastSuspension


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for child in get_children():
		if child is RaycastSuspension:
			wheels.append(child)
#		elif child is Aero:
		elif child.is_in_group("Aero"):
			wings.append(child)

#
#func _process(delta: float) -> void:
#	VehicleAPI.set_vehicle_speed(local_vel.z)


func _physics_process(delta: float) -> void:
	local_vel = global_transform.basis.xform_inv((global_transform.origin - prev_pos) / delta)
	prev_pos = global_transform.origin
	
	var prev_comp = susp_comp
	susp_comp[2] = wheel_bl.apply_forces(prev_comp[3], delta)
	susp_comp[3] = wheel_br.apply_forces(prev_comp[2], delta)
	susp_comp[0] = wheel_fr.apply_forces(prev_comp[1], delta)
	susp_comp[1] = wheel_fl.apply_forces(prev_comp[0], delta)


func _integrate_forces(state: PhysicsDirectBodyState) -> void:
#	var collision_count = state.get_contact_count()
#	var impact_pos = 0
#	if collision_count > 0:
#		impact_pos = state.get_contact_local_position(collision_count - 1)
	
	var vel2 = local_vel.length_squared()
	var drag_force = 0.5 * vel2 * cd * frontal_area * air_density if vel2 < 100000 else 0
	state.add_central_force(-local_vel.normalized() * drag_force)
	
	for wheel in wheels:
		if wheel.is_colliding():
			var contact = wheel.get_collision_point() - global_transform.origin
			var normal = wheel.get_collision_normal()
			
			state.add_force(normal * wheel.y_force, contact)
			state.add_force(wheel.global_transform.basis.x * wheel.force_vec.x, contact)
			state.add_force(wheel.global_transform.basis.z * wheel.force_vec.y, contact)
	
	for wing in wings:
		state.add_central_force(-local_vel.normalized() * wing.drag_force)
		var offset = wing.global_transform.origin - global_transform.origin
		state.add_force(wing.global_transform.basis.y * wing.lift_force, offset)
