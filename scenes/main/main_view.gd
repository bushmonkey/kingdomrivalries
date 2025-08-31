# res://scenes/main/main_view.gd
extends Control

const MapPopupScene = preload("res://scenes/map/map_popup.tscn")
const EventSelectionPanel = preload("res://scenes/ui/event_selection_panel.tscn")
const GameOverScreen = preload("res://scenes/main/game_over_screen.tscn")
const EndOfActionsPanel = preload("res://scenes/ui/end_of_actions_panel.tscn")
const InteractiveSummaryPanel = preload("res://scenes/ui/interactive_summary_panel.tscn")
const CensusPanelScene = preload("res://scenes/ui/census_panel.tscn")

# --- NEW STATE MANAGEMENT VARIABLES ---
# A dictionary to link our category enums to the actual button nodes.
var _category_buttons: Dictionary = {}
# An array to keep track of which categories have been chosen this turn.
var _used_categories_this_turn: Array = []
var _popup_container = null
var game_over_screen_instance = null

var _last_focused_node = null
var _active_main_panel: Control = null

# --- A simpler State Machine ---
enum GameState {
	AWAITING_PLAYER_ACTION, # The main hub with 6 buttons is showing
	SHOWING_DECISION,       # An event/decision panel is active
	AWAITING_RANDOM_EVENT,   # end of actions panel displayed
	SHOWING_MANDATORY_EVENT,
	RESOLUTION,              # End of month AI/summary phase
	AWAITING_INPUT,
	IN_POPUP
}

# --- Preload Scenes ---
const GenericPanel = preload("res://scenes/ui/generic_decision_panel.tscn")
const EventPanel = preload("res://scenes/ui/event_panel.tscn")
const SummaryPanel = preload("res://scenes/ui/monthly_summary_panel.tscn")
const OutcomePanelScn = preload("res://scenes/ui/outcome_panel.tscn")
const IntroPanelScn = preload("res://scenes/story/intro_panel.tscn")

# --- Onready Variables ---
@onready var date_label = %DateLabel # Using % syntax for unique nodes
@onready var gold_label = %GoldLabel
@onready var food_label = %FoodLabel
@onready var manpower_label = %ManpowerLabel
@onready var public_label = %PublicLabel
@onready var nobility_label = %NobilityLabel
@onready var church_label = %ChurchLabel
@onready var kingdom_label = %KingdomLabel
@onready var kingdom_button = %KingdomButton
@onready var stats_display = %StatsDisplay
@onready var center_stage = %CenterStage
#@onready var action_hub = %ActionHub # The new container for the 6 buttons
#@onready var actions_label = %ActionsLabel
@onready var council_view = %CouncilView # The new instanced scene
@onready var footer_tooltip = %FooterTooltip # The new label

# --- State Variables ---
var current_state: GameState
var _last_active_state: GameState
var current_panel
var actions_remaining: int = 3

func _ready():
	# For now, let's assume GameManager is ready and has a player kingdom
	# In a real game, you'd have a start menu that calls this
	GameManager.game_world_ready.connect(_on_game_world_ready)
	
	council_view.advisor_hovered.connect(_on_advisor_hovered)
	council_view.advisor_unhovered.connect(_on_advisor_unhovered)
	council_view.advisor_clicked.connect(_on_category_button_pressed)
	council_view.view_census_clicked.connect(_on_view_census_clicked)
	_active_main_panel = council_view
	
	GameManager.game_over.connect(_on_game_over)
	
	#_category_buttons = {
	#GameEvent.EventCategory.ECONOMIC: %EconButton,
	#GameEvent.EventCategory.AGRICULTURE: %AgriButton,
	#GameEvent.EventCategory.MANUFACTURING: %ManuButton,
	##GameEvent.EventCategory.SCIENCE: %SciButton,
	#GameEvent.EventCategory.MILITARY: %MilitaryButton,
	#GameEvent.EventCategory.CULTURE: %CultButton,
	#GameEvent.EventCategory.PERSONAL_GROWTH: %PersoButton
	#}
	
	#%EconButton.pressed.connect(_on_category_button_pressed.bind(GameEvent.EventCategory.ECONOMIC))
	#%AgriButton.pressed.connect(_on_category_button_pressed.bind(GameEvent.EventCategory.AGRICULTURE))
	#%ManuButton.pressed.connect(_on_category_button_pressed.bind(GameEvent.EventCategory.MANUFACTURING))
	#%SciButton.pressed.connect(_on_category_button_pressed.bind(GameEvent.EventCategory.SCIENCE))
	#%CultButton.pressed.connect(_on_category_button_pressed.bind(GameEvent.EventCategory.CULTURE))
	#%PersoButton.pressed.connect(_on_category_button_pressed.bind(GameEvent.EventCategory.PERSONAL_GROWTH))
	#
	
	## We loop through the keys (the categories)
	#for category in _category_buttons:
		## And get the value (the button) using the key
		#var button = _category_buttons[category]
		#button.pressed.connect(_on_category_button_pressed.bind(category))
	
	kingdom_button.pressed.connect(_on_kingdom_button_pressed)

	# --- Pre-instance the game over screen ---
	game_over_screen_instance = GameOverScreen.instantiate()
	add_child(game_over_screen_instance) # Add it to the scene but it starts hidden
	
	# --- FOR TESTING PURPOSES ---
	# We'll call start_new_game() from here to simulate a main menu button click.
	# In a real game, this would be in your main menu scene.
	# Using call_deferred ensures that this call happens after all nodes have finished their _ready() functions.
	GameManager.call_deferred("start_new_game", 8)

