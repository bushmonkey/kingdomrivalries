extends Node2D

class_name ProvinceNode

@onready var label = %Label
@onready var color_rect = $ColorRect
@onready var banner_rect = %BannerRect
@onready var area_2d=%Area2D
@onready var province_polygon = $ProvincePolygon 

signal province_hovered(province_data)
signal province_unhovered(province_data)
signal province_clicked(province_data)

const COLOR_HIGHLIGHT_SELECT = Color(2.0, 2.0, 1.5, 1.0) # The "warm" highlight
const COLOR_HIGHLIGHT_HOVER = Color(255, 24, 18, 1.0)  # The "hot" highlight

var province_data: Province # A reference to the actual game logic province
var _base_color: Color
var map_view_controller = null

var _pulse_tween: Tween



func setup(p_data: Province,p_map_view_controller):
	self.province_data = p_data
	self.map_view_controller = p_map_view_controller
	label.text = province_data.province_name
	var player_kingdom = GameManager.player_kingdom
	
	# 2. Check if this province IS the player's capital.
	#    We compare the province data object (p_data) with the player's capital object.
	if is_instance_valid(player_kingdom) and is_instance_valid(player_kingdom.capital):
		if p_data == player_kingdom.capital:
			# If it is, prepend the crown icon to the label text.
			# You can copy-paste the crown emoji directly.
			label.text = "👑 " + label.text
	
func update_color():
	if is_instance_valid(province_data.owner):
		# TODO: Assign a color based on the owner
		if province_data.owner==GameManager.player_kingdom:
			color_rect.color = Color.WEB_GREEN # Placeholder color for owned
			banner_rect.modulate = Color.WEB_GREEN
		else:
			color_rect.color = province_data.owner.color # Placeholder color for owned
			banner_rect.modulate = province_data.owner.color
		_base_color = province_data.owner.color
	else:
	# The base color for an unowned province.
		_base_color = Color.from_string("3a3a3a", Color.ALICE_BLUE)
	color_rect.color = _base_color

# This function will be called by map_view.gd to turn the highlight on or off.
func highlight(is_on: bool,is_hot: bool = false):
	
	if is_instance_valid(_pulse_tween):
		_pulse_tween.kill()
		_pulse_tween = null
		
	if is_on:
		if is_hot:
			# Apply the "hot" hover color
			_start_pulse_animation()
		else:
			# Apply the standard "warm" selection color
			province_polygon.modulate = COLOR_HIGHLIGHT_SELECT
		province_polygon.show()
		
	else:
		province_polygon.modulate = _base_color
		province_polygon.hide() # We can hide it by default

func _start_pulse_animation():
	# Create a new Tween. We use create_tween() to make it scene-bound.
	_pulse_tween = create_tween()
	
	# Set the tween to loop infinitely until we kill it.
	_pulse_tween.set_loops()
	# Set the transition type for a smoother pulse
	_pulse_tween.set_trans(Tween.TRANS_SINE)
	
	# The animation sequence:
	# 1. Animate from the "warm" select color to the "hot" hover color over 0.5 seconds.
	_pulse_tween.tween_property(province_polygon, "modulate", COLOR_HIGHLIGHT_HOVER, 0.5)
	# 2. Animate from the "hot" color back to the "warm" color over 0.7 seconds.
	_pulse_tween.tween_property(province_polygon, "modulate", COLOR_HIGHLIGHT_SELECT, 0.7)
	
#Make the node unclickable when not highlighted ---
# This prevents the player from clicking on invalid provinces.
func set_pickable(is_pickable: bool):
	# The Area2D's monitoring property is the master switch for its signals.
	area_2d.input_pickable = is_pickable
	
	
func _on_area_2d_mouse_entered():
	emit_signal("province_hovered", province_data)

func _on_area_2d_mouse_exited():
	emit_signal("province_unhovered", province_data)
	
	
func _on_area_2d_input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		emit_signal("province_clicked", province_data)
