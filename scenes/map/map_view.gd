extends Node2D

const ProvinceNodeScene = preload("res://scenes/map/province_node.tscn")
const MAP_LAYOUT_FILE = "res://data/map/map_layout.json"

signal province_selected(province_data)

@onready var camera = $Camera2D # Get a reference to our new camera
@onready var connection_lines_container = %ConnectionLinesContainer
var _province_nodes_by_id: Dictionary = {}
#var _line_segments: Array = []
var _line_segments_to_draw: Array = []

#mouse state vars
var _is_panning: bool = false
var _is_potential_click: bool = false
var _mouse_down_position: Vector2 = Vector2.ZERO
const DRAG_THRESHOLD = 5 # How many pixels the mouse must move to be considered a drag
const ZOOM_LEVELS = [0.25, 0.5, 0.75]

var _current_zoom_index = 1 # Start at mid-zoom (0.5)
var controller=null

var current_mode: GameManager.MapMode = GameManager.MapMode.VIEW_ONLY

var _selectable_provinces: Array[Province] = []

func setup(p_controller, mode: GameManager.MapMode, p_selectable_provinces: Array[Province]):
	self.controller = p_controller
	self.current_mode = mode
	self._selectable_provinces = p_selectable_provinces
	controller.zoom_in_pressed.connect(_on_zoom_in)
	controller.zoom_out_pressed.connect(_on_zoom_out)
	province_selected.connect(controller._on_map_province_selected)

# This is the function that kicks everything off.
func initialize_and_draw_map():
	_province_nodes_by_id.clear()
	_draw_map()
	_update_highlights()
	
# --- NEW: Handle input for panning ---
func _input(event: InputEvent):
	# --- MOUSE BUTTON PRESS ---
	var has_moved = false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.is_pressed():
			# Mouse button was just pressed down.
			# This could be the start of a pan OR a click.
			_is_potential_click = true
			_mouse_down_position = get_global_mouse_position()
		else:
			# Mouse button was just released.
			if _is_potential_click:
				# If we are still in "potential click" mode, it means the mouse
				# was never dragged far enough to start a pan. This was a click!
				# Here you would add logic to find which province was clicked.
				pass
			
			# Reset all states on mouse release.
			_is_panning = false
			_is_potential_click = false

	# --- MOUSE MOTION ---
	if event is InputEventMouseMotion:
		# Check if the left button is held down (is_action_pressed is for custom actions)
		# We check the button mask instead for direct mouse state.
		if event.button_mask == MOUSE_BUTTON_MASK_LEFT:
			if _is_panning:
				# If we are already panning, just continue to pan.
				camera.position -= event.relative / camera.zoom
				has_moved = true
			elif _is_potential_click:
				# If we are not yet panning, check if we've moved past the threshold.
				if get_global_mouse_position().distance_to(_mouse_down_position) > DRAG_THRESHOLD:
					# We've dragged far enough. This is officially a pan, not a click.
					_is_panning = true
					_is_potential_click = false