func _update_action_hub_buttons():
	# --- CORRECTED LOOP ---
	for category in _category_buttons:
		var button = _category_buttons[category]
		# Check if the category for this button is in our "used" list.
		if _used_categories_this_turn.has(category):
			button.disabled = true
		else:
			button.disabled = false
			

func _on_game_world_ready():
	print("MainView received game_world_ready signal. Starting game loop.")
	# The game world is guaranteed to exist now.
	_update_stats_display()
	
	current_panel = IntroPanelScn.instantiate()
	center_stage.add_child(current_panel)
	
	# Pass the player's kingdom data to the panel
	current_panel.display_intro(GameManager.player_kingdom)
	
	# Connect to the panel's "continue" button signal
	# When it's clicked, THEN we start the first turn.
	current_panel.intro_acknowledged.connect(_start_new_turn)
	
	#_start_new_turn()
	
func _start_game():
	# TODO: Connect to GameManager signals if needed
	kingdom_label.text = GameManager.player_kingdom.ruler.character_name
	_update_stats_display()
	_start_new_turn()
	
func _start_new_turn():
	#action_hub.show()
	actions_remaining = 3
	_used_categories_this_turn.clear()
	
	GameManager.initialize_chronicle_for_new_turn()
	
	current_state = GameState.AWAITING_PLAYER_ACTION
	_update_ui_for_state()

# --- The Core UI Update Function ---
func _update_ui_for_state():
	# Clear any existing panel
	if is_instance_valid(current_panel):
		current_panel.queue_free()
		current_panel = null
		
	match current_state:
		GameState.AWAITING_PLAYER_ACTION:
			#action_hub.show()
			#actions_label.text = "Actions Remaining: %d" % actions_remaining
			council_view.show()
			stats_display.show()
			council_view.update_disabled_advisors(_used_categories_this_turn)
			footer_tooltip.text = "Actions Remaining: %d" % actions_remaining
		# --- NEW CASE for our new state ---
		GameState.AWAITING_RANDOM_EVENT:
			# Hide the main action hub
			council_view.hide()
			stats_display.show()
			footer_tooltip.text = ""
			
			# Show our new interstitial panel
			current_panel = EndOfActionsPanel.instantiate()
			center_stage.add_child(current_panel)
			current_panel.continue_to_random_event.connect(_do_mandatory_random_event)
		_:
			council_view.hide()
			stats_display.hide()
			footer_tooltip.text = ""
			#_update_action_hub_buttons()
		#_:
			#action_hub.hide()
			
			
 #All 6 buttons connect to this one function!

# --- NEW Tooltip Handlers ---
func _on_advisor_hovered(tooltip_text):
	footer_tooltip.text = tooltip_text

func _on_advisor_unhovered():
	footer_tooltip.text = "Actions Remaining: %d" % actions_remaining

func _on_view_census_clicked():
	# This function will open the census for the PLAYER'S kingdom.
		
	current_state = GameState.IN_POPUP
	_update_ui_for_state()
	
	var census_panel = CensusPanelScene.instantiate()
	add_child(census_panel)
	# Tell the panel which kingdom to display
	census_panel.display_census_for_kingdom(GameManager.player_kingdom)
	
	# Listen for its close signal to restore the UI
	census_panel.closed.connect(_on_census_panel_closed)

func _on_summary_view_census_requested(kingdom: Kingdom):
	_open_census_popup(kingdom)

func _open_census_popup(kingdom_to_display: Kingdom):
	# If a popup is already open, don't open another one.
	if is_instance_valid(_popup_container):
		return

	var census_panel = CensusPanelScene.instantiate()
	
	# Create the popup container system (dimmer, centering)
	_popup_container = Control.new()
	_popup_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var dimmer = ColorRect.new()
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0, 0, 0, 0.5)
	_popup_container.add_child(dimmer)
	
	var centerer = CenterContainer.new()
	centerer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_popup_container.add_child(centerer)
	
	var viewport_size = get_viewport_rect().size
	census_panel.custom_minimum_size = viewport_size * 0.8
	centerer.add_child(census_panel)
	add_child(_popup_container)
	
	# Tell the panel which kingdom's data to display.
	census_panel.display_census_for_kingdom(kingdom_to_display)
	
	# Listen for its close signal to clean up.
	# We can use the same cleanup function as the map.
	census_panel.closed.connect(_on_census_panel_closed)
	
func _on_census_panel_closed():
	# Clean up the container
	if is_instance_valid(_popup_container):
		_popup_container.queue_free()
		_popup_container = null
		
	if current_state == GameState.IN_POPUP: #the census was opened from the councilview
		current_state = GameState.AWAITING_PLAYER_ACTION
		_update_ui_for_state()
	# Show the main UI again
		
