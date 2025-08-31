# res://scenes/ui/map_popup.gd
extends Panel

# This signal will tell the MainView that we want to close.
signal closed
signal zoom_in_pressed
signal zoom_out_pressed

@onready var close_button = %CloseButton
@onready var hover_info_label = %HoverInfoLabel
@onready var map_view = %MapView 
@onready var zoom_in_button = %ZoominButton
@onready var zoom_out_button = %ZoomoutButton
@onready var map_view_container = %MapViewContainer 

const DEFAULT_HOVER_TEXT = "Hover over a province to see details."

var _last_focused_node = null
var _is_hovering_a_province: bool = false
var _currently_hovered_province: Province = null

var map_province_id_entered: int = -1 # Use -1 to indicate no province
var map_province_id_exited: int = -2

func _ready():
	# Connect the button's pressed signal to our closing function.
	close_button.pressed.connect(_on_close_button_pressed)
	hover_info_label.text = DEFAULT_HOVER_TEXT
	
	zoom_in_button.pressed.connect(func(): emit_signal("zoom_in_pressed"))
	zoom_out_button.pressed.connect(func(): emit_signal("zoom_out_pressed"))
	
	# Now that it's set up, we tell it to draw.
	#map_view.call_deferred("initialize_and_draw_map")
	#map_view_container.call_deferred("grab_focus")


# This is the "front door" for configuring the popup from the outside.
func setup(mode: GameManager.MapMode, selectable_provinces: Array[Province]):
	# The MapPopup is now responsible for passing the data down to its child.
	map_view.setup(self, mode, selectable_provinces)
	map_view.initialize_map()
	
	# We can even connect the signal here to keep MainView cleaner.
	map_view.province_selected.connect(_on_map_province_selected)

# We need a new signal to pass the data back up
signal province_selected(province_data)

func _on_map_province_selected(province_data: Province):
	# Just pass the signal along
	emit_signal("province_selected", province_data)
	queue_free()
	
func _on_close_button_pressed():
	# Emit the signal and then remove the popup from the scene.
	emit_signal("closed")
	queue_free()

# This function is called when the mouse ENTERS a province.
func _on_province_hovered(province_data: Province):
	# Update the "entered" state.
	map_province_id_entered = province_data.id
	print("entered",map_province_id_entered)
	# Update the label text.
	if is_instance_valid(province_data.owner):
		hover_info_label.text = "%s (Owned by: %s)" % [province_data.province_name, province_data.owner.kingdom_name]
	else:
		hover_info_label.text = "%s (Unclaimed)" % province_data.province_name

	
# This function is called when the mouse LEAVES a province.
func _on_province_unhovered(province_data: Province):
	# Update the "exited" state.
	map_province_id_exited = province_data.id
	print("exited",map_province_id_exited)
	# Only reset the text if the last province we entered is the same one we just exited.
	# This means we haven't entered a new province in the meantime.
	if map_province_id_entered == map_province_id_exited:
		hover_info_label.text = DEFAULT_HOVER_TEXT
	
