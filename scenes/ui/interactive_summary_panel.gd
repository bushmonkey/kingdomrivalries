extends PanelContainer

signal summary_acknowledged
signal view_census_for_kingdom(kingdom) 

@onready var kingdom_button_container = %KingdomButtonContainer
@onready var details_title_label = %DetailsTitle
@onready var details_text_label = %DetailsText
@onready var action_buttons_container = %ActionButtonsContainer
@onready var continue_button = %ContinueButton
@onready var details_scroll = %DetailsScroll
@onready var critical_events_button = %CriticalEventsButton

const CensusViewScene = preload("res://scenes/ui/census_panel.tscn")

var _chronicle: Dictionary
var _all_characters: Array[Character]
var _current_kingdom_log_view: Kingdom = null # Memory for the back button
var census_view

func _ready():
	continue_button.pressed.connect(_on_continue_button_pressed)
	critical_events_button.pressed.connect(_display_critical_events)

# This is the main entry point, called by MainView
func display_summary(chronicle: Dictionary, all_characters: Array[Character]):
	self._chronicle = chronicle
	self._all_characters = all_characters
	
	# 1. Clear previous state
	for child in kingdom_button_container.get_children():
		child.queue_free()
		
	# 2. Populate the kingdom list buttons
	# We want the player kingdom to always be at the top.
	var player_kingdom = GameManager.player_kingdom
	_create_kingdom_button(player_kingdom)
	
	for kingdom in _chronicle.kingdom_logs:
		if kingdom != player_kingdom:
			_create_kingdom_button(kingdom)
			
	# 3. Display the critical events by default.
	_display_critical_events()

# --- Helper to create the kingdom buttons ---
func _create_kingdom_button(kingdom: Kingdom):
	var button = Button.new()
	if kingdom == GameManager.player_kingdom:
		# If it is, we prepend the crown icon to the text.
		# You can copy-paste the crown emoji directly into the script.
		button.text = "👑 " + kingdom.kingdom_name
	else:
		button.text = kingdom.kingdom_name
	button.pressed.connect(_on_kingdom_button_pressed.bind(kingdom))
	kingdom_button_container.add_child(button)

# --- Display Functions for the right-hand panel ---
func _display_critical_events():
	details_title_label.text = "Season's Critical Events"
	details_text_label.clear()
	details_text_label.bbcode_enabled = true
	for child in action_buttons_container.get_children():
		child.queue_free()
	if census_view:
		census_view.hide()
		
	details_text_label.show()
	
	var critical_events = _chronicle.critical_events
	if critical_events.is_empty():
		details_text_label.append_text("- A quiet season across the realms.")
	else:
		for line in critical_events:
			details_text_label.append_text("[color=red]- %s[/color]\n" % line)

func _display_kingdom_log(kingdom: Kingdom):
	_current_kingdom_log_view = kingdom
	details_title_label.text = "Events in %s" % kingdom.kingdom_name
	if details_text_label:
		details_text_label.clear()
	
	if census_view:
		census_view.hide()
	details_text_label.show()
	
	#for child in details_scroll.get_children():
		#child.queue_free()
	for child in action_buttons_container.get_children():
		child.queue_free()
	# Add a Census button at the top of the log
	details_text_label.show()
	var census_button = Button.new()
	census_button.text = "View Census"
	
	#census_button.pressed.connect(_on_summary_census_button_pressed.bind(kingdom))
	census_button.pressed.connect(_on_view_census_button_pressed.bind(kingdom))
	action_buttons_container.add_child(census_button)
	
	#details_text_label.newline()
	
	var kingdom_log = _chronicle.kingdom_logs[kingdom]
	if kingdom_log.is_empty():
		details_text_label.append_text("- Nothing of note occurred.")
	else:
		for line in kingdom_log:
			details_text_label.append_text("- %s\n" % line)
			
func _on_summary_census_button_pressed(kingdom: Kingdom):
	emit_signal("view_census_for_kingdom", kingdom)
	