func _draw_map():
	print("MapView: _draw_map() CALLED. Using MANUAL map setup.")

	var bb_width = 4100
	var bb_height = 2500
	var precalculated_maprectx = 4100
	var precalculated_maprecty = 2500
	var screen_size = get_viewport_rect().size

	# We add padding so the map isn't touching the screen edges
	var xpadding = 100 
	var ypadding = 100 
	var scale_x = ((screen_size.x*4) - xpadding) / bb_width
	var scale_y = ((screen_size.y*4) - ypadding) / bb_height
	
	
	print("screen x:",(screen_size.x*4) - xpadding)
	print("screen y:",(screen_size.y*4) - ypadding)
	
	# We still need this dictionary to store references for the line drawing pass.
	#var province_nodes_by_id: Dictionary = {}
	# We still need this to calculate the camera limits.
	var map_rect = Rect2()

	# --- KEEP and MODIFY: The main loop ---
	# Instead of looping through JSON data, we loop through our game logic provinces.
	for province_logic in GameManager.all_provinces_in_world:
		# 1. Find the pre-placed node in our scene tree that matches the province's name.
		#    This assumes you have named your ProvinceNode instances in the editor
		#    to exactly match the province_name (e.g., "Wessex", "Mercia").
		var node_name_to_find = "province_%d" % province_logic.id
		var province_node = find_child(node_name_to_find, true, false) # Recursive, not owned
		
		if is_instance_valid(province_node):
			# --- KEEP: The setup and linking logic ---
			
			# a) Link the node to its game logic.
			province_node.setup(province_logic,self)
			province_node.update_color() # Set its initial color
			
			# b) Handle the selection mode highlighting (this logic is still needed).
			if current_mode != GameManager.MapMode.VIEW_ONLY:
				if _selectable_provinces.has(province_logic):
					province_node.highlight(true)
				else:
					province_node.highlight(false)
					province_node.set_pickable(false)
			
			# c) Store the reference for line drawing and camera limits.
			_province_nodes_by_id[province_logic.id] = province_node
			
			# d) Connect its signals to the controller.
			#province_node.province_hovered.connect(controller._on_province_hovered)
			#province_node.province_unhovered.connect(controller._on_province_unhovered)
			#province_node.province_clicked.connect(_on_province_node_clicked) # Assuming controller has this
			#
			province_node.province_hovered.connect(_on_province_node_hovered)
			province_node.province_unhovered.connect(_on_province_node_unhovered)
			province_node.province_clicked.connect(_on_province_node_clicked)
			
			# e) NEW: Calculate the map's total area from the pre-placed nodes.
			var polygon: Polygon2D = province_node.get_node("ProvincePolygon")
			
			if is_instance_valid(polygon):
				# 2. Get the polygon's array of points.
				var local_points = polygon.polygon
				
				# 3. Use our new helper function to calculate its LOCAL bounding box.
				var local_rect = _get_bounding_rect_for_polygon(local_points)
				
				# 4. Create the GLOBAL bounding rectangle by offsetting by the parent's position.
				var global_rect = Rect2(province_node.position + local_rect.position, local_rect.size)
				
				# 5. Merge this rectangle into our total map_rect.
				map_rect = map_rect.merge(global_rect)
				
		else:
				printerr("MAP SETUP WARNING: Could not find node named: '%s'" % node_name_to_find)
	
	var initial_zoom = ZOOM_LEVELS[_current_zoom_index]
	camera.zoom = Vector2(initial_zoom, initial_zoom)
	
	var map_center_x = (bb_width * scale_x) / 2.0
	var map_center_y = (bb_height * scale_y) / 2.0
	camera.position = Vector2(map_center_x, map_center_y)
	
	
	# Find the player's capital province NODE.
	var player_capital_id = GameManager.player_kingdom.capital.id
	var player_capital_node = _province_nodes_by_id.get(player_capital_id, null)
	
		# Set the camera's initial position.
	if is_instance_valid(player_capital_node):
		# If we found the capital node, center the camera on its position.
		camera.position = player_capital_node.position
	else:
		# Fallback: If we couldn't find it for some reason, center on the whole map.
		camera.position = map_rect.get_center()
	
	var cam_margin=20
	camera.limit_left = int(map_rect.position.x-cam_margin)
	camera.limit_top = int(map_rect.position.y-cam_margin)
	camera.limit_right = int(precalculated_maprectx+cam_margin)
	camera.limit_bottom = int(precalculated_maprecty+cam_margin)
	camera.force_update_scroll()
	
	# First, clear out any lines from a previous generation.
	for child in connection_lines_container.get_children():
		child.queue_free()

	for province_id in _province_nodes_by_id:
		var start_node = _province_nodes_by_id[province_id]
		var start_province_logic = start_node.province_data
		
		for neighbor_province_logic in start_province_logic.neighbors:
			if _province_nodes_by_id.has(neighbor_province_logic.id):
				var end_node = _province_nodes_by_id[neighbor_province_logic.id]
				
				# The essential check to prevent drawing each line twice.
				if start_province_logic.id < neighbor_province_logic.id:
					# --- Create and configure ONE new line ---
					var line = Line2D.new()
					line.width = 7.0
					line.default_color = Color(1, 1, 1, 0.4) # Semi-transparent white
					line.antialiased = true
					
					# Add the start and end points for this specific line.
					line.add_point(start_node.position)
					line.add_point(end_node.position)
					
					# Add the fully configured line to our container.
					connection_lines_container.add_child(line)


