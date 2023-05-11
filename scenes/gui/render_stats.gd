class_name RenderStats
extends Control


func _process(delta: float) -> void:
	update_stats()


func update_stats():
	$Panel/VBoxContainer/FPSLabel.text = "FPS = %3.2f" % Performance.get_monitor(Performance.TIME_FPS)
	$Panel/VBoxContainer/StaticMemoryLabel.text = "Static Memory = %4.2f" % (Performance.get_monitor(Performance.MEMORY_STATIC) / 1000000.0)
	$Panel/VBoxContainer/VideoMemoryLabel.text =  "Video Memory = %4.2f" % (Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1000000.0)
	$Panel/VBoxContainer/DrawCallsLabel.text = "Draw Calls = %d" % int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	
