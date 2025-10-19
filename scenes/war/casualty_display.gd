extends Label

func show_casualties(amount: int, color: Color):
	self.text = "-%d" % amount
	self.modulate = color
	
	# Animate the text moving up and fading out
	var tween = create_tween()
	# Fade out over 1.5 seconds
	tween.tween_property(self, "modulate:a", 0.0, 1.5).from(1.0)
	# Move up by 50 pixels at the same time
	tween.tween_property(self, "position:y", position.y - 50, 1.5).set_trans(Tween.TRANS_CUBIC)
	
	# When the animation is finished, delete the node
	tween.tween_callback(queue_free)
