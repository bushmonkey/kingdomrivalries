class_name PreparedEvent
extends Node

var event_resource: GameEvent
var format_args: Dictionary

# A path to the folder containing all your event resources.
const EVENTS_PATH = "res://data/events/"

var all_events: Array[GameEvent] = []
var _events_by_id: Dictionary = {}
var _event_cooldown_tracker: Dictionary = {}

func _ready():
	load_all_events()

func reset_event_state():
	_event_cooldown_tracker.clear()
	
func load_all_events():
	all_events.clear()
	_events_by_id.clear()
	var dir = DirAccess.open(EVENTS_PATH)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			# We only want to load .tres files (Godot's text resource format).
			if not dir.current_is_dir() and not file_name.begins_with("."):
				var resource_path_to_load = ""
				# Check if it's a remapped resource (from an exported build)
				if file_name.ends_with(".remap"):
					resource_path_to_load = EVENTS_PATH + file_name.get_basename()
				elif file_name.ends_with(".tres"):
					resource_path_to_load = EVENTS_PATH + file_name
					
				if not resource_path_to_load.is_empty():
					var event_resource = load(resource_path_to_load)
					
				#A final safety check to make sure we only add GameEvents
					if event_resource is GameEvent:
						all_events.append(event_resource)
						_events_by_id[event_resource.event_id] = event_resource
					else:
						printerr("Found a resource that was not a GameEvent: ", resource_path_to_load)	
					
			file_name = dir.get_next()
		
		print("Successfully loaded %d event resources." % all_events.size())
	else:
		printerr("Could not open events directory at: ", EVENTS_PATH)


# The function signature changes slightly. It now returns a GameEvent object.
func get_random_event_for(kingdom: Kingdom) -> GameEvent:
	if all_events.is_empty(): 
		# It's good practice to have a default/fallback event
		printerr("No events loaded!")
		return null 
	
	return all_events.pick_random()
	
func get_random_event_of_category(event_category: GameEvent.EventCategory, kingdom: Kingdom) -> GameEvent:
	# Filter the master list to get only events of the desired category
	# 1. First, filter by the requested category.
	var category_events = all_events.filter(func(e): return e.category == event_category)
	
	# 2. --- NEW: Second, filter that list by our validator function. ---
	var valid_events = category_events.filter(func(e): return _is_event_valid_for_kingdom(e, kingdom))

	
	if valid_events.is_empty():
		printerr("No events found for category: ", GameEvent.EventCategory.keys()[event_category])
		# Return a fallback "do nothing" event here if you create one
		return null
		
	return valid_events.pick_random()
	
#func _prepare_PG001_eligible_ladies_list(event_courtship_ball_resource):
	#var event_courtship_ball_option_template: EventOption = load("res://data/eventoptiontemplate/pg001_eligible_lady.tres")
	#var eligible_ladies = GameManager.get_eligible_courting_targets(GameManager.player_kingdom.ruler)
## 2. Check if there are any candidates
	#if eligible_ladies.is_empty():
		## Cannot fire the event, maybe choose a different one
		#print("no ladies")
		#return null
#
	## 3. Create a temporary, modified copy of the event resource
	#var temp_event = event_courtship_ball_resource.duplicate(true)
	#print("copying...")
	#temp_event.options.clear()
#
	## 4. Loop through the candidates and create dynamic options
	#for lady in eligible_ladies:
		#var option_template = event_courtship_ball_option_template.duplicate(true)
		#
		## Format the text with the lady's name
		#option_template.text = option_template.text.format({"lady_name": lady.full_name})
		#option_template.text = option_template.text.format({"lady_personality": lady.CharacterPersonality.keys()[lady.personality].to_lower()})
		#option_template.success_text = option_template.success_text.format({"lady_name": lady.full_name})
		#option_template.failure_text=option_template.failure_text.format({"lady_name": lady.full_name})
		#option_template.skill_check.stat=option_template.skill_check.stat
		#
		#
		## Set the target of the outcomes to this specific lady's ID
		#for outcome in option_template.success_outcomes:
			#if outcome.target == "{lady_id}":
				#outcome.target = lady.id # Assuming characters have a unique ID property
		#
		#for outcome in option_template.failure_outcomes:
			#if outcome.target == "{lady_id}":
				#outcome.target = lady.id # Assuming characters have a unique ID property
				#
		#temp_event.options.append(option_template)
	## 5. Add the static options ("mingle" and "cancel") back to the list
	## ...