func _on_category_button_pressed(category: GameEvent.EventCategory):
	_used_categories_this_turn.append(category)
	
	current_state = GameState.SHOWING_DECISION
	_last_active_state = current_state
	_update_ui_for_state()
	
	# Get a relevant event and display it
	#var prepared_event = EventManager.get_event_for_display(category)
	# --- NEW FLOW ---
	# 1. Get the list of 3 event choices from the manager.
	var event_choices = EventManager.get_event_choices_for_category(category, GameManager.player_kingdom)
		
	if event_choices.is_empty():
		# If no event is found, don't penalize the player
		print("No event found for this category, returning to hub.")
		current_state = GameState.AWAITING_PLAYER_ACTION
		_update_ui_for_state()
		return
		
	# 2. Show the new selection panel.
	current_state = GameState.SHOWING_DECISION # Or a new state like 'SELECTING_EVENT'
	_update_ui_for_state()
	
	current_panel = EventSelectionPanel.instantiate()
	center_stage.add_child(current_panel)
	current_panel.display_choices(event_choices)

	# 3. Connect to its signals.
	current_panel.event_selected.connect(_on_event_from_selection_chosen)
		
	#old behaviour
	#current_panel = EventPanel.instantiate()
	#center_stage.add_child(current_panel)
	#current_panel.display_event(prepared_event)
	#current_panel.option_chosen.connect(_on_event_choice_made)
	
# This handles the result of the player's choice

# --- NEW signal handler for when an event is CHOSEN from the popup ---
func _on_event_from_selection_chosen(event_resource: GameEvent):
	# The player has committed.
	
	# Pay the cost to select the event.
	if event_resource.selection_cost > 0:
		GameManager.player_kingdom.treasury -= event_resource.selection_cost
		_update_stats_display() # Update UI to show gold spent
	
	# --- Now, we proceed with the existing event display logic ---
	var prepared_event = EventManager.prepare_event_for_display(event_resource) # New helper needed
	
	_update_ui_for_state() # Hides the selection panel
	
	current_panel = EventPanel.instantiate()
	center_stage.add_child(current_panel)
	current_panel.display_event(prepared_event)
	current_panel.option_chosen.connect(_on_event_choice_made)

func _do_mandatory_random_event():
	#_update_ui_for_state() # Hides the outcome panel
	if is_instance_valid(current_panel):
		current_panel.queue_free()
		current_panel = null
		
	print("DEBUG: Checking for critical or random event...")
	
	var critical_event = GameManager.check_for_critical_state_events()
	
	if is_instance_valid(critical_event):
		# A critical event was found! It takes precedence.
		print("  - Critical event found: %s. Displaying it." % critical_event.event_resource.event_id)
		# We display it using our existing 'forced event' function.
		display_forced_event(critical_event)
		# We stop here. The random event is SKIPPED for this turn.
		return
	
	current_state = GameState.SHOWING_MANDATORY_EVENT
	_last_active_state = current_state # Remember what we're doing
	
	var prepared_event = EventManager.get_event_for_display(GameEvent.EventCategory.RANDOM)
			
	#var event_data = EventManager.get_random_event_of_category(GameEvent.EventCategory.RANDOM, GameManager.player_kingdom)
	if not prepared_event:
		# If there are no random events, just end the month
		resolve_month()
		return
	
	print("DEBUG: Successfully got a mandatory event: ", prepared_event.event_resource.event_id)
	
	if prepared_event.event_resource.event_id=="RD002" :
		GameManager.player_kingdom.ruler.spouse.start_pregnancy()
			
	# Re-use the event choice flow for the random event
	current_panel = EventPanel.instantiate()
	center_stage.add_child(current_panel)
	current_panel.display_event(prepared_event)
	# When this choice is made, we want to resolve the month immediately
	current_panel.option_chosen.connect(_on_event_choice_made)


# --- Resolution ---
func resolve_month():
	# This is where the world ticks forward
	_update_ui_for_state()
	print("MainView: Resolving month...")
	
	# --- 1. Advance the game state by one month ---
	# This runs all the simulation logic: economy, AI, wars, births, deaths.
	GameManager.advance_turn()
	
	# --- 2. Check for Critical Events that RESULTED from the turn's events ---
	#var critical_event = GameManager.check_for_critical_state_events()
	#
	#if is_instance_valid(critical_event):
		## If an interruption occurred, display its event and stop.
		#display_forced_event(critical_event)
	#else:
		# If there were no interruptions, proceed to the normal summary.
	_show_monthly_summary()
	

func _show_monthly_summary():
	
	if is_instance_valid(current_panel):
		current_panel.queue_free()
		current_panel = null
		
	current_panel = InteractiveSummaryPanel.instantiate()
	center_stage.add_child(current_panel)
	
	var chronicle = GameManager.monthly_chronicle
	var all_chars = GameManager.all_characters_in_world
	current_panel.display_summary(chronicle, all_chars)
	current_panel.summary_acknowledged.connect(_start_new_turn)
	current_panel.view_census_for_kingdom.connect(_on_summary_view_census_requested)
	
	#current_panel = SummaryPanel.instantiate()
	#center_stage.add_child(current_panel)
	#
	#var Monthlog = GameManager.monthly_event_log
	#var court_data = GameManager.get_characters_grouped_by_court()
	#current_panel.display_summary(Monthlog, court_data)
	#
	#current_panel.summary_acknowledged.connect(_start_new_turn)
	
	_update_stats_display()

func _on_event_choice_made(choice_package: Dictionary):
	var on_complete_callable: Callable
	
	if _last_active_state == GameState.SHOWING_MANDATORY_EVENT:
		# If it was the final event, the next step is to end the month.
		on_complete_callable = Callable(self, "resolve_month")
	else:
		# Otherwise, it was a regular action, so we process the outcome.
		on_complete_callable = Callable(self, "_on_outcome_acknowledged")
		
	# Now, call our universal handler, passing BOTH the choice data AND the "next step" function.
	_handle_event_resolution(choice_package, on_complete_callable)
	
	
	#_update_ui_for_state()
	
	
	
