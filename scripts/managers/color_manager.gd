extends Node

# An array to hold our kingdom color palette.
var kingdom_colors: Array[Color] = [
	Color("e16146"), # Ochre Yellow
	Color("9d2548"), # Russet Red
	Color("678acd"), # Royal Blue
	Color("3a758e"), # Sage Green
	Color("6a7a77"), # Parchment
	Color("4156af"), # Woad Blue
	Color("ffca74"),  # Pale Gold
	Color("853c6e"), # Lavender
	Color("596860"), # Terracotta
	Color("1e253c") # Slate Gray
]

var _next_color_index = 0

# This function provides a unique color from the palette in order.
# It will loop back to the start if we run out of colors.
func get_next_kingdom_color() -> Color:
	if kingdom_colors.is_empty():
		return Color.WHITE # Fallback color
		
	var color = kingdom_colors[_next_color_index]
	
	_next_color_index += 1
	# If the index goes past the end of the array, loop it back to 0.
	if _next_color_index >= kingdom_colors.size():
		_next_color_index = 0
		
	return color

# A function to reset the counter for a new game.
func reset_color_index():
	_next_color_index = 0
