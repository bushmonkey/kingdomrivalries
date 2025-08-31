extends Node2D

# A flag to prevent the scene from changing multiple times if input is rapid.
var _is_switching_scene: bool = false

# Godot's built-in function to handle any input that wasn't already consumed by UI elements.
# This is perfect for a "press any key" prompt.
func _input(event: InputEvent):
	if _is_switching_scene:
		return

	# This logic is perfect and does not need to change.
	if (event is InputEventKey and event.is_pressed()) or \
	   (event is InputEventMouseButton and event.is_pressed()):
		
		_is_switching_scene = true
		print("Input detected via _input(). Switching to main game scene...")
		get_tree().change_scene_to_file("res://scenes/main/main_view.tscn")
