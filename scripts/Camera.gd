extends ClippedCamera

# This script is taken from Bastiaan Olijs vehicle demo, available at https://github.com/BastiaanOlij/vehicle-demo

#MIT License
#
#Copyright (c) 2018 Bastiaan Olij
#
#Permission is hereby granted, free of charge, to any person obtaining a copy
#of this software and associated documentation files (the "Software"), to deal
#in the Software without restriction, including without limitation the rights
#to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#copies of the Software, and to permit persons to whom the Software is
#furnished to do so, subject to the following conditions:
#
#The above copyright notice and this permission notice shall be included in all
#copies or substantial portions of the Software.
#
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
#SOFTWARE.


export (NodePath) var follow_this_path = null

export var target_distance = 3.0
export var target_height = 1.0
export var lerp_speed = 20.0

var follow_this = null
var last_lookat


func _ready():
	follow_this = get_node(follow_this_path)
	last_lookat = follow_this.global_transform.origin
	set_as_toplevel(true)


func _physics_process(delta):
	set_as_toplevel(true)
	var delta_v = global_transform.origin - follow_this.global_transform.origin
	var target_pos = global_transform.origin

	# ignore y
	delta_v.y = 0.0

	if (delta_v.length() > target_distance):
		delta_v = delta_v.normalized() * target_distance
		delta_v.y = target_height
		target_pos = follow_this.global_transform.origin + delta_v
	else:
		target_pos.y = follow_this.global_transform.origin.y + target_height

	global_transform.origin = global_transform.origin.linear_interpolate(target_pos, delta * lerp_speed)
	last_lookat = last_lookat.linear_interpolate(follow_this.global_transform.origin, delta * lerp_speed)

	look_at(last_lookat, Vector3(0.0, 1.0, 0.0))