func _on_outcome_acknowledged():
	
	actions_remaining -= 1
	
	if actions_remaining > 0:
		# Still have actions left, return to the hub
		current_state = GameState.AWAITING_PLAYER_ACTION
		_update_ui_for_state()
	else:
		# No actions left, time for the mandatory random event
		current_state = GameState.AWAITING_RANDOM_EVENT
		_update_ui_for_state()
		#_do_mandatory_random_event()

	
func _perform_skill_check(ruler: Character, check: SkillCheck, parent_event: GameEvent) -> Dictionary:
	var result = {
		"is_success": true,
		"base_stat": 0,
		"stat_name": "N/A",
		"roll": 0,
		"personality_bonus": 0,
		"modifier_penalty": 0,
		"penalty_reason": "",
		"total_score": 0,
		"difficulty": 0,
		"tech_bonus": 0
	}
	# If there is no skill check defined, it's an automatic success
	if not is_instance_valid(check):
		return result

	result.stat_name = check.stat
	result.difficulty = check.difficulty
	result.base_stat = ruler.get(check.stat.to_lower())
	result.roll = randi_range(1, 20)
	
	# Get the relevant stat from the ruler
	var ruler_skill = ruler.get(check.stat.to_lower()) # e.g., "Stewardship" -> "stewardship"
	var ruler_kingdom = GameManager.player_kingdom
	# The "die roll": 1d20
	var roll = randi_range(1, 20)
	var personality_bonus = 0
	# --- Modifier Penalty Logic ---
	var modifier_penalty = 0
	var penalty_reason = "" 
	
	# --- Add bonus/penalty from personality ---
	# We check if the skill being tested matches the ruler's personality.
	match ruler.personality:
		Character.CharacterPersonality.FRIENDLY:
			if check.stat == "Charisma": personality_bonus = 2
			if check.stat == "Diplomacy": personality_bonus = 2
			if check.stat == "Stewardship": personality_bonus = 2
		Character.CharacterPersonality.CHARMING:
			if check.stat == "Charisma": personality_bonus = 3
			if check.stat == "Diplomacy": personality_bonus = 2
		Character.CharacterPersonality.CUNNING:
			if check.stat == "Intrigue": personality_bonus = 3
			if check.stat == "Martial": personality_bonus = 1
			if check.stat == "Stewardship": personality_bonus = 2
		Character.CharacterPersonality.STRONG:
			if check.stat == "Martial": personality_bonus = 2
			if check.stat == "Vigor": personality_bonus = 2
		Character.CharacterPersonality.WEAK:
			# A 'Weak' ruler gets a penalty on any physical or forceful check.
			if check.stat == "Martial" or check.stat == "Vigor":
				personality_bonus = -3
		Character.CharacterPersonality.STUBBORN:
			if check.stat == "Vigor": personality_bonus = 2
			if check.stat == "Diplomacy": personality_bonus = 2
		Character.CharacterPersonality.RUTHLESS:
			if check.stat == "Intrigue": personality_bonus = 2
			if check.stat == "Martial": personality_bonus = 2
			if check.stat == "Diplomacy" or check.stat == "Charisma":
				personality_bonus = -3
		Character.CharacterPersonality.WARLORD:
			if check.stat == "Martial": personality_bonus = 3
			if check.stat == "Diplomacy" or check.stat == "Stewardship":
				personality_bonus = -3
		Character.CharacterPersonality.SHY:
			# A 'Weak' ruler gets a penalty on any physical or forceful check.
			if check.stat == "Diplomacy" or check.stat == "Charisma":
				personality_bonus = -3
			if check.stat == "Stewardship": personality_bonus = 2
	
	result.personality_bonus = personality_bonus
	
	if ruler_kingdom.has_modifier("MinorInjury"):
		if check.stat == "Martial" or check.stat == "Vigor":
			modifier_penalty = -3 # A significant penalty
			penalty_reason = "Minor Injury"
			
	if ruler_kingdom.has_modifier("DiminishedAuthority"):
			if check.stat == "Diplomacy" or check.stat == "Charisma" or check.stat == "Martial":
				# We use min() so if they have both injury and this, they don't get a double penalty on Martial.
				# The harsher penalty takes precedence.
				modifier_penalty = min(modifier_penalty, -2) # A moderate penalty
				if penalty_reason.is_empty(): # Only set the reason if one isn't already set
					penalty_reason = "Diminished Authority"
					
	if parent_event.category == GameEvent.EventCategory.MANUFACTURING:
		
		# Check for the AdvancedArchitecture modifier.
		if ruler_kingdom.has_modifier("AdvancedArchitecture"):
			result.tech_bonus += 1
			
		# Check for the MinorInnovations modifier.
		# Let's assume this is a one-time use modifier.
		if ruler_kingdom.has_modifier("MinorInnovations"):
			result.tech_bonus += 1
			# Since it's one-time use, we should remove it after applying the bonus.
			ruler_kingdom.remove_modifier("MinorInnovations") # We will need to create this function
	
	result.modifier_penalty = modifier_penalty # Your calculated value
	result.penalty_reason = penalty_reason   # Your calculated reason
	
	result.total_score = result.base_stat + result.roll + result.personality_bonus + result.modifier_penalty + result.tech_bonus
	result.is_success = result.total_score >= result.difficulty
	var total_score = ruler_skill + roll + personality_bonus
	
	var print_string = "Skill Check: %s (%d) + Roll (%d)" % [check.stat, ruler_skill, roll]
	if personality_bonus != 0:
		print_string += " + Perso Bonus (%d)" % personality_bonus
	if modifier_penalty != 0:
		print_string += " + Mod Penalty (%d from %s)" % [modifier_penalty, penalty_reason]
	print_string += " = %d. Target: %d" % [total_score, check.difficulty]
	print(print_string)
	
	return result
	

