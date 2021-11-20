extends ClippedCamera

export var lerp_speed = 20.0

export (NodePath) var target_path = null
export (Vector3) var offset = Vector3.ZERO
var target = null

func _ready():

	if target_path:
		target = get_node(target_path)
		set_as_toplevel(true)

func _physics_process(delta):
	if !target:
		return
	
#	var nb = global_transform.looking_at(target.global_transform.origin, Vector3.UP)
#	global_transform = global_transform.interpolate_with(nb, lerp_speed * delta)
	var target_pos = target.global_transform.translated(offset)
	global_transform = global_transform.interpolate_with(target_pos, lerp_speed * delta)
	self.look_at(target.global_transform.origin + Vector3(0, 1, 0), target.transform.basis.y)