func _draw_map_old():
	# 1. Load and parse the layout JSON
	var content = FileAccess.get_file_as_string(MAP_LAYOUT_FILE)
	var layout_data = JSON.parse_string(content)
	var province_nodes_by_id: Dictionary = {}
	var map_rect = Rect2()
	#var map_popup_controller = get_parent().get_parent().get_parent()
	
	if not is_instance_valid(controller):
		printerr("MapView CRITICAL ERROR: _draw_map called but controller is not set!")
		return

	
	if not layout_data:
		printerr("Failed to parse map layout data!")
		return
		
	# 2. Get the bounding box to calculate scaling factors
	var bb_parts = layout_data.bb.split(",")
	var bb_width = bb_parts[2].to_float()
	var bb_height = bb_parts[3].to_float()
	
	var screen_size = get_viewport_rect().size
	# We add padding so the map isn't touching the screen edges
	var xpadding = 100 
	var ypadding = 100 
	var scale_x = ((screen_size.x*4) - xpadding) / bb_width
	var scale_y = ((screen_size.y*4) - ypadding) / bb_height
	print("screen x:",(screen_size.x*4) - xpadding)
	print("screen y:",(screen_size.y*4) - ypadding)
	
	# 3. Loop through the provinces in the layout data
	for province_layout in layout_data.objects:
		# The 'name' in this JSON is our provinceId
		var province_id = province_layout.name.to_int()
		# Find the corresponding game logic object
		var province_logic = GameManager.find_province_by_id(province_id)
		
		if not is_instance_valid(province_logic):
			print("Could not find game logic for province ID: ", province_id)
			continue
			
		# 4. Instantiate and position the node
		var instance = ProvinceNodeScene.instantiate()
		
		add_child(instance) 
		
		var pos_parts = province_layout.pos.split(",")
		var json_x = pos_parts[0].to_float()
		# In Graphviz, Y is inverted (0 is at the bottom). We flip it.
		var json_y = bb_height - pos_parts[1].to_float()
		var final_pos = Vector2(json_x * scale_x, json_y * scale_y)
		# Apply scaling
		instance.position = Vector2(json_x * scale_x, json_y * scale_y)
		
		var node_rect = Rect2(final_pos - Vector2(60, 30), Vector2(120, 60))
		map_rect = map_rect.merge(node_rect)
		# 5. Setup the node and add it to the scene
		instance.setup(province_logic)
		instance.update_color() # Set its initial color
		if current_mode != GameManager.MapMode.VIEW_ONLY:
			if _selectable_provinces.has(province_logic):
				instance.highlight(true) # A new function in province_node.gd
			else:
				instance.set_pickable(false) # Make non-selectable provinces unclickable
		
		_province_nodes_by_id[province_id] = instance
		#province_nodes_by_id[province_id] = instance
		instance.province_hovered.connect(controller._on_province_hovered)
		instance.province_unhovered.connect(controller._on_province_unhovered)
		
	var initial_zoom = ZOOM_LEVELS[_current_zoom_index]
	camera.zoom = Vector2(initial_zoom, initial_zoom)
	
	var map_center_x = (bb_width * scale_x) / 2.0
	var map_center_y = (bb_height * scale_y) / 2.0
	camera.position = Vector2(map_center_x, map_center_y)
	
	var cam_margin=20
	camera.limit_left = int(map_rect.position.x-cam_margin)
	camera.limit_top = int(map_rect.position.y-cam_margin)
	camera.limit_right = int(map_rect.end.x+cam_margin)
	camera.limit_bottom = int(map_rect.end.y+cam_margin)
	
	# First, clear out any lines from a previous generation.
	for child in connection_lines_container.get_children():
		child.queue_free()

	for province_id in province_nodes_by_id:
		var start_node = province_nodes_by_id[province_id]
		var start_province_logic = start_node.province_data
		
		for neighbor_province_logic in start_province_logic.neighbors:
			if province_nodes_by_id.has(neighbor_province_logic.id):
				var end_node = province_nodes_by_id[neighbor_province_logic.id]
				
				# The essential check to prevent drawing each line twice.
				if start_province_logic.id < neighbor_province_logic.id:
					# --- Create and configure ONE new line ---
					var line = Line2D.new()
					line.width = 7.0
					line.default_color = Color(1, 1, 1, 0.4) # Semi-transparent white
					line.antialiased = true
					
					# Add the start and end points for this specific line.
					line.add_point(start_node.position)
					line.add_point(end_node.position)
					
					# Add the fully configured line to our container.
					connection_lines_container.add_child(line)