func _on_view_census_button_pressed(kingdom: Kingdom):
	#details_title_label.text = "Census for %s" % kingdom.kingdom_name
	
	# --- Clear the scroll container and action buttons ---
	#for child in details_scroll.get_children():
		#child.queue_free()
	for child in action_buttons_container.get_children():
		child.queue_free()

	# --- Hide the text label and show the census instance ---
	if details_text_label:
		details_text_label.hide() # Hide the main text display
	
	if census_view:
		census_view.show()
	else:
		census_view = CensusViewScene.instantiate()
		details_scroll.add_child(census_view)
	
	var viewport_size = get_viewport_rect().size
	census_view.custom_minimum_size = viewport_size * 0.8
	census_view.display_census_for_kingdom(kingdom)
	
	var back_button = Button.new()
	back_button.text = "Back to Kingdom Events"
	back_button.pressed.connect(_display_kingdom_log.bind(kingdom))
	action_buttons_container.add_child(back_button)
	# Listen for the back button signal from the census view.
	census_view.closed.connect(_on_census_back_button_pressed)

func _display_kingdom_census(kingdom: Kingdom):
	details_title_label.text = "Census for %s" % kingdom.kingdom_name
	#details_text_label.clear()
	
	for child in details_scroll.get_children():
		child.queue_free()
	for child in action_buttons_container.get_children():
		child.queue_free()
	
	details_text_label.hide() 
	
	var back_button = Button.new()
	back_button.text = "Back to Kingdom Events"
	back_button.pressed.connect(_display_kingdom_log.bind(kingdom))
	action_buttons_container.add_child(back_button)
	details_text_label.newline()
	
	# Filter characters for this specific court
	var courtiers = _all_characters.filter(func(c): return c.is_alive and c.current_court == kingdom)
	
	if courtiers.is_empty():
		details_text_label.append_text("- This court is empty.")
	else:
		# Use the same census formatting logic from your old summary panel
		for character in courtiers:
			# ... format and append text for character, spouse, children, etc.
			var character_string = ""
			
			# Name and Age
			var age = GameManager.current_year - character.birth_year
			character_string += "[b]%s[/b] (Age: %d)" % [character.full_name, age]
			var personality_name = Character.CharacterPersonality.keys()[character.personality]

			if kingdom.ruler==character:
				character_string += ": the [i]%s[/i]" % personality_name.to_lower()
				character_string+=" Ruler of the kingdom"
			# Spouse
			if is_instance_valid(character.spouse):
				if character.spouse.is_alive:
					character_string += " - Married to %s." % character.spouse.full_name
				else:
					character_string += " - Widow of %s." % character.spouse.full_name
			else:
				if age > 15:
					character_string += " - Unmarried."
				
			
			details_text_label.append_text(character_string + "\n")
			
			# Parents
			var parents_string = "  [i]Parents:[/i] "
			if is_instance_valid(character.father) and is_instance_valid(character.mother):
				parents_string += "%s & %s %s." % [character.father.first_name, character.mother.first_name, character.father.dynasty_name]
				details_text_label.append_text(parents_string + "\n")
			
			# Children
			var children_string = "  [i]Children:[/i] "
			if character.children.is_empty():
				children_string += "None."
			else:
				var child_names: Array[String] = []
				for child in character.children:
					# Only list living children in this section
					if child.is_alive:
						child_names.append(child.first_name)
				children_string += ", ".join(child_names)
				if child_names.is_empty(): # In case all children are dead
					children_string = "  [i]Children:[/i] None living."
			
			if age > 15:
				details_text_label.append_text(children_string + "\n")
				
				# Add a separator for readability
			details_text_label.append_text("-------------------\n")

# --- Signal Handlers ---
func _on_kingdom_button_pressed(kingdom: Kingdom):
	_display_kingdom_log(kingdom)
	
func _on_continue_button_pressed():

	emit_signal("summary_acknowledged")

func _on_census_back_button_pressed():
	# The back button was pressed, so we should return to the log view
	# for the kingdom we were last looking at.
	if is_instance_valid(_current_kingdom_log_view):
		_display_kingdom_log(_current_kingdom_log_view)
