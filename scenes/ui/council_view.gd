extends Control

# These signals will tell the MainView what's happening.
signal advisor_hovered(tooltip_text)
signal advisor_unhovered()
signal advisor_clicked(category)
signal view_census_clicked

# A dictionary to map Area2D nodes to their data.
var _advisor_areas = {}

func _ready():
	# We'll populate our dictionary for easy access.
	_advisor_areas = {
		%MilitaryAdvisorArea: {
			"category": GameEvent.EventCategory.MILITARY,
			"tooltip": "Military Advisor: Manage your army, declare wars, and seize territory."
		},
		%EconomicAdvisorArea: {
			"category": GameEvent.EventCategory.ECONOMIC,
			"tooltip": "Economic Advisor: Manage trade, tariffs, and the treasury."
		},
		%AgricultureAdvisorArea: {
			"category": GameEvent.EventCategory.AGRICULTURE,
			"tooltip": "Agriculture Advisor: Oversee farms, food production, and the peasantry."
		},
		%ManufacturingAdvisorArea: {
			"category": GameEvent.EventCategory.MANUFACTURING,
			"tooltip": "Manufacturing Advisor: Develop mines, workshops, and infrastructure."
		},
		%CultureAdvisorArea: {
			"category": GameEvent.EventCategory.CULTURE,
			"tooltip": "Culture Advisor: Foster the arts, manage public happiness, and host events."
		},
		%PersonalAdvisorArea: {
			"category": GameEvent.EventCategory.PERSONAL_GROWTH,
			"tooltip": "Personal Advisor: Focus on self-improvement, courtship, and family matters."
		},
		%KingArea: {
			"category": null,
			"tooltip": "Kingdom Census"
		}
	}
	
	# Connect the signals for every Area2D.
	for area in _advisor_areas:
		var data = _advisor_areas[area]
		area.mouse_entered.connect(_on_advisor_mouse_entered.bind(area, data.tooltip))
		area.mouse_exited.connect(_on_advisor_mouse_exited.bind(area))
		area.input_event.connect(_on_advisor_input_event.bind(data.category))
		

# This is called when a player clicks inside one of the polygons.
func _on_advisor_input_event(viewport, event, shape_idx, category):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		if category == null:
			emit_signal("view_census_clicked")
		else:
			emit_signal("advisor_clicked", category)

# These handle the hovering for the tooltip.
func _on_advisor_mouse_entered(area: Area2D, tooltip_text: String):
	# 1. Handle the tooltip (your existing logic)
	emit_signal("advisor_hovered", tooltip_text)
	
	# 2. Handle the highlight (the new logic)
	var mask_polygon = area.get_node("Polygon2D") # Assumes your visual mask is named "Polygon2D"
	if is_instance_valid(mask_polygon):
		# We set the color to a semi-transparent white to create a brightening effect.
		#mask_polygon.color = Color(1.0, 1.0, 1.0, 0.25)
		# We make sure it's visible.
		mask_polygon.visible = true

func _on_advisor_mouse_exited(area: Area2D):
	# 1. Handle the tooltip (your existing logic)
	emit_signal("advisor_unhovered")
	
	# 2. Handle the highlight (the new logic)
	var mask_polygon = area.get_node("Polygon2D")
	if is_instance_valid(mask_polygon):
		# We need to decide whether to hide the polygon completely OR
		# revert it to the dark "used" mask. We can check the 'disabled'
		# status of the collision shape to know which state it's in.
		var collision_shape = area.get_child(0)
		if collision_shape.disabled:
			# If the advisor is "used", revert the mask to the dark overlay color.
			mask_polygon.color = Color(0.0, 0.0, 0.0, 0.6)
		else:
			# If the advisor is available, hide the highlight completely.
			mask_polygon.visible = false
	
# This function will be called by MainView to disable used advisors.
func update_disabled_advisors(used_categories: Array):
	for area in _advisor_areas:
		var data = _advisor_areas[area]
		# The CollisionPolygon2D is the first child (index 0)
		var collision_shape = area.get_child(0)
		# The Polygon2D mask is the second child (index 1)
		var mask_polygon = area.get_child(1)
		
		# Check if this advisor's category has been used
		if used_categories.has(data.category):
			# Disable the clickable area
			collision_shape.disabled = true
			# Make the dark mask VISIBLE
			mask_polygon.visible = true
		else:
			# Enable the clickable area
			collision_shape.disabled = false
			# Make the dark mask INVISIBLE
			mask_polygon.visible = false