#
	## 6. Return the fully formed 'temp_event'
	#return temp_event
	
func get_event_by_id(event_id: String) -> GameEvent:
	# Check if the ID is valid and exists in our dictionary.
	if not event_id.is_empty() and _events_by_id.has(event_id):
		# Return the event object directly from the dictionary. This is extremely fast.
		return _events_by_id[event_id]
	
	# If the ID was not found, print an error and return null.
	printerr("Could not find event with ID: ", event_id)
	return null
	
	
func _is_event_valid_for_kingdom(event: GameEvent, kingdom: Kingdom) -> bool:
	
	#custom checks first:
	if event.event_id == "ML009":
		var target_province = _find_weakest_neighbor_province()
		if is_instance_valid(target_province):
			print('ML009 is valid, trying for ',target_province.province_name)
			_prepare_border_dispute_event(event_resource, target_province)
		else:
			print('ML009 not valid')
			return false
			
	if event.event_id == "ML015":
		var squire=_find_squire_for_knighting()
		if !is_instance_valid(squire):
			print('ML015 not valid')
			return false
	# If an event has no conditions defined, it's always valid.
	if not is_instance_valid(event.trigger_conditions):
		return true
	
	var conditions = event.trigger_conditions

	# CHECK for Cooldown
	if event.cooldown_years > 0:
		# Check if this event is in our cooldown tracker.
		if _event_cooldown_tracker.has(event.event_id):
			var last_fired_year = _event_cooldown_tracker[event.event_id]
			var current_year = GameManager.current_year
			
			# If the cooldown period has NOT passed yet, the event is invalid.
			if current_year < (last_fired_year + event.cooldown_years):
				return false # Condition fails
				
	# CHECK for season
	#    We use a pow(2, season_index) to get 1, 2, 4, or 8.
	var current_season_flag = 1 << GameManager.current_season 
	# Same as pow(2, GameManager.current_season)
	if (conditions.allowed_seasons & current_season_flag) == 0:
		return false
	
	var ruler = kingdom.ruler

	# --- Perform all checks. If any check fails, we return false immediately. ---
	
	if conditions.requires_player_is_married and not is_instance_valid(ruler.spouse):
		return false
	
	if conditions.requires_player_is_unmarried and is_instance_valid(ruler.spouse):
		return false
	
	if conditions.requires_player_has_heir:
		if ruler.children.is_empty():
			return false
			
	# Assuming you have a 'courting_target' variable on your Character class
	if conditions.requires_player_is_courting and not ruler.is_courting:
		return false
	if conditions.requires_player_is_not_courting and ruler.is_courting:
		return false
	if conditions.requires_spouse_is_not_pregnant:
			# First, we need to make sure the ruler actually has a spouse.
			if not is_instance_valid(ruler.spouse):
				# If they don't have a spouse, they can't have a pregnant spouse, so this condition is met.
				# This might seem counter-intuitive, but it prevents the event from being blocked
				# just because the player is unmarried. The 'requires_player_is_married'
				# trigger would handle that case separately if needed.
				pass # Condition is technically met, continue checks.
			else:
				# The ruler has a spouse, so now we check if she is pregnant.
				# We're assuming your Character class has an 'is_pregnant' boolean property.
				if ruler.spouse.is_pregnant:
					# The spouse IS pregnant, but the condition requires them NOT to be.
					# Therefore, the condition fails.
					return false
	if kingdom.treasury < conditions.min_gold:
		return false
	if conditions.requires_friendly_rival:
		if GameManager.find_kingdom_by_relationship(GameManager.TargetRelationshipType.FRIENDLY_NON_ALLY)==null:
			return false
	if conditions.requires_unfriendly_rival:
		if GameManager.find_kingdom_by_relationship(GameManager.TargetRelationshipType.UNFRIENDLY_NON_RIVAL)==null:
			return false
					
	var is_at_war = WarManager.is_player_at_war()
	if conditions.requires_is_at_war and not is_at_war:
		return false
	if conditions.requires_is_at_peace and is_at_war:
		return false
	if conditions.requires_empty_neighboring_province:
		var unowned_lands = kingdom.get_neighboring_unowned_provinces()
		if unowned_lands.is_empty():
			return false
	
	if conditions.requires_coastal_province:
		var has_coast = false
		# Loop through all of the kingdom's provinces
		for province in kingdom.provinces_owned:
			if province.is_coastal:
				# We found at least one coastal province, so the condition is met.
				has_coast = true
				break # Stop searching for efficiency.
					
		# If the loop finished and we never found a coastal province, the condition fails.
		if not has_coast:
			return false
			
	if conditions.max_nobility_opinion<kingdom.nobility_opinion:
		return false
	return true
	
	
	if conditions.requires_valid_trade_partner:
			# We just need to know if a partner EXISTS. We don't need to store it here.
			var partner = _find_valid_trade_partner()
			if not is_instance_valid(partner):
				# If no valid partner was found, the trigger fails.
				return false