func _on_summary_acknowledged():
	# The player has read the summary, start the next month's cycle
	_start_new_turn()

# --- UI Update Helper ---
func _update_stats_display():
	
	var player_k = GameManager.player_kingdom
	
	# First, we check if the player's kingdom itself is valid.
	if is_instance_valid(player_k):
		# Now, we do a SECOND, nested check to see if the RULER is valid.
		if is_instance_valid(player_k.ruler):
			kingdom_label.text = GameManager.player_kingdom.ruler.full_name
			var season_name = GameManager.get_season_name()
			date_label.text = "%s, Year %d" % [season_name, GameManager.current_year]
			if is_instance_valid(GameManager.player_kingdom):
				gold_label.text = "| Gold: %d (%s)" % [int(player_k.treasury), _format_change_string(player_k.monthly_gold_change)]
			else:
				gold_label.text = "Treasury: N/A"
			if is_instance_valid(GameManager.player_kingdom):
				food_label.text = "| Food: %d (%s)" % [player_k.food, _format_change_string(player_k.monthly_food_change)]
			else:
				food_label.text = "Food: N/A"
			if is_instance_valid(GameManager.player_kingdom):
				manpower_label.text = "| %d Manpower" % GameManager.player_kingdom.manpower
			else:
				manpower_label.text = "Manpower: N/A"
			if is_instance_valid(GameManager.player_kingdom):
				public_label.text = "| Public +%d" % GameManager.player_kingdom.public_opinion
			else:
				public_label.text = ""
			if is_instance_valid(GameManager.player_kingdom):
				nobility_label.text = "| Nobility +%d" % GameManager.player_kingdom.nobility_opinion
			else:
				manpower_label.text = ""
			if is_instance_valid(GameManager.player_kingdom):
				church_label.text = "| Church +%d" % GameManager.player_kingdom.church_opinion
			else:
				manpower_label.text = ""
		else:
			# The kingdom exists, but the ruler is dead and there's no heir yet.
			# This is our Game Over state. We should display appropriate text.
			gold_label.text = "Treasury: ---"
			food_label.text = "Food: ---"
			kingdom_button.text = "The Dynasty Ends"
			kingdom_button.disabled = true # Prevent further interaction
	else:
		# Fallback for if the entire player kingdom object is invalid.
		gold_label.text = "Treasury: N/A"
		food_label.text = "Food: N/A"
		kingdom_button.text = "No Kingdom"
		kingdom_button.disabled = true
	# --- END FIX ---
		
func _handle_event_resolution(choice_package: Dictionary, on_complete_callable: Callable):
	# Set the state to paused
	current_state = GameState.AWAITING_INPUT
	var parent_event: GameEvent = choice_package.event
	var choice_data: EventOption = choice_package.option
	var format_args: Dictionary = choice_package.format_args
	
	# Hide the event panel immediately
	if is_instance_valid(current_panel):
		current_panel.queue_free()

	# 1. Perform the Skill Check
	var player_ruler = GameManager.player_kingdom.ruler
	var roll_results = _perform_skill_check(player_ruler, choice_data.skill_check, parent_event)
	var is_success = roll_results.is_success
	#var is_success = _perform_skill_check(player_ruler, choice_data.skill_check)
	
	# --- NEW: Custom Logic for Specific Events ---
	match parent_event.event_id: # get_parent() gets the GameEvent from the EventOption
		"ML008":
			# This event has its own unique success calculation
			var calculation = _calculate_border_raid_success(choice_package.format_args)
			is_success = calculation.is_success
			roll_results = calculation.roll_results
		"ML009":
			var calculation = _calculate_border_dispute_outcome(format_args)
			is_success = calculation.is_success
			roll_results = calculation.roll_results
		"SP006": # <-- NEW CASE
			var calculation = _calculate_starvation_revolt_outcome()
			is_success = calculation.is_success
			roll_results = calculation.roll_results
		_:
			# For all other events, use the standard skill check
			var standard_calculation = _perform_skill_check(player_ruler, choice_data.skill_check, parent_event)
			is_success = standard_calculation.is_success
			roll_results = standard_calculation
	# --- 3. Determine which raw text and outcomes to use ---
	var flavor_text_template: String
	var outcomes_to_apply_raw: Array[EventOutcome]

	
	if is_instance_valid(player_ruler.spouse):
		format_args["wife_name"] = player_ruler.spouse.full_name
	if is_instance_valid(player_ruler.girlfriend):
		format_args["girlfriend_name"] = player_ruler.girlfriend.full_name
	
	if is_success:
		flavor_text_template = choice_data.success_text
		outcomes_to_apply_raw = choice_data.success_outcomes
	else:
		flavor_text_template = choice_data.failure_text
		outcomes_to_apply_raw = choice_data.failure_outcomes
		
