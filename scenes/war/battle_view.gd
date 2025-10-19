extends Control

# --- State Machines ---
enum BattleState {
	PLAYER_TURN,
	AI_TURN,
	BATTLE_OVER
}
var current_state: BattleState

enum TurnPhase {
	BEGIN,           # A new phase to kick things off
	CHOOSE_ATTACKER,
	CHOOSE_DEFENDER,
	RESOLVE_COMBAT,
	SHOW_RESULTS,
	APPLY_RESULTS, 
	FINISH
}
var _current_turn_phase: TurnPhase

# --- Preloads ---
const UnitDisplayScene = preload("res://scenes/war/unit_display.tscn")
const UnitButtonScene = preload("res://scenes/war/unit_button.tscn")
const CasualtyDisplayScene = preload("res://scenes/war/casualty_display.tscn")
const CLASH_SOUND = preload("res://assets/audio/sfx/clash.mp3")

# --- @onready vars ---
@onready var status_label = %StatusLabel
@onready var attacker_name_label = %AttackerName
@onready var attacker_units_container = %AttackerUnits
@onready var defender_name_label = %DefenderName
@onready var defender_units_container = %DefenderUnits
@onready var turn_timer = %TurnTimer # The timer node from your scene
@onready var sfx_player = %SFXPlayer

# --- State variable ---
var _player_selected_attacker: BattleUnit = null
var _player_army: BattleArmy
var _ai_army: BattleArmy

func _ready():
	# Connect the timer's timeout signal ONCE at the start.
	turn_timer.timeout.connect(_on_turn_timer_timeout)
	# Determine the initial state and update the UI
	if BattleManager.attacker_army.kingdom == GameManager.player_kingdom:
		_player_army = BattleManager.attacker_army
		_ai_army = BattleManager.defender_army
	else:
		_player_army = BattleManager.defender_army
		_ai_army = BattleManager.attacker_army
	_set_initial_state()

func _set_initial_state():
	if BattleManager.current_turn_army == _player_army:
		current_state = BattleState.PLAYER_TURN
	else:
		current_state = BattleState.AI_TURN
		
	_start_new_turn()
	#update_ui()

func _start_new_turn():
	# First, always refresh the entire UI to show the current state.
	update_ui()
	
	# Now, based on the state, start the correct turn sequence.
	match current_state:
		BattleState.PLAYER_TURN:
			_current_turn_phase = TurnPhase.BEGIN
			_process_turn_phase()
		BattleState.AI_TURN:
			_current_turn_phase = TurnPhase.BEGIN
			_process_turn_phase()
		BattleState.BATTLE_OVER:
			_handle_battle_over_state() # A new helper for clarity

# --- The Main UI Update Function ---
func update_ui():

	# Clear all containers
	for child in attacker_units_container.get_children():
		child.queue_free()
	for child in defender_units_container.get_children():
		child.queue_free()
		
	# Populate the panels with non-interactive unit info
	attacker_name_label.text = _player_army.kingdom.kingdom_name
	defender_name_label.text = _ai_army.kingdom.kingdom_name
	_populate_unit_display(attacker_units_container, _player_army)
	_populate_unit_display(defender_units_container, _ai_army)
	
	# The "Gatekeeper" Victory/Defeat Check
	var player_army_strength = _player_army.get_total_troops()
	var ai_army_strength = _ai_army.get_total_troops()
	if player_army_strength <= 0 or ai_army_strength <= 0:
		current_state = BattleState.BATTLE_OVER
#
	## Handle the current state
	#match current_state:
		#BattleState.PLAYER_TURN:
			## Kick off the player's turn sequence from the beginning.
			#_current_turn_phase = TurnPhase.BEGIN
			#_process_turn_phase()
			#
		#BattleState.AI_TURN:
			## Kick off the AI's turn sequence from the beginning.
			#_current_turn_phase = TurnPhase.BEGIN
			#_process_turn_phase()
			#
		#BattleState.BATTLE_OVER:
			#var victor = _player_army.kingdom if player_army_strength > 0 else _ai_army.kingdom
			#var loser = _ai_army.kingdom if player_army_strength > 0 else _player_army.kingdom
			#status_label.text = "Decisive Victory for The %s!" % victor.kingdom_name
			#
			## Clear containers to prevent actions
			#for child in attacker_units_container.get_children(): child.queue_free()
			#for child in defender_units_container.get_children(): child.queue_free()
#
			#var return_button = Button.new()
			#return_button.text = "View the Aftermath"
			#return_button.pressed.connect(BattleManager.conclude_battle.bind(victor, loser))
			#attacker_units_container.add_child(return_button)
		
# --- Helper Functions ---

func _handle_battle_over_state():
	var player_army_strength = _player_army.get_total_troops()
	var victor = _player_army.kingdom if player_army_strength > 0 else _ai_army.kingdom
	var loser = _ai_army.kingdom if player_army_strength > 0 else _player_army.kingdom
	status_label.text = "Decisive Victory for The %s!" % victor.kingdom_name
	
	# Clear containers to prevent actions
	for child in attacker_units_container.get_children(): child.queue_free()
	for child in defender_units_container.get_children(): child.queue_free()

	var return_button = Button.new()
	return_button.text = "View the Aftermath"
	return_button.pressed.connect(BattleManager.conclude_battle.bind(victor, loser))
	attacker_units_container.add_child(return_button)

