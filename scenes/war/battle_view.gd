extends Control

enum BattleState {
	PLAYER_CHOOSE_ATTACKER,
	PLAYER_CHOOSE_DEFENDER,
	AI_TURN,
	BATTLE_OVER
}
var current_state: BattleState

# --- Preloads ---
const UnitDisplayScene = preload("res://scenes/war/unit_display.tscn")
const UnitButtonScene = preload("res://scenes/war/unit_button.tscn") # Assume this is a scene with a Button as root

# --- @onready vars ---
@onready var status_label = %StatusLabel
@onready var attacker_name_label = %AttackerName
@onready var attacker_units_container = %AttackerUnits
@onready var defender_name_label = %DefenderName
@onready var defender_units_container = %DefenderUnits

# --- State variable ---
var _player_selected_attacker: BattleUnit = null

func _ready():
	# Determine the initial state and update the UI
	_set_initial_state()

func _set_initial_state():
	var current_turn_army = BattleManager.current_turn_army
	if current_turn_army.kingdom == GameManager.player_kingdom:
		current_state = BattleState.PLAYER_CHOOSE_ATTACKER
	else:
		current_state = BattleState.AI_TURN
	
	update_ui()

# --- The Main UI Update Function ---
func update_ui():
	var player_army = BattleManager.attacker_army if BattleManager.attacker_army.kingdom == GameManager.player_kingdom else BattleManager.defender_army
	var ai_army = BattleManager.defender_army if BattleManager.attacker_army.kingdom == GameManager.player_kingdom else BattleManager.attacker_army
	
	# --- 1. Clear all containers ---
	for child in attacker_units_container.get_children():
		child.queue_free()
	for child in defender_units_container.get_children():
		child.queue_free()
		
	# --- 2. Populate the panels with unit info ---
	attacker_name_label.text = player_army.kingdom.kingdom_name
	defender_name_label.text = ai_army.kingdom.kingdom_name
	
	_populate_unit_display(attacker_units_container, player_army)
	_populate_unit_display(defender_units_container, ai_army)
	
	# --- 3. Handle the current state ---
	match current_state:
		BattleState.PLAYER_CHOOSE_ATTACKER:
			status_label.text = "Your Turn: Choose a unit to attack with."
			_create_interactive_buttons(attacker_units_container, player_army, "_on_player_choose_attacker")
			
		BattleState.PLAYER_CHOOSE_DEFENDER:
			status_label.text = "Choose a unit to target."
			_create_interactive_buttons(defender_units_container, ai_army, "_on_player_choose_defender")
			
		BattleState.AI_TURN:
			status_label.text = "Enemy is planning their move..."
			# Use a short timer to create a sense of deliberation
			var timer = get_tree().create_timer(1.5)
			await timer.timeout
			_execute_ai_turn()
			
		BattleState.BATTLE_OVER:
			# ... (logic for showing a victory/defeat panel)
			pass

# --- Helper Functions ---

# Populates a container with non-interactive unit displays
func _populate_unit_display(container, army: BattleArmy):
	for unit_type in army.units:
		var unit = army.units[unit_type]
		if unit.count > 0:
			# Assuming you have a simple scene for this
			var display = UnitDisplayScene.instantiate()
			# display.get_node("UnitName").text = BattleUnit.UnitType.keys()[unit.unit_type]
			# display.get_node("UnitCount").text = str(unit.count)
			container.add_child(display)

# Replaces static displays with clickable buttons
func _create_interactive_buttons(container, army: BattleArmy, function_to_connect: String):
	# First, clear the static displays
	for child in container.get_children():
		child.queue_free()
		
	for unit_type in army.units:
			var unit = army.units[unit_type]
			# We only create a button for units that actually exist.
			if unit.count > 0:
				# --- THE REFACTOR ---
				# 1. Instance our pre-designed scene.
				var unit_button = UnitButtonScene.instantiate()
				
				# 2. Add it to the container FIRST to avoid the @onready bug.
				container.add_child(unit_button)
				
				# 3. Call its setup function to populate it with data.
				unit_button.set_unit_data(unit)
				
				# 4. Connect its 'pressed' signal.
				unit_button.pressed.connect(Callable(self, function_to_connect).bind(unit))


# --- Signal Handlers and Turn Logic ---

func _on_player_choose_attacker(attacker_unit: BattleUnit):
	print("Player chose to attack with: ", attacker_unit.unit_type)
	_player_selected_attacker = attacker_unit
	current_state = BattleState.PLAYER_CHOOSE_DEFENDER
	update_ui()

func _on_player_choose_defender(defender_unit: BattleUnit):
	print("Player chose to target: ", defender_unit.unit_type)
	
	# We have both attacker and defender, resolve the combat
	BattleManager.resolve_combat(_player_selected_attacker, defender_unit)
	_player_selected_attacker = null # Reset for the next turn
	
	# After combat, it's the AI's turn
	current_state = BattleState.AI_TURN
	update_ui()
	
func _execute_ai_turn():
	var player_army = BattleManager.attacker_army if BattleManager.attacker_army.kingdom == GameManager.player_kingdom else BattleManager.defender_army
	var ai_army = BattleManager.defender_army if BattleManager.attacker_army.kingdom == GameManager.player_kingdom else BattleManager.attacker_army

	# Get the AI's choices from the BattleManager
	var ai_attacker = BattleManager.get_ai_attack_choice(ai_army)
	var player_defender = BattleManager.get_ai_defense_choice(player_army, ai_attacker)
	
	if not is_instance_valid(ai_attacker) or not is_instance_valid(player_defender):
		# AI has no units left, battle is over
		print("AI has no units left to attack with. Battle over.")
		current_state = BattleState.BATTLE_OVER
		update_ui()
		return
		
	# Resolve the combat
	BattleManager.resolve_combat(ai_attacker, player_defender)
	
	# After combat, it's the player's turn again
	current_state = BattleState.PLAYER_CHOOSE_ATTACKER
	update_ui()