# --- 4. Personalize the Outcomes and Flavor Text ---
	var final_flavor_text = flavor_text_template.format(format_args, "{_}")
	var final_outcomes: Array[EventOutcome] = []
	
	for raw_outcome in outcomes_to_apply_raw:
		# Create a unique copy to modify
		var final_outcome = raw_outcome.duplicate(true)
		
		
		# Check if the target is a string that needs formatting
		if final_outcome.target is String and not format_args.is_empty():
			final_outcome.target = final_outcome.target.format(format_args, "{_}")
		
		# Check if the value is a string that needs formatting
		if final_outcome.value is String and not format_args.is_empty():
			final_outcome.value = final_outcome.value.format(format_args, "{_}")
			
		final_outcomes.append(final_outcome)
		print(final_outcomes)
	# 3. Apply the mechanical effects
	GameManager.apply_outcomes(GameManager.player_kingdom, final_outcomes)
	
	
	var open_map_mode = null
	for outcome in final_outcomes:
		if outcome.type == "OpenMapForAnnex":
			open_map_mode = GameManager.MapMode.SELECT_ANNEX_TARGET
			break # Found it, no need to keep searching
		elif outcome.type == "OpenMapForClaim":
			open_map_mode = GameManager.MapMode.SELECT_CLAIM_TARGET
			break
	# Show outcome panel OR open map ---
	if open_map_mode != null:
		# Don't show an outcome panel, go directly to opening the map.
		_open_map_for_annexation(open_map_mode)
	else:
		# 4. Display the results to the player
		current_panel = OutcomePanelScn.instantiate()
		center_stage.add_child(current_panel)
		current_panel.display_outcome(is_success, flavor_text_template, final_outcomes, format_args, roll_results)
	
		# 5. Connect the "Continue" button to the function we were given
		current_panel.outcome_acknowledged.connect(on_complete_callable)
	
	# Update the top bar to reflect any changes immediately
	_update_stats_display()


# This function is called by the OpenMapForAnnex outcome.
func _open_map_for_annexation(map_mode):
	print("DEBUG: Opening map for annexation selection...")
	
	# 1. Get the list of provinces the player is allowed to select.
	var selectable_provinces: Array[Province]
	if map_mode==GameManager.MapMode.SELECT_ANNEX_TARGET:
		selectable_provinces= GameManager.player_kingdom.get_neighboring_unowned_provinces()
	else:
		selectable_provinces.append_array(GameManager.player_kingdom.get_neighboring_unowned_provinces())
	# 2. Get the owned ones from neighbors.
		var neighbors = GameManager.player_kingdom.get_neighboring_kingdoms()
		for neighbor in neighbors:
			# Don't allow targeting allies
			if GameManager.player_kingdom.allies.has(neighbor.id):
				continue
			var border_provinces = GameManager.get_border_provinces(neighbor, GameManager.player_kingdom)
			for province in border_provinces:
				# Don't allow targeting capitals
				if province != neighbor.capital:
					selectable_provinces.append(province)
					
	# 2. Instance the popup scene.
	var map_popup = MapPopupScene.instantiate()
	add_child(map_popup)
	map_popup.setup(map_mode, selectable_provinces)

	
	# 3. Tell the MapView to start in "SELECT_ANNEX_TARGET" mode.
	#var map_view = map_popup.get_node("...") # Get the map_view node
	#map_view.setup(map_popup, GameManager.MapMode.SELECT_ANNEX_TARGET, selectable_provinces)
	#map_view.initialize_map() # This now happens after setup
	
	# 4. Listen for the map's selection signal (we need to create this).
	#map_view.province_selected.connect(_on_annex_target_selected)
	# Also listen for the close button.
	map_popup.province_selected.connect(_on_annex_target_selected)
	map_popup.closed.connect(_on_annex_selection_cancelled)

func _on_annex_selection_cancelled():
	# If the player closes the map without choosing, the action is wasted.
	actions_remaining -= 1
	# ... (proceed to next state)

# This is called when the player clicks a valid province on the map.
func _on_annex_target_selected(province: Province):
	# The player has made their choice!
	if is_instance_valid(_popup_container):
		_popup_container.queue_free()
		_popup_container = null
	# Now we can trigger the actual annexation event.
	
	var event_id_to_trigger: String
	
# Check if the selected province has an owner.
	if is_instance_valid(province.owner):
		# It's owned! We need to trigger the Border Dispute.
		event_id_to_trigger = "INTERNAL_EXECUTE_BORDER_DISPUTE"
	else:
		# It's empty! We trigger the peaceful Annexation.
		event_id_to_trigger = "INTERNAL_EXECUTE_ANNEXATION"
	# We need to prepare it with the province they clicked on.
	
	var event_resource = EventManager.get_event_by_id(event_id_to_trigger)
	var context = {"target_province": province}
	print("annexed selected province:",province.id)
	var prepared_event = EventManager.prepare_event_for_display(event_resource, context)
	
	_update_ui_for_state() # Hides the map
	
	current_panel = EventPanel.instantiate()
	center_stage.add_child(current_panel)
	current_panel.display_event(prepared_event)
	current_panel.option_chosen.connect(_on_event_choice_made)
	
	