func prepare_event_for_display(event_resource: GameEvent, context: Dictionary = {}) -> PreparedEvent:
	# 1. Create the formatting arguments for this specific event.
	var format_args = _get_contextual_format_args_for_event(event_resource)
	
		# This allows us to handle one-off data for specific events.
	if not context.is_empty():
		for key in context:
			format_args[key] = context[key]
			
	# Now, we use the data from the context to populate the placeholders.
	if context.has("dead_ruler"):
		var dead_ruler: Character = context.dead_ruler
		format_args["player_ruler_name"] = dead_ruler.full_name
		format_args["cause_of_death"] = dead_ruler.cause_of_death
	
	if context.has("target_province"):
		var province: Province = context.target_province
		format_args["target_province_name"] = province.province_name
		# This is crucial for the AddProvince outcome later!
		format_args["target_province_id"] = province.id 
		
	# 2. Package the resource and its arguments together.
	var prepared_event = PreparedEvent.new()
	prepared_event.event_resource = event_resource
	prepared_event.format_args = format_args
	
	if event_resource.cooldown_years > 0:
		_event_cooldown_tracker[event_resource.event_id] = GameManager.current_year
		print("EVENT COOLDOWN: '%s' is now on cooldown until year %d." % [event_resource.event_id, GameManager.current_year + event_resource.cooldown_years])
	
	# 3. Return the complete package, ready for the UI.
	return prepared_event
	

func get_event_for_display(category: GameEvent.EventCategory) -> PreparedEvent:
		
	var event_resource = get_random_event_of_category(category, GameManager.player_kingdom)
	if not event_resource: return null
	
	# Check for Storyline Events First ---
	# We only check for storyline events when it's the mandatory random event phase.
	if category == GameEvent.EventCategory.RANDOM:
		var storyline_event = _get_active_storyline_event()
		if is_instance_valid(storyline_event):
			# A storyline event takes precedence over all other random events!
			return prepare_event_for_display(storyline_event)
		
	# 2. Prepare the formatting arguments
	var format_args = _get_contextual_format_args_for_event(event_resource)
	
	# 3. Create the prepared event object
	var prepared_event = PreparedEvent.new()
	prepared_event.event_resource = event_resource
	prepared_event.format_args = format_args
	
	# 4. Return the complete package
	return prepared_event

# --- HELPER to find a valid storyline event ---
func _get_active_storyline_event() -> GameEvent:
	for storyline_id in GameManager.active_storylines:
		var stage = GameManager.active_storylines[storyline_id]
		
		# Construct the event ID we are looking for, e.g., "SERPENT_S1"
		var event_id_to_find = "%s_S%d" % [storyline_id, stage]
		print ('checking for:',event_id_to_find)
		
		if event_id_to_find=="SERPENT_S0":
		#this is a special story beat that happens immediatly on first turn
			var event = get_event_by_id(event_id_to_find)
			if is_instance_valid(event) and _is_event_valid_for_kingdom(event, GameManager.player_kingdom):
				return event
		if randf() < 0.20: # 20% chance per season to advance the story
			var event = get_event_by_id(event_id_to_find)
			if is_instance_valid(event) and _is_event_valid_for_kingdom(event, GameManager.player_kingdom):
				return event
				
	return null
	