#HELPER function to handle the click from a province node
func _on_province_node_clicked(province_data: Province):
	# If we are in selection mode, emit the signal up to the MainView.
	if current_mode != GameManager.MapMode.VIEW_ONLY:
		emit_signal("province_selected", province_data)
# The click handler also lives here now.

					
func initialize_map():
	if controller: # Make sure setup has been called
		_draw_map()
	else:
		printerr("MapView initialize_map called before setup!")


# --- NEW: The Zoom Handler Functions ---
func _on_zoom_in():
	# We pass a direction of +1 to our existing helper function.
	_update_zoom(1)

func _on_zoom_out():
	# We pass a direction of -1.
	_update_zoom(-1)
	
# The helper function for zooming.
# It no longer needs the "zoom to cursor" logic.
func _update_zoom(zoom_direction: int):
	# Calculate the new zoom index, clamping it.
	var new_index = _current_zoom_index + zoom_direction
	new_index = clampi(new_index, 0, ZOOM_LEVELS.size() - 1)
	
	if new_index == _current_zoom_index:
		return # Already at max/min zoom
		
	_current_zoom_index = new_index
	var new_zoom_value = ZOOM_LEVELS[_current_zoom_index]
	
	# Apply the new zoom. The camera will stay centered.
	camera.zoom = Vector2(new_zoom_value, new_zoom_value)

# --- NEW HELPER FUNCTION ---
# This function takes an array of Vector2 points and calculates a Rect2
# that perfectly encloses all of them. This replaces the old get_rect().
func _get_bounding_rect_for_polygon(points: PackedVector2Array) -> Rect2:
	if points.is_empty():
		return Rect2()

	# Start with the position and size of the very first point.
	var top_left = points[0]
	var bottom_right = points[0]

	# Loop through the rest of the points to find the extremes.
	for i in range(1, points.size()):
		var p = points[i]
		top_left.x = min(top_left.x, p.x)
		top_left.y = min(top_left.y, p.y)
		bottom_right.x = max(bottom_right.x, p.x)
		bottom_right.y = max(bottom_right.y, p.y)

	# The final rectangle is from the top-leftmost point to the bottom-rightmost point.
	return Rect2(top_left, bottom_right - top_left)


func _update_highlights():
	# This function is the single source of truth for what should be highlighted.
	for province_id in _province_nodes_by_id:
		var node = _province_nodes_by_id[province_id]
		var province_logic = node.province_data
		
		var should_be_highlighted = false
		var should_be_pickable = false

		if current_mode == GameManager.MapMode.VIEW_ONLY:
			# In view mode, a province is pickable. Highlighting is handled by hover.
			should_be_pickable = true
			# We don't set highlight here, hover handlers will do it.
		
		else:
			# In annex mode, a province is highlighted AND pickable ONLY if it's in our list.
			if _selectable_provinces.has(province_logic):
				should_be_highlighted = true
				should_be_pickable = true

		node.highlight(should_be_highlighted)
		node.set_pickable(should_be_pickable)


# --- NEW: Local Hover Handlers ---
func _on_province_node_hovered(province_data: Province):
	# First, pass the tooltip info up to the main popup.
	controller._on_province_hovered(province_data) # Assuming this is the new function name

	if not _province_nodes_by_id.has(province_data.id): return
	var node = _province_nodes_by_id[province_data.id]
	
	if current_mode == GameManager.MapMode.VIEW_ONLY:
		# In view mode, hovering turns the highlight ON.
		node.highlight(true)
		
	else:
		node.highlight(true, true) # Pass true for the 'is_hot' parameter


func _on_province_node_unhovered(province_data: Province):
	# Pass the tooltip info up.
	controller._on_province_unhovered(province_data)
	if not _province_nodes_by_id.has(province_data.id): return
	var node = _province_nodes_by_id[province_data.id]
	
	# Handle the visual un-highlight.
	if current_mode == GameManager.MapMode.VIEW_ONLY:
		node.highlight(false)
		
	else:
		node.highlight(true, false)