#HELPER FUNCTION for the Starvation Revolt ---
func _calculate_starvation_revolt_outcome() -> Dictionary:
	var player = GameManager.player_kingdom.ruler
	
	# The "attack" strength is the ruler's martial skill + half their manpower (representing the garrison)
	var defense_score = player.martial + (GameManager.player_kingdom.manpower / 2.0)
	
	# The "defense" strength is the mob's anger, driven by negative public opinion.
	var public_opinion = GameManager.player_kingdom.public_opinion 
	var revolt_strength = 100 - (public_opinion * 2) # The lower the opinion, the stronger the revolt
	
	# Add randomness
	defense_score += randi_range(0, 25)
	revolt_strength += randi_range(10, 40)
	
	var is_success = defense_score >= revolt_strength
	
	var roll_results = {
		"is_custom": true,
		"breakdown": "Your Garrison's Strength (%d) vs. The Mob's Fury (%d)" % [defense_score, revolt_strength],
		"success_chance_text": "Garrison: %d | Mob: %d. %s" % [defense_score, revolt_strength, "YOU SURVIVED" if is_success else "YOU ARE OVERTHROWN"]
	}
	
	return {"is_success": is_success, "roll_results": roll_results}
	
# --- NEW HELPER FUNCTION FOR THE BORDER RAID ---
func _calculate_border_raid_success(format_args: Dictionary) -> Dictionary:
	var player = GameManager.player_kingdom
	var enemy_id = format_args.get("enemy_kingdom_id")
	var enemy = GameManager.find_kingdom_by_id(enemy_id)
	
	if not is_instance_valid(enemy):
		return {"is_success": false, "roll_results": {}} # Failsafe

	# 1. Base chance from manpower difference
	var manpower_advantage = player.manpower - enemy.manpower
	# Let's say every 100 manpower difference is a 1% chance change.
	var base_chance = 50 + (manpower_advantage / 100.0)
	
	# 2. Add randomness
	var random_factor = randi_range(-15, 15)
	
	# 3. Add personality modifier
	var personality_bonus = 0
	match player.ruler.personality:
		Character.CharacterPersonality.WARLORD, Character.CharacterPersonality.STRONG:
			personality_bonus = 10
		Character.CharacterPersonality.RUTHLESS, Character.CharacterPersonality.CUNNING:
			personality_bonus = 5
		Character.CharacterPersonality.WEAK, Character.CharacterPersonality.SHY:
			personality_bonus = -15
			
	# 4. Calculate final success chance and roll
	var final_chance = clampi(base_chance + random_factor + personality_bonus, 5, 95)
	var roll = randi_range(1, 100)
	var is_success = roll <= final_chance
	
	# 5. Build the results dictionary for the outcome panel to display
	var roll_results = {
		"is_custom": true, # A flag for the outcome panel
		"breakdown": "Manpower Advantage: %d%% | Random Factor: %d%% | Personality: %d%%" % [int(manpower_advantage / 100.0), random_factor, personality_bonus],
		"total_score": int(final_chance),
		"difficulty": roll, # We display the roll as the "difficulty" to beat
		"success_chance_text": "Success Chance: %d%%. You rolled %d." % [int(final_chance), roll]
	}
	
	return {"is_success": is_success, "roll_results": roll_results}
	
	
# --- NEW FUNCTION for special events ---
func display_forced_event(event_data: PreparedEvent):
	current_state = GameState.AWAITING_INPUT
	_update_ui_for_state()
	
	current_panel = EventPanel.instantiate()
	center_stage.add_child(current_panel)
	current_panel.display_event(event_data)
	current_panel.option_chosen.connect(_on_forced_event_choice_made)


# --- NEW Signal Handler for the forced event's outcome ---
# This is the signal handler that is connected to the EventPanel
# when a "forced" event (like bankruptcy or victory) is displayed.
func _on_forced_event_choice_made(choice_package: Dictionary):
	# 1. Unpack the data we need from the package.
	var parent_event: GameEvent = choice_package.event
	var choice_data: EventOption = choice_package.option
	# We don't need format_args here, as forced events are simpler.

	# 2. Hide the main event panel.
	_update_ui_for_state()
	
	# 3. Determine the "next step" based on the event's ID.
	#    This is the function that will be called when the player clicks "Continue"
	#    on the outcome panel.
	var on_complete_callable: Callable
	
	match parent_event.event_id:
		"SP001","SP006":
			# For these game-ending events, the next step is to try and find an heir.
			on_complete_callable = Callable(self, "_execute_overthrow_and_succession")
			
		"SP003","SP004","SP002":
			# For a simple victory, we just apply the outcome and then show the summary.
			# So the next step is to show the monthly summary.
			on_complete_callable = Callable(self, "_show_monthly_summary")
		
		"SP005":
			on_complete_callable = Callable(self, "_execute_succession_flow")
		_: # A fallback for any other future forced events
			printerr("Unknown forced event ID: ", parent_event.event_id)
			on_complete_callable = Callable(self, "_show_monthly_summary")

	# 4. Apply the mechanical outcomes of the choice.
	#    Even for forced events, we should run this in case there are outcomes.
	#    For the victory event, this is where the `EndWarBySurrender` outcome is processed.
	#    We use a simplified version of _handle_event_resolution's logic.
	
	# We assume forced events are always "successful" in their outcome.
	var outcomes_to_apply = choice_data.success_outcomes
	GameManager.apply_outcomes(GameManager.player_kingdom, outcomes_to_apply)

	# 5. Display the outcome panel to the player.
	var flavor_text = choice_data.success_text
	var empty_outcomes_for_display: Array[EventOutcome] = [] # We don't need to re-display mechanics

	current_panel = OutcomePanelScn.instantiate()
	center_stage.add_child(current_panel)
	
	# We can use the event ID to decide if the outcome is "good" (Success) or "bad" (Failure).
	var is_success_display = (parent_event.event_id == "SP004")
	
	# The format_args dictionary should be passed, but it can be empty for these events.
	current_panel.display_outcome(is_success_display, flavor_text, empty_outcomes_for_display, {}, {})
	
	# 6. Connect the "Continue" button to the "next step" function we determined earlier.
	current_panel.outcome_acknowledged.connect(on_complete_callable)