func _get_contextual_format_args_for_event(event: GameEvent) -> Dictionary:
	var format_args = {}
	var player_kingdom = GameManager.player_kingdom
	var player_ruler = GameManager.player_kingdom.ruler
	
	var friendly_kingdom=GameManager.find_kingdom_by_relationship(GameManager.TargetRelationshipType.FRIENDLY_NON_ALLY)
	var unfriendly_kingdom=GameManager.find_kingdom_by_relationship(GameManager.TargetRelationshipType.UNFRIENDLY_NON_RIVAL)
	var empty_neighboring_provinces=GameManager.player_kingdom.get_neighboring_unowned_provinces()
	var owned_provinces=GameManager.get_owned_provinces(GameManager.player_kingdom)
	var trade_partner = _find_valid_trade_partner()
	var empty_neighboring_province=empty_neighboring_provinces.pick_random()
	var owned_province=owned_provinces.pick_random()
	var squire: Character=_find_squire_for_knighting()
	var unowned_lands = GameManager.player_kingdom.get_neighboring_unowned_provinces()
	var weak_province = _find_weakest_neighbor_province()
	var weak_province_kingdom = weak_province.owner if is_instance_valid(weak_province) else null
	
	print('DEBUG: owned province selected: %s' % owned_province.province_name)
	if is_instance_valid(player_ruler.spouse):
		format_args["wife_name"] = player_ruler.spouse.full_name
		format_args["wife_id"] = player_ruler.spouse.id
	if is_instance_valid(player_ruler.girlfriend):
		format_args["girlfriend_name"] = player_ruler.girlfriend.full_name
		format_args["girlfriend_id"] = player_ruler.girlfriend.id
	
	if not player_ruler.children.is_empty():
		var heir = player_ruler.children[0] # Simplistic heir selection
		format_args["heir_name"] = heir.first_name
	
	if friendly_kingdom != null:
		format_args["friendly_kingdom_name"] = friendly_kingdom.kingdom_name
		format_args["friendly_ruler_name"] = friendly_kingdom.ruler.full_name
		format_args["friendly_ruler_id"] = friendly_kingdom.ruler.id
		format_args["friendly_kingdom_id"] = friendly_kingdom.id
	
	if unfriendly_kingdom != null:
		format_args["unfriendly_kingdom_name"] = unfriendly_kingdom.kingdom_name
		format_args["unfriendly_ruler_name"] = unfriendly_kingdom.ruler.full_name
		format_args["unfriendly_kingdom_id"] = unfriendly_kingdom.id
		format_args["unfriendly_ruler_id"] = unfriendly_kingdom.ruler.id
	
	if is_instance_valid(trade_partner):
				format_args["trade_partner_kingdom_name"] = trade_partner.kingdom_name
				format_args["trade_partner_ruler_name"] = trade_partner.ruler.full_name
				format_args["trade_partner_kingdom_id"] = trade_partner.id
				
	if empty_neighboring_province !=null:
		format_args["empty_province_name"] = empty_neighboring_province.province_name

	if is_instance_valid(squire):
		format_args["squire_name"] = squire.full_name
		format_args["squire_id"] = squire.id
		
	if is_instance_valid(weak_province):
		format_args["weak_neighbor_province_name"] =weak_province.province_name
		format_args["weak_neighbor_province_id"]= weak_province.id
		format_args["weak_neighbor_kingdom_name"]= weak_province_kingdom.kingdom_name
		format_args["weak_neighbor_kingdom_id"]= weak_province_kingdom.id
		format_args["weak_neighbor_ruler_name"]= weak_province_kingdom.ruler.full_name
				
	if WarManager.is_player_at_war():
			var enemy = WarManager.get_player_war_opponent() # New helper needed
			var wartarget_province = _find_best_wartime_target(enemy)
			format_args["enemy_kingdom_name"]= enemy.kingdom_name
			format_args["enemy_kingdom_id"]= enemy.id
			if is_instance_valid(wartarget_province):
				format_args["wartarget_province_name"]= wartarget_province.province_name
				format_args["wartarget_province_id"]= wartarget_province.id
		# We'll need these for the outcomes
	
	var eligible_ladies = GameManager.get_eligible_courting_targets(GameManager.player_kingdom.ruler)
	# 2. Check if there are any candidates
	if eligible_ladies.is_empty():
		# Cannot fire the event, maybe choose a different one
		print("no ladies")

	# 4. Loop through the candidates and create dynamic options
	# Format the text with the lady's name
	format_args["lady_name_1"]= eligible_ladies[0].full_name
	format_args["lady_personality_1"]= eligible_ladies[0].CharacterPersonality.keys()[eligible_ladies[0].personality].to_lower()
	format_args["lady_id_1"]=eligible_ladies[0].id
	
	format_args["lady_name_2"]= eligible_ladies[1].full_name
	format_args["lady_personality_2"]= eligible_ladies[1].CharacterPersonality.keys()[eligible_ladies[1].personality].to_lower()
	format_args["lady_id_2"]=eligible_ladies[1].id
	
	format_args["owned_province_name"] = owned_province.province_name
 
		
	return format_args


