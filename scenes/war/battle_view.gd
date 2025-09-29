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
		
	# --- 2. Populate the panels with non-interactive unit info ---
	attacker_name_label.text = player_army.kingdom.kingdom_name
	defender_name_label.text = ai_army.kingdom.kingdom_name
	
	_populate_unit_display(attacker_units_container, player_army)
	_populate_unit_display(defender_units_container, ai_army)
	
	# --- 3. NEW: The "Gatekeeper" Victory/Defeat Check ---
	# This now happens BEFORE the main state machine.
	var player_army_strength = player_army.get_total_troops()
	var ai_army_strength = ai_army.get_total_troops()
	
	if player_army_strength <= 0 or ai_army_strength <= 0:
		# If either side has no troops, the battle is over.
		# We force the state to BATTLE_OVER.
		current_state = BattleState.BATTLE_OVER
	# --- END NEW ---

	# --- 4. Handle the current state ---
	match current_state:
		BattleState.PLAYER_CHOOSE_ATTACKER:
			status_label.text = "Your Turn: Choose a unit to attack with."
			_create_interactive_buttons(attacker_units_container, player_army, "_on_player_choose_attacker")
			
		BattleState.PLAYER_CHOOSE_DEFENDER:
			status_label.text = "Choose a unit to target."
			_create_interactive_buttons(defender_units_container, ai_army, "_on_player_choose_defender")
			
		BattleState.AI_TURN:
			status_label.text = "Enemy is planning their move..."
			print("AI Turn")
			# Use call_deferred to prevent the game from freezing while it "thinks"
			call_deferred("_execute_ai_turn")
			
		BattleState.BATTLE_OVER:
			# --- NEW: The correct BATTLE_OVER logic ---
			# Determine the victor
			var victor = player_army.kingdom if player_army_strength > 0 else ai_army.kingdom
			var loser = ai_army.kingdom if player_army_strength > 0 else player_army.kingdom
			
			status_label.text = "Decisive Victory for The %s!" % victor.kingdom_name
			
			# We must clear the unit button containers to prevent further actions.
			for child in attacker_units_container.get_children():
				child.queue_free()
			for child in defender_units_container.get_children():
				child.queue_free()

			# Create a single "Return to World Map" button.
			var return_button = Button.new()
			return_button.text = "View the Aftermath"
			return_button.pressed.connect(BattleManager.conclude_battle.bind(victor, loser))
			
			# Add it to one of the main containers. Let's use the attacker's.
			attacker_units_container.add_child(return_button)
			# --- END NEW ---
		
# --- Helper Functions ---

# Populates a container with non-interactive unit displays
func _populate_unit_display(container, army: BattleArmy):
	for unit_type in army.units:
		var unit = army.units[unit_type]
		if unit.count > 0:
			# Assuming you have a simple scene for this
			var display = UnitDisplayScene.instantiate()
			container.add_child(display)
			display.set_unit_data(unit)

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
	print("AI attacking with ",ai_attacker.unit_type)
	var player_defender = BattleManager.get_ai_defense_choice(player_army, ai_attacker)
	print("AI attacking ",player_defender.unit_type)
	
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