func _populate_unit_display(container, army: BattleArmy):
	for unit_type in army.units:
		var unit = army.units[unit_type]
		if unit.count > 0:
			var display = UnitDisplayScene.instantiate()
			container.add_child(display)
			display.set_unit_data(unit)

func _create_interactive_buttons(container, army: BattleArmy, function_to_connect: String):
	for child in container.get_children():
		child.queue_free()
	for unit_type in army.units:
		var unit = army.units[unit_type]
		if unit.count > 0:
			var unit_button = UnitButtonScene.instantiate()
			container.add_child(unit_button)
			unit_button.set_unit_data(unit)
			unit_button.pressed.connect(Callable(self, function_to_connect).bind(unit))

# --- Player Turn Signal Handlers ---
func _on_player_choose_attacker(attacker_unit: BattleUnit):
	_player_selected_attacker = attacker_unit
	_current_turn_phase = TurnPhase.CHOOSE_DEFENDER
	_process_turn_phase()

func _on_player_choose_defender(defender_unit: BattleUnit):
	BattleManager.player_chosen_defender = defender_unit
	_current_turn_phase = TurnPhase.RESOLVE_COMBAT
	_process_turn_phase()
	
func _execute_ai_turn():
	# This is now the entry point. It sets the phase to BEGIN.
	status_label.text = "Enemy is planning their move..."
	_current_turn_phase = TurnPhase.BEGIN
	# And it starts the very first timer.
	turn_timer.start(1.0)

func _on_turn_timer_timeout():
	# We just advance the phase and re-process.
	_current_turn_phase += 1
	_process_turn_phase()

func _process_ai_turn_phase():
	var player_army = BattleManager.attacker_army if BattleManager.attacker_army.kingdom == GameManager.player_kingdom else BattleManager.defender_army
	var ai_army = BattleManager.defender_army if BattleManager.attacker_army.kingdom == GameManager.player_kingdom else BattleManager.attacker_army

func _process_turn_phase():

	# We use the main BattleState to determine WHO is acting.
	var is_player_acting = (current_state == BattleState.PLAYER_TURN)
	
	# We use the TurnPhase to determine WHAT is happening.
	match _current_turn_phase:
		TurnPhase.BEGIN:
			if is_player_acting:
				_current_turn_phase = TurnPhase.CHOOSE_ATTACKER
				_process_turn_phase() # Immediately go to the next phase
			else: # AI is acting
				status_label.text = "Enemy is planning their move..."
				#_current_turn_phase = TurnPhase.CHOOSE_ATTACKER
				turn_timer.start(1.0) # Start the AI's "thinking" timer

		TurnPhase.CHOOSE_ATTACKER:
			if is_player_acting:
				status_label.text = "Your Turn: Choose a unit to attack with."
				_create_interactive_buttons(attacker_units_container, _player_army, "_on_player_choose_attacker")
			else: # AI is acting
				status_label.text = "Enemy is choosing an attacker..."
				var ai_attacker = BattleManager.get_ai_attack_choice(_ai_army)
				BattleManager.ai_chosen_attacker = ai_attacker
				_highlight_unit_node(_ai_army, ai_attacker.unit_type, true)
				turn_timer.start(1.5)

		TurnPhase.CHOOSE_DEFENDER:
			if is_player_acting:
				status_label.text = "Choose a unit to target."
				_create_interactive_buttons(defender_units_container, _ai_army, "_on_player_choose_defender")
			else: # AI is acting
				status_label.text = "Enemy is choosing a target..."
				var player_defender = BattleManager.get_ai_defense_choice(_player_army, BattleManager.ai_chosen_attacker)
				BattleManager.ai_chosen_defender = player_defender
				_highlight_unit_node(_player_army, player_defender.unit_type, true)
				turn_timer.start(1.5)

		TurnPhase.RESOLVE_COMBAT, TurnPhase.SHOW_RESULTS, TurnPhase.APPLY_RESULTS:
			# The logic for these phases is nearly identical for player and AI.
			# We can write a single helper function.
			_handle_combat_resolution_and_results()

		TurnPhase.FINISH:
			if is_player_acting:
				# Player's turn is over, switch to AI.
				current_state = BattleState.AI_TURN
			else: # AI's turn is over
				current_state = BattleState.PLAYER_TURN
			_start_new_turn()



func _on_ai_turn_timer_timeout() -> void:
	pass # Replace with function body.

# Finds the specific UI node for a given unit type in a given army.
func _find_unit_node(army: BattleArmy, unit_type_to_find: BattleUnit.UnitType) -> Node:
	var container_to_search = attacker_units_container if army.kingdom == GameManager.player_kingdom else defender_units_container
	
	for node in container_to_search.get_children():
		if node.unit_type == unit_type_to_find:
			return node
	return null