func _find_valid_trade_partner() -> Kingdom:
	var player_kingdom = GameManager.player_kingdom
	var potential_partners: Array[Kingdom] = []

	# We loop through all other kingdoms
	for kingdom in GameManager.all_kingdoms:
		# --- Filter out invalid partners ---
		if kingdom == player_kingdom: continue # Can't trade with yourself
		if not is_instance_valid(kingdom.ruler): continue # Kingdom must have a ruler
		
			
		# Condition: Must NOT be a rival
		if player_kingdom.rivals.has(kingdom.id):
			continue
			
		# Condition 3: Relations must be neutral or friendly (>= 0)
		var relations = player_kingdom.relations.get(kingdom.id, -100)
		if relations < 0:
			continue
			
		# If all checks pass, they are a valid potential partner
		potential_partners.append(kingdom)

	if potential_partners.is_empty():
		return null
	else:
		return potential_partners.pick_random()
		

func _find_weakest_neighbor_province() -> Province:
	var player_kingdom = GameManager.player_kingdom
	var best_target_province: Province = null
	var highest_score = -INF # We're looking for the highest score (most advantageous target)

	# 1. Get all neighboring kingdoms
	var neighbors = player_kingdom.get_neighboring_kingdoms()
	
	for neighbor_kingdom in neighbors:
		# 2. For each neighbor, get the provinces they own that border us.
		var border_provinces = GameManager.get_border_provinces(neighbor_kingdom, player_kingdom)
		
		for province in border_provinces:
			# --- 3. Score each potential target province ---
			
			# a) Don't target a kingdom's capital. This is a sacred rule.
			if province == neighbor_kingdom.capital:
				continue

			# b) Calculate the score.
			# We want a target that is militarily weak but economically valuable.
			var manpower_advantage = float(player_kingdom.manpower - neighbor_kingdom.manpower)
			var economic_value = float(province.maintenance_cost) # Use maintenance cost as a proxy for value
			
			# The score is a combination of how much stronger we are and how rich the land is.
			var score = manpower_advantage + (economic_value * 20.0) # Weight economic value heavily
			
			if score > highest_score:
				highest_score = score
				best_target_province = province
				
	# 4. Return the province that had the highest score.
	# This will be null if no valid non-capital provinces were found.
	return best_target_province
	
func _prepare_border_dispute_event(event_template: GameEvent, target_province: Province) -> PreparedEvent:
	var target_kingdom = target_province.owner
	print("border dispute with ",target_province.owner)
	# 1. Create the formatting arguments dictionary.
	# This holds all the dynamic data we need to inject into the text and outcomes.
	var format_args = {
		"target_province_name": target_province.province_name,
		"target_province_id": target_province.id,
		"target_kingdom_name": target_kingdom.kingdom_name,
		"target_kingdom_id": target_kingdom.id,
		"target_ruler_name": target_kingdom.ruler.full_name,
		"weak_neighbor_province_name": target_province.province_name,
		"weak_neighbor_province_id": target_province.id,
		"weak_neighbor_kingdom_name": target_kingdom.kingdom_name,
		"weak_neighbor_kingdom_id": target_kingdom.id,
		"weak_neighbor_ruler_name": target_kingdom.ruler.full_name
	}
	
	# 2. Create the PreparedEvent package.
	# The event_resource itself doesn't need to be modified, as the text formatting
	# and outcome personalization will happen later in the MainView.
	# We just need to bundle the template and the arguments together.
	var prepared_event = PreparedEvent.new()
	prepared_event.event_resource = event_template
	prepared_event.format_args = format_args
	
	return prepared_event
	
