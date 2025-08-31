extends Node2D

var _line_segments: Array = []

# This function is now very "dumb". It just takes data and requests a redraw.
func draw_lines(segments: Array):
	self._line_segments = segments
	queue_redraw()

func _draw():
	# This print statement will now work as expected.
	print("LineDrawer: _draw() is executing with %d segments." % _line_segments.size())
	
	if _line_segments.is_empty():
		return

	# We draw using the direct world coordinates we were given. No conversion needed.
	for segment in _line_segments:
		var start_pos = segment[0]
		var end_pos = segment[1]
		draw_line(start_pos, end_pos, Color(1, 1, 1, 0.5), 3.0, true)