# Creates and positions the animated casualty display.
func _show_casualty_display(parent_node: Node, amount: int, color: Color):
	var casualty_display = CasualtyDisplayScene.instantiate()
	# Add the display as a child of the BattleView, not the unit node
	add_child(casualty_display) 
	
	# Position it over the center of the unit's UI node
	casualty_display.global_position = parent_node.global_position + (parent_node.size / 2)
	
	# Start the animation
	casualty_display.show_casualties(amount, color)
	
func _handle_combat_resolution_and_results():
	# First, determine which army is the attacker and which is the defender FOR THIS CLASH.
	# --- 1. Get clean references to the player's army and the AI's army ---
	var player_army: BattleArmy
	var ai_army: BattleArmy
	if BattleManager.attacker_army.kingdom == GameManager.player_kingdom:
		player_army = BattleManager.attacker_army
		ai_army = BattleManager.defender_army
	else:
		player_army = BattleManager.defender_army
		ai_army = BattleManager.attacker_army

	# --- 2. Determine who is the ACTING army and who is DEFENDING for this clash ---
	var is_player_acting = (current_state == BattleState.PLAYER_TURN)
	var acting_army: BattleArmy
	var defending_army: BattleArmy
	var attacker_unit: BattleUnit
	var defender_unit: BattleUnit
	
	if is_player_acting:
		# --- THE FIX ---
		# If the player is acting, the acting army is the player's army.
		acting_army = player_army
		defending_army = ai_army
		# --- END FIX ---
		attacker_unit = _player_selected_attacker
		defender_unit = BattleManager.player_chosen_defender
	else: # AI's Turn
		# --- THE FIX ---
		# If the AI is acting, the acting army is the AI's army.
		acting_army = ai_army
		defending_army = player_army
		# --- END FIX ---
		attacker_unit = BattleManager.ai_chosen_attacker
		defender_unit = BattleManager.ai_chosen_defender

		
	# Now we process the current phase.
	match _current_turn_phase:
		TurnPhase.RESOLVE_COMBAT:
			status_label.text = "CLASH!"
			
			sfx_player.stream = CLASH_SOUND
			sfx_player.play()
			
			# Store the pre-combat counts on the BattleManager.
			BattleManager.pre_combat_attacker_count = attacker_unit.count
			BattleManager.pre_combat_defender_count = defender_unit.count
			
			# Resolve the combat.
			BattleManager.resolve_combat(attacker_unit, defender_unit)
			for child in attacker_units_container.get_children():
				child.queue_free()
			for child in defender_units_container.get_children():
				child.queue_free()
			# Instantly update the static unit displays to show the new counts.
			#_populate_unit_display(attacker_units_container, acting_army)
			#_populate_unit_display(defender_units_container, defending_army)
			_populate_unit_display(attacker_units_container, _player_army)
			_populate_unit_display(defender_units_container, _ai_army)
	
			_highlight_unit_node(player_army, defender_unit.unit_type, false)
			_highlight_unit_node(ai_army, attacker_unit.unit_type, false)
			# Wait a moment for the player to register the change.
			turn_timer.start(0.75)

		TurnPhase.SHOW_RESULTS:
			# Calculate casualties.
			var attacker_casualties = BattleManager.calculated_attacker_casualties
			var defender_casualties = BattleManager.calculated_defender_casualties

			# Find the UI nodes for the units that fought.
			var attacker_node = _find_unit_node(acting_army, attacker_unit.unit_type)
			var defender_node = _find_unit_node(defending_army, defender_unit.unit_type)
			
			# Determine colors for the casualty popups.
			var acting_player_color = Color.PALE_VIOLET_RED if is_player_acting else Color.WHITE
			var defending_player_color = Color.WHITE if is_player_acting else Color.PALE_VIOLET_RED
			
			if is_instance_valid(attacker_node) and attacker_casualties > 0:
				_show_casualty_display(attacker_node, attacker_casualties, acting_player_color)
			if is_instance_valid(defender_node) and defender_casualties > 0:
				_show_casualty_display(defender_node, defender_casualties, defending_player_color)
			
			# Wait for the animation to play out.
			turn_timer.start(1.5)
			
		TurnPhase.APPLY_RESULTS: 
			attacker_unit.count = max(0, attacker_unit.count - BattleManager.calculated_attacker_casualties)
			defender_unit.count = max(0, defender_unit.count - BattleManager.calculated_defender_casualties)
			update_ui()
			turn_timer.start(1.0)
			
func _highlight_unit_node(army: BattleArmy, unit_type: BattleUnit.UnitType, is_on: bool):
	# Determine which container to search in.
	var container_to_search: Container
	if army == _player_army:
		container_to_search = attacker_units_container
	else:
		container_to_search = defender_units_container
		
	# Loop through the children (UnitDisplay nodes) in that container.
	for node in container_to_search.get_children():
		# Check if the node has the 'unit_type' property and if it matches.
		if "unit_type" in node and node.unit_type == unit_type:
			# We found the correct UI node. Call its highlight function.
			node.highlight(is_on)
			return # Stop searching