# Helper to find a target for the wartime offensive
func _find_best_wartime_target(enemy_kingdom: Kingdom) -> Province:
	var player_kingdom = GameManager.player_kingdom
	var potential_targets: Array[Province] = []
	
	# Find all non-capital provinces the enemy owns
	for province in enemy_kingdom.provinces_owned:
		if province != enemy_kingdom.capital:
			potential_targets.append(province)
			
	# If they only have their capital left, that becomes the only target
	if potential_targets.is_empty() and is_instance_valid(enemy_kingdom.capital):
		potential_targets.append(enemy_kingdom.capital)
		
	if potential_targets.is_empty():
		return null
	else:
		# Could add more logic here to pick the "best" target,
		# but for now, a random non-capital is good.
		return potential_targets.pick_random()

# Helper to package the event and its data
func _prepare_wartime_offensive_event(event_template: GameEvent, target_province: Province, enemy_kingdom: Kingdom) -> PreparedEvent:
	var format_args = {
		"enemy_kingdom_name": enemy_kingdom.kingdom_name,
		"target_province_name": target_province.province_name,
		# We'll need these for the outcomes
		"target_province_id": target_province.id,
		"enemy_kingdom_id": enemy_kingdom.id
	}
	
	var prepared_event = PreparedEvent.new()
	prepared_event.event_resource = event_template
	prepared_event.format_args = format_args
	
	return prepared_event

func get_event_choices_for_category(category: GameEvent.EventCategory, kingdom: Kingdom) -> Array[GameEvent]:
	var choices: Array[GameEvent] = []
	
	# --- 1. THE NEW MASTER FILTER ---
	# Instead of using 'all_events', we first get a list of only the currently unlocked events.
	var unlocked_events = all_events.filter(func(e): return GameManager.unlocked_event_ids.has(e.event_id))
	
	var all_valid_events = unlocked_events.filter(func(e): return e.category == category and _is_event_valid_for_kingdom(e, kingdom))
	if all_valid_events.is_empty():
		return [] # No choices available

	
	# 2. Separate them by rarity.
	var commons = all_valid_events.filter(func(e): return e.rarity == GameEvent.EventRarity.COMMON)
	var uncommons = all_valid_events.filter(func(e): return e.rarity == GameEvent.EventRarity.UNCOMMON)
	var rares = all_valid_events.filter(func(e): return e.rarity == GameEvent.EventRarity.RARE)
	
	commons.shuffle()
	uncommons.shuffle()
	rares.shuffle()
	
	print("common list events")
	for element in commons:
		print(element.event_id)
		
	print("uncommon list events")
	for element in uncommons:
		print(element.event_id)
	# 3. Add two common events (if available).
	for i in range(2):
		if not commons.is_empty():
			choices.append(commons.pop_front())
			
	# 4. Add one special event (Rare > Uncommon).
	# We'll use a weighted chance to find a rare one.
	if not rares.is_empty() and randf() < 0.25: # 25% chance to see a rare event
		choices.append(rares.pop_front())
		print("rare list events")
		for element in rares:
			print(element.event_id)
	elif not uncommons.is_empty():
		choices.append(uncommons.pop_front())
	else:
		# If no uncommon/rare events are valid, fill the last slot with another common one.
		if not commons.is_empty():
			choices.append(commons.pop_front())
	
	print("final list events")
	for element in choices:
		print(element.event_id)
	
	return choices

func _find_squire_for_knighting() -> Character:
	var player_court = GameManager.get_characters_in_court(GameManager.player_kingdom)
	var candidates: Array[Character] = []
	for char in player_court:
		var age = char.get_age()
		if char.is_alive and not char.is_knight and char.gender == Character.Gender.MALE and age >= 16 and age <= 22:
			candidates.append(char)
	
	return candidates.pick_random() if not candidates.is_empty() else null