# --- NEW: The function that handles the actual game state change ---
func _execute_overthrow_and_succession():
	var ruler_to_die = GameManager.player_kingdom.ruler
	if is_instance_valid(ruler_to_die):
		# The cause of death is now logged from here
		ruler_to_die.die("Executed by rebellious nobles after the kingdom's bankruptcy.")
	
	# The existing succession logic will now be triggered automatically
	# by the _update_monthly_state check for dead rulers.
	# To be safe, we can call it directly.
	var succession_was_successful = GameManager._handle_succession(GameManager.player_kingdom)
	
	if succession_was_successful:
		# --- Case 1: NOT Game Over ---
		# The heir or spouse took over. We should now show the monthly summary.
		print("Succession successful. Proceeding to monthly summary.")
		_show_monthly_summary()
	else:
		# --- Case 2: Game Over ---
		# Succession failed. The _handle_succession function has already emitted
		# the 'game_over' signal. Our _on_game_over handler will take care of
		# displaying the correct screen. We don't need to do anything else here.
		print("Succession failed. Game over sequence initiated.")
	
func _on_kingdom_button_pressed():
	if is_instance_valid(_popup_container): return

	# We must explicitly HIDE the council view before opening the map.
	# The _active_main_panel variable should be pointing to it.
	current_state = GameState.IN_POPUP
	_update_ui_for_state()
	
	# Instance the popup scene
	var map_popup = MapPopupScene.instantiate()
	add_child(map_popup)
	
	var empty_provinces: Array[Province] = []
	map_popup.setup(GameManager.MapMode.VIEW_ONLY, empty_provinces)
	# Add it as a child of MainView. It will appear on top of everything.

	
	# Connect to the popup's "closed" signal
	map_popup.closed.connect(_on_map_popup_closed)
	
	
	
func _on_map_popup_closed():
	# We must SHOW the council view again to return to the game.
	current_state = GameState.AWAITING_PLAYER_ACTION
	_update_ui_for_state()
		
# --- NEW HELPER to format the (+10) or (-20) string ---
func _format_change_string(value) -> String:
	if value >= 0:
		return "+%d" % value
	else:
		return "%d" % value # The value is already negative
		
# --- NEW HELPER FUNCTION for the Border Dispute ---
func _calculate_border_dispute_outcome(format_args: Dictionary) -> Dictionary:
	var player = GameManager.player_kingdom
	var target_kingdom = GameManager.find_kingdom_by_id(format_args.get("target_kingdom_id"))

	# 1. Base chance on Manpower difference (major factor)
	var manpower_advantage = player.manpower - target_kingdom.manpower
	var manpower_chance = clampi(manpower_advantage / 100.0, -20, 40) # Capped effect
	
	# 2. Modify chance based on Kingdom Relations (major factor)
	var relations = player.relations.get(target_kingdom.id, 0)
	# If relations are good, they are less likely to cede land peacefully.
	# If relations are terrible, they might cede it just to avoid a war they can't win.
	var relations_chance = clampi(relations / -5.0, -15, 15)
	
	# 3. Add randomness
	var random_factor = randi_range(0, 30)
	
	# 4. Calculate the "Target's Will to Resist"
	# This is the number we need to beat.
	var resistance_target = 50 - manpower_chance - relations_chance
	
	# 5. The "Roll" is our diplomacy and charisma.
	var player_roll = player.ruler.diplomacy + player.ruler.charisma + random_factor
	var is_success = player_roll >= resistance_target
	
	# 6. Build the results dictionary for display
	var roll_results = {
		"is_custom": true,
		"breakdown": "Your Diplomatic Pressure (%d) vs. Their Will to Resist (%d)" % [player_roll, resistance_target],
		"success_chance_text": "Your Pressure: %d | Target: %d. %s" % [player_roll, resistance_target, "SUCCESS" if is_success else "FAILURE"]
	}
	
	return {"is_success": is_success, "roll_results": roll_results}
	
# --- NEW signal handler for game over ---
func _on_game_over(summary_data: Dictionary):
	# Hide all other UI
	if is_instance_valid(current_panel):
		current_panel.queue_free()
#	action_hub.hide()
	stats_display.hide()
	footer_tooltip.hide()
	
	# Display the game over screen with the data
	game_over_screen_instance.display_summary(summary_data)
	
func _execute_succession_flow():
	var succession_was_successful = GameManager._handle_succession(GameManager.player_kingdom)
	
	if succession_was_successful:
		# NOT Game Over. Show the summary for the new ruler.
		_show_monthly_summary()
	else:
		# Game Over. The _handle_succession function has already emitted the
		# game_over signal. The _on_game_over handler will display the screen.
		pass
