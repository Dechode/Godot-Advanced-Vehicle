## Made by Bastiaan Olij. Available from: https://github.com/BastiaanOlij/vehicle-demo
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


@tool
extends Path3D

@export var track_width = 8.0 : get = get_track_width, set = set_track_width
@export var lower_ground_width = 12.0 : get = get_lower_ground_width, set = set_lower_ground_width

var is_dirty = true


# Called when the node enters the scene tree for the first time.
func _ready():
	call_deferred("_update")


func set_track_width(new_width):
	if track_width != new_width:
		track_width = new_width
		is_dirty = true
		call_deferred("_update")

func get_track_width():
	return track_width


func set_lower_ground_width(new_width):
	if lower_ground_width != new_width:
		lower_ground_width = new_width
		is_dirty = true
		call_deferred("_update")


func get_lower_ground_width():
	return lower_ground_width


func _update():
	if !is_dirty:
		return
	
	var track_half_width = track_width * 0.5
	
	var track = $Road.polygon
	track.set(0, Vector2(-track_half_width, 0.0))
	track.set(1, Vector2(-track_half_width, -0.1))
	track.set(2, Vector2( track_half_width, -0.1))
	track.set(3, Vector2( track_half_width, 0.0))
	$Road.polygon = track
	
	var ground = $Ground.polygon
	ground.set(1, Vector2( track_half_width + 2.0, -0.1))
	ground.set(0, Vector2(-track_half_width - 2.0, -0.1))
	ground.set(2, Vector2( lower_ground_width, -4.01))
	ground.set(3, Vector2( lower_ground_width + 0.1, -4.1))
	ground.set(4, Vector2(-lower_ground_width - 0.1, -4.1))
	ground.set(5, Vector2(-lower_ground_width, -4.0))
	$Ground.polygon = ground
	
	is_dirty = false


func _on_Path_curve_changed():
	is_dirty = true
	call_deferred("_update")
