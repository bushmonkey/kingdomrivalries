extends CanvasLayer

@onready var panel = $PanelContainer
@onready var log_output = %LogOutput
@onready var force_war_button = %ForceWarButton
@onready var end_war_button = %EndWarButton
@onready var add_gold_button = %AddGoldButton
@onready var add_manpower_button = %AddManpowerButton
@onready var win_battle_button = %WinBattleButton
@onready var lose_battle_button = %LoseBattleButton
@onready var annex_empty_button = %AnnexEmptyButton 
@onready var kill_player_button = %KillPlayerButton 
@onready var debug_hover_button = %DebugHoverButton

var _is_hover_debugging = false

func _ready():
	panel.hide() # Start hidden
	# Connect all the buttons to their functions
	force_war_button.pressed.connect(_on_force_war_pressed)
	end_war_button.pressed.connect(_on_end_war_pressed)
	add_gold_button.pressed.connect(_on_add_gold_pressed)
	add_manpower_button.pressed.connect(_on_add_manpower_pressed)
	win_battle_button.pressed.connect(_on_win_battle_pressed)
	lose_battle_button.pressed.connect(_on_lose_battle_pressed)
	annex_empty_button.pressed.connect(_on_annex_empty_pressed)
	kill_player_button.pressed.connect(_on_kill_player_pressed)
	debug_hover_button.pressed.connect(_on_debug_hover_pressed)
	_log("Debug console ready. Press ` to toggle.")

# The tilde/backtick key (`) is the standard for opening a console.
func _process(delta):
	if Input.is_action_just_pressed("toggle_console"):
		toggle_visibility()
		
	if not _is_hover_debugging:
			return
# Get the main viewport.
	var viewport = get_viewport()
	
	# Get the mouse position relative to that viewport.
	var mouse_pos = viewport.get_mouse_position()
	
	# Get the World2D object from the viewport.
	var world_2d = viewport.get_world_2d()
	
	# If the world doesn't exist for some reason, stop.
	if not is_instance_valid(world_2d):
		return
		
	# Get the direct space state from the world.
	var space_state = world_2d.direct_space_state
	# --- END FIX ---

	var query = PhysicsPointQueryParameters2D.new()
	# Important: We need to tell the query to check for both Area and Body colliders.
	# Configure the query object's properties
	query.position = mouse_pos
	query.collide_with_areas = true
	query.collide_with_bodies = true
	
	var result = space_state.intersect_point(query)

	if not result.is_empty():
		# The result contains the collider that was hit.
		# The collider is the CollisionShape2D/CollisionPolygon2D.
		# We need its parent, the Area2D.
		var collider_node = result[0].collider
		if is_instance_valid(collider_node):
			# The Area2D is the parent of the collision shape.
			var area_node = collider_node.get_parent()
			if is_instance_valid(area_node):
				print("HOVERING OVER: %s (Path: %s)" % [area_node.name, area_node.get_path()])
				
				
func toggle_visibility():
	panel.visible = not panel.visible

func _log(message: String):
	log_output.append_text(message + "\n")
	await get_tree().process_frame
	
	var scroll_bar = log_output.get_v_scroll_bar()
	if is_instance_valid(scroll_bar):
		scroll_bar.value = scroll_bar.max_value

# --- BUTTON COMMANDS ---

func _on_force_war_pressed():
	var player = GameManager.player_kingdom
	if WarManager.is_player_at_war():
		_log("ERROR: Already at war.")
		return
	
	var neighbors = player.get_neighboring_kingdoms()
	if neighbors.is_empty():
		_log("ERROR: Player has no neighbors to declare war on.")
		return
		
	var target_kingdom = neighbors.pick_random()
	var war_goal = target_kingdom.provinces_owned.pick_random()
	
	WarManager.declare_war(player, target_kingdom, war_goal)
	_log("SUCCESS: Forced war with %s over %s." % [target_kingdom.kingdom_name, war_goal.province_name])

func _on_end_war_pressed():
	var war = WarManager.get_player_war()
	if not is_instance_valid(war):
		_log("ERROR: Player is not at war.")
		return
	
	# We'll just make the player the winner for this test
	var loser = WarManager.get_player_war_opponent()
	WarManager.enact_surrender(loser, war)
	_log("SUCCESS: Forced player victory by surrender.")

func _on_add_gold_pressed():
	GameManager.player_kingdom.treasury += 1000
	_log("SUCCESS: Added 1000 Treasury.")
	# We need to tell the main view to update its display
	get_tree().get_first_node_in_group("main_view")._update_stats_display()

func _on_add_manpower_pressed():
	GameManager.player_kingdom.manpower += 1000
	_log("SUCCESS: Added 1000 Manpower.")

func _on_win_battle_pressed():
	var war = WarManager.get_player_war()
	if not is_instance_valid(war):
		_log("ERROR: Player is not at war.")
		return
	war.war_score = clampf(war.war_score + 20, -100, 100)
	_log("SUCCESS: Increased war score by 20. New score: %.1f" % war.war_score)

func _on_lose_battle_pressed():
	var war = WarManager.get_player_war()
	if not is_instance_valid(war):
		_log("ERROR: Player is not at war.")
		return
	war.war_score = clampf(war.war_score - 20, -100, 100)
	_log("SUCCESS: Decreased war score by 20. New score: %.1f" % war.war_score)

func _on_annex_empty_pressed():
	var player = GameManager.player_kingdom
	if not is_instance_valid(player):
		_log("ERROR: Player kingdom not found.")
		return

	# 1. Find an available target.
	# We use the function we already built on the Kingdom class.
	var empty_neighbors = player.get_neighboring_unowned_provinces()
	
	if empty_neighbors.is_empty():
		_log("INFO: No empty neighboring provinces to annex.")
		return
		
	# 2. Pick one at random.
	var target_province = empty_neighbors.pick_random()
	
	# 3. Execute the annexation.
	# We use the master geopolitical update function to handle all the logic.
	GameManager.update_geopolitical_state(target_province, player)
	
	# 4. Log the success.
	_log("SUCCESS: Annexed empty province '%s'." % target_province.province_name)
	
	
func _on_debug_hover_pressed():
	_is_hover_debugging = not _is_hover_debugging
	if _is_hover_debugging:
		_log("Hover Debug ENABLED. Check output log.")
	else:
		_log("Hover Debug DISABLED.")
		
		
func _on_kill_player_pressed():
	var player_ruler = GameManager.player_kingdom.ruler
	
	if not is_instance_valid(player_ruler):
		_log("ERROR: Player ruler not found. Cannot kill.")
		return

	if not player_ruler.is_alive:
		_log("INFO: Player ruler is already dead.")
		return

	# 1. Kill the player character with a specific cause.
	player_ruler.die("Struck down by the Debug Console of Fate.")
	_log("SUCCESS: Player ruler has been killed.")
	# 2. Immediately trigger the end-of-month resolution process.
	#    because trying to run any other events with the player dead will crash the game
	var main_view = get_tree().get_first_node_in_group("main_view")
	if is_instance_valid(main_view):
		main_view.resolve_month()
		_log("INFO: Forcing end-of-month resolution to test succession...")
	else:
		_log("ERROR: Could not find MainView to force turn resolution.")
		
	# 3. Close the console and unpause the game so the events can proceed.
	toggle_visibility()
