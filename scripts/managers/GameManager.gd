extends Node

signal turn_advanced
signal game_world_ready
signal game_over(summary_data)

const INCOME_PER_FARM_GOLD = 15
const INCOME_PER_MINE_GOLD = 40
const FOOD_COST_PER_10_PEOPLE = 0.5 
const FOOD_PER_FARM = 80
const FOOD_PER_GRANARY = 150
const FOOD_BONUS_IRRIGATION = 20
const FOOD_BONUS_BOUNTIFUL = 50
const GOLD_BONUS_FOREST = 5
const FOOD_BONUS_FISHING_VILLAGE = 25
const COST_PER_100_MANPOWER = 10
const FOOD_COST_PER_FAMILY = 1
const INCOME_PER_COASTAL_PROVINCE = 1
const TAX_PER_FAMILY = 2
const ALL_STORYLINES = ["SERPENT"]
const TRADE_DEAL_FOOD_AMOUNT = 25
const TRADE_DEAL_GOLD_AMOUNT = 20

enum TargetRelationshipType {
	FRIENDLY_NON_ALLY,
	UNFRIENDLY_NON_RIVAL
}

#Map Mode Enum ---
enum MapMode {
	VIEW_ONLY,
	SELECT_ANNEX_TARGET, #empty neighbours
	SELECT_CLAIM_TARGET #any neighbours
}

# --- NEW: Season Enum ---
enum Season {
	SPRING, # Corresponds to index 0
	SUMMER, # Corresponds to index 1
	AUTUMN, # Corresponds to index 2
	WINTER  # Corresponds to index 3
}

var all_kingdoms: Array[Kingdom] = []
var player_kingdom: Kingdom
var all_provinces_in_world: Array[Province] = []
var _player_ruler_at_turn_start: Character = null
var player_succession_pending: bool = false # This is true only during the turn after the player ruler dies,
var debug=true



var current_year: int = 1040
var current_season: Season = Season.SPRING # Start in Spring
var current_month: int = 1
var start_year: int
var peak_province_count: int = 1

var illness_factor=0
var murder_factor=0

var _character_id_map: Dictionary = {}
var _kingdom_id_map: Dictionary = {}
var active_storylines: Dictionary = {}   # Storyline Management

var incremental_id: int = 0
var all_characters_in_world: Array[Character] = [] # A central list of all characters.


var monthly_event_log: Array[String] = []
var unlocked_event_ids: Array[String] = []
var monthly_chronicle: Dictionary = {}

func _ready():
	print("Game Manager is ready.")

func start_new_game(num_kingdoms: int):
	print("--- STARTING NEW GAME: WORLD GENERATION ---")
	
	# Clear any data from a previous game
	all_kingdoms.clear()
	all_characters_in_world.clear()
	all_provinces_in_world.clear()
	ColorManager.reset_color_index()
	active_storylines.clear()
	initialize_unlocked_events()
	start_year = current_year # Store the starting year
	
	# --- STAGE 1: Generate the world map from the JSON file ---
	var unique_dynasty_names = NameGenerator.get_dynasty_name_list()
	if unique_dynasty_names.size() < num_kingdoms:
			printerr("WARNING: Not enough unique dynasty names (%d) for the number of kingdoms requested (%d). Duplicates may occur." % [unique_dynasty_names.size(), num_kingdoms])
		
	unique_dynasty_names.shuffle()
	
	all_provinces_in_world = _generate_world_map()
	if all_provinces_in_world.is_empty():
		printerr("Halting game start because map generation failed.")
		return
	
		
	# Create a pool of provinces that can be assigned as capitals
	var available_capitals = all_provinces_in_world.duplicate()
	
	# --- STAGE 2: Create Kingdoms and assign their capitals ---
	var temp_kingdoms: Array[Kingdom] = []
	for i in range(num_kingdoms):
		# Safety check: make sure we have provinces left to assign
		if available_capitals.is_empty():
			print("WARNING: Ran out of provinces to assign. Created %d kingdoms." % i)
			break
			
	# --- STAGE 1: Create Kingdoms, Rulers, and Adult Courtiers ---
	#for i in range(num_kingdoms):
		# Create the Kingdom itself
		var kingdom = Kingdom.new()
		kingdom.id=get_id()
		_kingdom_id_map[kingdom.id] = kingdom
		kingdom.treasury = randi_range(2000, 5000)
		kingdom.manpower = randi_range(800, 1500)
		kingdom.color = ColorManager.get_next_kingdom_color()
		for k1 in all_kingdoms:
			for k2 in all_kingdoms:
				if k1 == k2: continue # A kingdom has no relation with itself
		# Set a neutral or slightly random starting relationship
				k1.relations[k2.id] = randi_range(-10, 10)
				
		all_kingdoms.append(kingdom)
		
		# Create the Ruler for this new Kingdom
		var ruler = Character.new()
		ruler.id=get_id()
		ruler.gender = Character.Gender.MALE
		ruler.first_name = NameGenerator.get_random_first_name(Character.Gender.MALE)
		
		var new_dynasty_name = unique_dynasty_names.pop_front()
		if new_dynasty_name == null:
			new_dynasty_name = "Landless %d" % (i + 1)
		ruler.dynasty_name = new_dynasty_name
			
		#ruler.dynasty_name = NameGenerator.get_random_dynasty_name()
		ruler.set_initial_age(randi_range(20, 35)) # Rulers start in their prime
		ruler.stewardship = randi_range(4, 8) # Rulers are generally competent
		ruler.diplomacy = randi_range(4, 8)
		ruler.martial = randi_range(4, 8)
		ruler.intrigue = randi_range(4, 8)
		ruler.vigor = randi_range(4, 8)
		ruler.charisma = randi_range(4, 8)
		ruler.expansion_desire = randi_range(20, 80)
		var personality_count = Character.CharacterPersonality.size()
		# 2. Pick a random index from 0 to the size-1
		var random_personality_index = randi() % personality_count
		# 3. Assign the enum value at that index
		ruler.personality = random_personality_index
		kingdom.ruler = ruler
		
					# --- NEW: Assign a capital province to the kingdom ---
		var capital_province = available_capitals.pick_random()
		available_capitals.erase(capital_province) # Remove it from the pool
		
		capital_province.buildings.append(Province.BuildingType.FARM)
		capital_province.buildings.append(Province.BuildingType.MINE)
		
		# Set ownership both ways. THIS IS CRITICAL.
		kingdom.provinces_owned.append(capital_province)
		capital_province.owner = kingdom	
		
		
		kingdom.capital = capital_province
		
		kingdom.kingdom_name = "The Kingdom of %s" % ruler.dynasty_name
		add_character_to_world(ruler, kingdom)
		
				# --- STAGE 3: Finalize and Start ---
		if not all_kingdoms.is_empty():
			player_kingdom = all_kingdoms.pick_random()
			
		player_kingdom.player_kingdom=true
		player_kingdom.ruler.player_character=true
	
		for onekingdom in all_kingdoms:
			var is_player_court = (onekingdom == player_kingdom)
			_populate_court(onekingdom, is_player_court)


	if is_instance_valid(player_kingdom):
		_apply_meta_progression_bonuses(player_kingdom)
	#initiate the temp variable that holds current ruler so the succession system works
	_player_ruler_at_turn_start = player_kingdom.ruler
	
	# --- STAGE 2: Generate Children for the newly married couples ---
	# We do this in a separate loop to ensure all marriages are set first.
	for kingdom in all_kingdoms:
		_generate_initial_children(kingdom)

# ---  Assign Starting Rivals AFTER all kingdoms are created ---
	if is_instance_valid(player_kingdom):
		# Find all other kingdoms that are not the player
		var potential_rivals = all_kingdoms.filter(func(k): return k != player_kingdom)
		potential_rivals.shuffle() # Randomize the list
		
		# Assign 1 or 2 rivals
		var num_rivals = randi_range(1, 2)
		for i in range(min(num_rivals, potential_rivals.size())):
			var new_rival = potential_rivals[i]
			player_kingdom.rivals.append(new_rival.id)
			# Make it mutual
			new_rival.rivals.append(player_kingdom.id)
			# Set a negative starting relation
			player_kingdom.relations[new_rival.id] = -40
			new_rival.relations[player_kingdom.id] = -40
	
# ---  Stage 3: Assign storylines ---			
	var chosen_storyline = ALL_STORYLINES.pick_random()
	_setup_storyline(chosen_storyline)
	
	_calculate_monthly_economy()
	print("--- WORLD GENERATION COMPLETE ---")
	emit_signal("game_world_ready")

func _apply_meta_progression_bonuses(kingdom: Kingdom):
	print("Applying meta progression bonuses...")
	
	# --- UNLOCK: INCREASED_INFLUENCE ---
	if MetaProgression.unlocks["INCREASED_INFLUENCE"]:
		print("  - Applying 'Increased Influence': Starting with an extra province.")
		# Find an unowned province that borders the player's capital.
		var extra_province = kingdom.get_neighboring_unowned_provinces().pick_random()
		if is_instance_valid(extra_province):
			# Use our master function to annex it safely.
			update_geopolitical_state(extra_province, kingdom)
		else:
			print("    - (Could not find an empty neighbor to grant extra province.)")
			
	# --- UNLOCK: ROYAL_TREASURY_GRANT ---
	if MetaProgression.unlocks["ROYAL_TREASURY_GRANT"]:
		print("  - Applying 'Royal Treasury Grant': +250 starting Treasury.")
		kingdom.treasury += 250
		
	# --- UNLOCK: VETERAN_TRAINING ---
	if MetaProgression.unlocks["VETERAN_TRAINING"]:
		print("  - Applying 'Veteran Training': +500 starting Manpower.")
		kingdom.manpower += 500
		
		
func _setup_storyline(storyline_id: String):
	print("STORYLINE: Setting up '%s'" % storyline_id)
	
	match storyline_id:
		"SERPENT":
			# 1. Set the storyline as active at stage 1.
			active_storylines["SERPENT"] = 0
			
			# 2. Create the antagonist: Lord Valerius, the player's uncle.
			var uncle = Character.new()
			uncle.first_name = "Valerius"
			uncle.dynasty_name = player_kingdom.ruler.dynasty_name # Same dynasty
			uncle.gender = Character.Gender.MALE
			# Make him older than the player
			uncle.set_initial_age(player_kingdom.ruler.get_age() + 15)
			
			# Give him a relevant personality and stats
			uncle.personality = Character.CharacterPersonality.RUTHLESS
			uncle.intrigue = randi_range(7, 10)
			uncle.diplomacy = randi_range(6, 9)
			# ... other stats
			
			# 3. Establish the family relationship.
			# For simplicity, we'll just say he's the brother of the player's (unseen) father.
			
			# 4. Add him to the player's court.
			add_character_to_world(uncle, player_kingdom)
			
func initialize_chronicle_for_new_turn():
	monthly_chronicle = {
		"critical_events": [],
		"kingdom_logs": {}
	}
	# Initialize a log for every kingdom.
	for kingdom in all_kingdoms:
		monthly_chronicle.kingdom_logs[kingdom] = []
	
	print("DEBUG: Chronicle initialized for the new turn.")
	
	
func advance_turn():
	print("GameManager: Advancing Turn...")
	
	# 1. Clear the log for the new month.
	monthly_event_log.clear()

	
	for kingdom in all_kingdoms:
		monthly_chronicle.kingdom_logs[kingdom] = []
	# 2. Calculate the economy first. This determines income and expenses.
	_calculate_monthly_economy()
	
	# 3. Simulate all AI actions (expansion, war declarations, marriages).
	Aimanager.simulate_ai_turns()
	
	# 4. Update the state of all ongoing wars.
	WarManager.update_monthly_warfare()
	
	# 5. Process character life cycles (births, deaths, aging).
	illness_factor=randi() % 3
	murder_factor=randi() % 2
	_update_seasonal_state()
	
	# 6. Announce that the turn's calculations are complete.
	emit_signal("turn_advanced")
	print("GameManager: Turn Advanced.")


func initialize_unlocked_events():
	unlocked_event_ids.clear()
	
	# Loop through every single event that the EventManager has loaded.
	for event in EventManager.all_events:
		# If the event is flagged to be unlocked at the start...
		if event.unlocked_at_start:
			# ...add its ID to our active list.
			unlocked_event_ids.append(event.event_id)
			
	print("Initialized with %d starting unlocked events." % unlocked_event_ids.size())
	

func _update_seasonal_state():
	# --- TIME ADVANCEMENT ---
	#current_month += 1
	current_season = (current_season + 1) % 4 # This loops from 3 back to 0
	
	#if current_month > 12:
		#current_month = 1
		#current_year += 1
	# If we've looped back to Spring, a new year has begun
	if current_season == Season.SPRING:
		current_year += 1
		# This is where you would age up all living characters
		# NOTE: Age is calculated on the fly (current_year - birth_year),
		# so we don't need a separate "age up" loop.

	# --- CHARACTER LIFE CYCLE SIMULATION --- DONE IN CHARACTER.GD
	# _process_character_deaths()
	# _process_character_births()
	
	# We iterate over a copy of the array because the _give_birth() method
	# might add new characters to the list while we are looping, which is unsafe.
	var characters_to_process = all_characters_in_world.duplicate()
	
	for character in characters_to_process:
		# The character's internal logic handles all the checks
		if character == player_kingdom.ruler:
			continue # Skip the player's own life-cycle tick for safety
		character.process_monthly_tick()
	
	# --- CLEAN UP THE DEAD ---
	# After processing, we can safely remove any characters who died this month.
	# We iterate backwards to avoid issues with shifting indices after removal.
	for character in all_characters_in_world:
		# Check if a ruler died during the tick() and needs succession handled.
		if not character.is_alive and character.cause_of_death != "" and is_instance_valid(character.current_court):
			if character.current_court.ruler == character:
				_handle_succession(character.current_court)
			# Mark cause of death as "processed" to avoid handling it again next month
			character.cause_of_death = "" 
			
	print("Monthly character update complete. %d characters in world." % all_characters_in_world.size())

# --- NEW: A helper to get the season name as a string ---
func get_season_name() -> String:
	return Season.keys()[current_season].capitalize()
	
func destroy_kingdom(kingdom_to_destroy: Kingdom):
	print("The Kingdom of %s has been destroyed!" % kingdom_to_destroy.kingdom_name)

	# 1. Kill the court
	var characters_to_kill: Array[Character] = []
	for character in get_tree().get_nodes_in_group("all_characters"): # Using groups to track characters
		if character.current_court == kingdom_to_destroy:
			characters_to_kill.append(character)
	
	for character in characters_to_kill:
		character.die("Slain in the fall of their kingdom.")

	# 2. Check for player game over
	if kingdom_to_destroy == player_kingdom:
		emit_signal("game_over", "Your realm has been conquered.")
		return

	# 3. Remove kingdom from simulation
	all_kingdoms.erase(kingdom_to_destroy)

# This function should be called whenever a new character is created
func add_character_to_world(character: Character, court: Kingdom):
	character.current_court = court
	all_characters_in_world.append(character)
	_character_id_map[character.id] = character
	#print("Added %s to the world at %s's court." % [character.character_name, court.kingdom_name])

func handle_ruler_death(kingdom: Kingdom):
	# Its only job is to call the main succession logic.
	_handle_succession(kingdom)
	
func _handle_succession(kingdom: Kingdom) -> bool:
	# Find a valid heir (e.g., eldest living son)
	var heir: Character = null
	var potential_heirs: Array[Character] = []
	var old_ruler=kingdom.ruler
	
	if kingdom == player_kingdom:
		player_succession_pending = false
	
	for child in kingdom.ruler.children:
		# Simple primogeniture: male children first
		if child.is_alive and child.gender == Character.Gender.MALE:
			potential_heirs.append(child)
	
	# Sort by age (oldest first)
	potential_heirs.sort_custom(func(a, b): return a.birth_year < b.birth_year)

	if not potential_heirs.is_empty():
		heir = potential_heirs[0]
	else:
		print('no heir')

	if heir:
		kingdom.ruler = heir
		print("Succession in %s! %s takes the throne." % [kingdom.kingdom_name, heir.character_name])
		# If this is the player's kingdom, fire a major event!
		if kingdom == player_kingdom:
			# EventManager.fire_event("Your ruler has died! Long live King/Queen %s!" % heir.character_name)
			return true
		return true	
	else:
		# No heir found, the dynasty is broken!
		# If it's an AI kingdom, it might fracture or be absorbed.
		# If it's the player, it's game over.
		if kingdom == player_kingdom:
			 #--- No Child Heir, Check for Spouse ---
			var spouse = player_kingdom.ruler.spouse
			if is_instance_valid(spouse) and spouse.is_alive:
				kingdom.ruler = spouse
				print("REGENCY: The consort, %s, takes control of the realm." % spouse.full_name)
				# TODO: Show a "A Regency is Declared!" panel
				return true # Succession was successful
				
			var summary_data = {
			"dynasty_name": old_ruler.dynasty_name,
			"years_ruled": current_year - start_year,
			"peak_provinces": peak_province_count,
			"final_ruler_name": old_ruler.full_name,
			"cause_of_downfall": "The line of succession was broken."
			}
			emit_signal("game_over", summary_data)
			return false
		else:
			# For AI, we can simply destroy the kingdom
			destroy_kingdom(kingdom)
			return false
			
# Applies a list of mechanical effects to a kingdom.
func apply_outcomes(target_kingdom: Kingdom, outcomes: Array[EventOutcome]):
	for outcome in outcomes:
		match outcome.type:
			"ChangeResource":
				# Assuming resource names like "Gold", "Manpower" match property names
				var current_value = target_kingdom.get(outcome.target.to_lower())
				target_kingdom.set(outcome.target.to_lower(), current_value + outcome.value)
				print("Applied: %s %s to %s" % [outcome.value, outcome.target, target_kingdom.kingdom_name])
			"ChangeStat":
				# Assuming resource names like "Gold", "Manpower" match property names
				var current_value = player_kingdom.ruler.get(outcome.target.to_lower())
				player_kingdom.ruler.set(outcome.target.to_lower(), current_value + outcome.value)
				print("Applied: %s %s to %s" % [outcome.value, outcome.target, player_kingdom.ruler.full_name])
								
			"ChangeOpinion":
				var current_value = target_kingdom.get(outcome.target.to_lower()+"_opinion")
				target_kingdom.set(outcome.target.to_lower()+"_opinion", current_value + outcome.value)
				# This requires a more complex character/opinion system
				print("Applied: %s Opinion %d" % [outcome.target, outcome.value])
				pass # TODO: Implement opinion changes
			# ... handle other outcome types
			"AddModifier":
				# The outcome.target is the modifier ID (e.g., "FestivalSpirit")
				# The outcome.value is the duration in months.
				#FestivalSpirit: fertility up
				#NewFarmlands: adds gold and food
				#ImprovedTools: adds gold
				#RoyalArmory: adds manpower
				#AgentInCourt_ : when in war, gives advantage
				#RivalSchemePower : when in war, gives disadvantage
				#LowMorale/HighMorale : Change military morale
				if outcome.duration is int:
					target_kingdom.add_modifier(outcome.target, outcome.duration, outcome.value, outcome.stackable)
				else:
					printerr("AddModifier outcome for '%s' has an invalid duration value." % outcome.target)
			"ChangeAffection":
				pass
			"ChangeCharacterOpinion":
				pass
			"GainIntel":
				pass
			"ChangeKingdomRelation":
				pass
			"GainRivalCasusBelli":
				pass
			"StartCourting":
				print("Courtship started")
				player_kingdom.ruler.is_courting=true
				print(outcome.target.to_lower())
				player_kingdom.ruler.girlfriend=find_character_by_id(outcome.target.to_lower())
				print (player_kingdom.ruler.girlfriend.full_name)
				
			"MarryCharacter":
				player_kingdom.ruler.spouse=player_kingdom.ruler.girlfriend
				player_kingdom.ruler.girlfriend.spouse=player_kingdom.ruler
				player_kingdom.ruler.girlfriend=null
				player_kingdom.ruler.is_courting=false
				
			"EndCourting":
				player_kingdom.ruler.ex_girlfriend=player_kingdom.ruler.girlfriend
				player_kingdom.ruler.girlfriend=null
				player_kingdom.ruler.is_courting=false

			"AddProvince":
				#_annex_province(outcome.target.to_lower())
				_annex_province(outcome.target)
				
			"AddBuilding":
				# The target is the province ID (as a string)
				# The value is the building type (as a string)
				var province = find_province_by_id(int(outcome.target))
				var building_type = outcome.value
				province.buildings.append(building_type)
				
			"ChangeWarScore":
				var war = WarManager.get_player_war()
				if is_instance_valid(war):
					war.war_score = clampf(war.war_score + float(outcome.value), -100.0, 100.0)
					print("Player war score changed by %s. New score: %.1f" % [str(outcome.value), war.war_score])
					
			"EndWarTotalVictory":
				var war = WarManager.get_player_war()
				var enemy_kingdom = GameManager.find_kingdom_by_id(int(outcome.target))
				
				if is_instance_valid(war) and is_instance_valid(enemy_kingdom):
					# Call the existing WarManager function to handle the destruction
					WarManager.end_war_total_victory(player_kingdom, enemy_kingdom, war)
				else:
					printerr("EndWarTotalVictory Error: Could not find active war or enemy kingdom.")
					
			"EndWarBySurrender":
				var war = WarManager.get_player_war()
				if is_instance_valid(war):
					var loser = WarManager.get_player_war_opponent()
					var winner = player_kingdom
					
					# Call the WarManager's public function to handle the surrender.
					WarManager.enact_surrender(loser, war)
				else:
					printerr("EndWarBySurrender outcome fired, but player is not at war.")
					
			"AdvanceStoryline":
				# The outcome.target is the Storyline ID string (e.g., "SERPENT_IN_COURT")
				# The outcome.value is the new stage number (e.g., 2)
				var storyline_id = str(outcome.target)
				var new_stage = int(outcome.value)
				_advance_storyline(storyline_id, new_stage)
				
			"UnlockEvent":
				# The outcome.target is the event_id string to unlock.
				var event_id_to_unlock = str(outcome.target)
				
				# Add the event to the unlocked list if it's not already there.
				if not unlocked_event_ids.has(event_id_to_unlock):
					unlocked_event_ids.append(event_id_to_unlock)
					var log_msg = "A new opportunity has arisen..." # A hint to the player
					monthly_event_log.append(log_msg)
					print("EVENT UNLOCKED: ", event_id_to_unlock)

#Function to advance or end a storyline ---
# A private helper to keep the logic clean.
func _advance_storyline(storyline_id: String, new_stage: int):
	# First, check if the storyline is actually active.
	if not active_storylines.has(storyline_id):
		printerr("Attempted to advance storyline '%s', but it is not active." % storyline_id)
		return

	# A new_stage of 0 or less signifies the end of the storyline.
	if new_stage <= 0:
		active_storylines.erase(storyline_id)
		var log_msg = "The storyline '%s' has concluded." % storyline_id
		monthly_event_log.append(log_msg)
		GameManager.monthly_chronicle.critical_events.append(log_msg)
		print("STORYLINE: ", log_msg)
		match storyline_id:
					"SERPEN_IN_COURT":
						# The player successfully defeated their uncle!
						# We check if this is the first time they've done it.
						if not MetaProgression.unlocks["INCREASED_INFLUENCE"]:
							print("META UNLOCK: Player has earned 'Increased Influence'!")
							MetaProgression.unlocks["INCREASED_INFLUENCE"] = true
							# Save the progress immediately so it's not lost.
							MetaProgression.save_progress()
	else:
		# Otherwise, update the dictionary to the new stage.
		active_storylines[storyline_id] = new_stage
		var log_msg = "The storyline '%s' has advanced to stage %d." % [storyline_id, new_stage]
		monthly_event_log.append(log_msg)
		print("STORYLINE: ", log_msg)
		
		
func _process_character_deaths():
	var characters_to_process = all_characters_in_world.duplicate()
	for character in characters_to_process:
		if character.is_alive:
			var age = current_year - character.birth_year
			if age > 50:
				var death_chance = pow(age - 49, 2) / (character.vigor * 2.0)
				if randi() % 1000 < death_chance:
					var cause = "died of old age"
					character.die(cause)
					# --- NEW: Log the death ---
					monthly_event_log.append("DEATH: %s has %s at age %d." % [character.full_name, cause, age])
					GameManager.monthly_chronicle.kingdom_logs[character.current_court].append("DEATH: %s has %s at age %d." % [character.full_name, cause, age])



func _process_character_births():
	var characters_to_process = all_characters_in_world.duplicate()
	for character in characters_to_process:
		if character.is_alive and character.is_pregnant:
			character.pregnancy_term -= 1
			if character.pregnancy_term <= 0:
				# The _give_birth method now returns the child object
				var child = character._give_birth() 
				if is_instance_valid(child):
					# --- NEW: Log the birth ---
					monthly_event_log.append("BIRTH: %s has been born to %s and %s." % [child.full_name, child.father.full_name, child.mother.full_name])
					GameManager.monthly_chronicle.kingdom_logs[child.current_court].append("BIRTH: %s has been born to %s and %s." % [child.full_name, child.father.full_name, child.mother.full_name])


# --- HELPER FUNCTIONS ---
func get_id() ->String:
	incremental_id+=1
	return str(incremental_id)
	
# Helper to create adults, marry them off, and add them to a specific court.
func _populate_court(kingdom: Kingdom,is_player_court: bool = false):
	var num_courtiers_per_gender = randi_range(10, 20) # "Dozens"
	
	var unmarried_men: Array[Character] = []
	var unmarried_women: Array[Character] = []
	
	# Create the men
	for i in range(num_courtiers_per_gender):
		var man = Character.new()
		man.id=get_id()
		man.gender = Character.Gender.MALE
		man.first_name = NameGenerator.get_random_first_name(man.gender)
		# Courtiers might not have a famous dynasty name
		if randf() < 0.3: # 30% chance of having a dynasty name
			man.dynasty_name = NameGenerator.get_random_dynasty_name()
		else:
			man.dynasty_name = NameGenerator.get_random_common_name()
		
		man.set_initial_age(randi_range(16, 50))
		man.stewardship = randi_range(1, 6) # Courtiers are more average
		man.diplomacy = randi_range(1, 6)
		man.martial = randi_range(1, 6)
		man.intrigue = randi_range(1, 6)
		man.vigor = randi_range(1, 6)
		man.charisma = randi_range(1, 6)
		var personality_count = Character.CharacterPersonality.size()
		# 2. Pick a random index from 0 to the size-1
		var random_personality_index = randi() % personality_count
		# 3. Assign the enum value at that index
		man.personality = random_personality_index
		add_character_to_world(man, kingdom)
		unmarried_men.append(man)
		
	# Create the initial batch of women
	for i in range(num_courtiers_per_gender):
		var woman = _create_random_woman(kingdom) # Use a new helper for this
		unmarried_women.append(woman)

	# Marry them!
	unmarried_men.shuffle()
	unmarried_women.shuffle()
	var num_couples = min(unmarried_men.size(), unmarried_women.size())
	
	for i in range(num_couples):
		var man_to_marry = unmarried_men.pop_front()
		var woman_to_marry = unmarried_women.pop_front()
		
		man_to_marry.spouse = woman_to_marry
		woman_to_marry.spouse = man_to_marry
		woman_to_marry.dynasty_name=man_to_marry.dynasty_name
		# print("Married %s and %s in the court of %s" % [man_to_marry.full_name, woman_to_marry.full_name, kingdom.kingdom_name])

# --- NEW: Minimum Guarantee Logic for Player's Court ---
	if is_player_court:
		var min_eligible_women = 10
		# Check how many eligible women we currently have
		var eligible_count = unmarried_women.filter(func(w): return w.get_age() >= 16 and w.get_age() <= 45).size()
		
		var women_to_add = min_eligible_women - eligible_count
		if women_to_add > 0:
			print("Player court short on eligible ladies. Generating %d more." % women_to_add)
			for i in range(women_to_add):
				# Create a new woman who is GUARANTEED to be of eligible age
				var new_woman = _create_random_woman(kingdom, true)
				unmarried_women.append(new_woman)


# --- NEW: A dedicated helper for creating women to reduce code duplication ---
func _create_random_woman(kingdom: Kingdom, force_eligible_age: bool = false) -> Character:
	var woman = Character.new()
	woman.id=get_id()
	woman.gender = Character.Gender.FEMALE
	woman.first_name = NameGenerator.get_random_first_name(woman.gender)
	woman.dynasty_name = NameGenerator.get_random_common_name()
	
	if force_eligible_age:
		# Guarantee they are of an age to be courted/married
		woman.set_initial_age(randi_range(16, 30))
	else:
		# The standard random age range
		woman.set_initial_age(randi_range(16, 45))
		
	woman.stewardship = randi_range(1, 6)
	woman.diplomacy = randi_range(1, 6)
	woman.martial = randi_range(1, 6)
	woman.intrigue = randi_range(1, 6)
	woman.vigor = randi_range(1, 6)
	woman.charisma = randi_range(1, 6)
	var personality_count = Character.CharacterPersonality.size()
	# 2. Pick a random index from 0 to the size-1
	var random_personality_index = randi() % personality_count
	# 3. Assign the enum value at that index
	woman.personality = random_personality_index
	add_character_to_world(woman, kingdom)
	return woman
	
# Helper to create children for already-married couples in a court.
func _generate_initial_children(kingdom: Kingdom):
	var married_women_in_court: Array[Character] = []
	
	# Find all the married women in this specific court
	for char in all_characters_in_world:
		if char.current_court == kingdom and char.gender == Character.Gender.FEMALE and char.spouse:
			married_women_in_court.append(char)
			
	# For each married woman, decide how many children to create
	for woman in married_women_in_court:
		var father = woman.spouse
		var child_chance = 0.70 # 70% chance to have at least one child
		
		# Loop up to 10 times, with decreasing probability for each child
		for i in range(10):
			if randf() < child_chance:
				# --- Create the child ---
				var child = Character.new()
				child.id=get_id()
				child.gender = Character.Gender.MALE if randi() % 2 == 0 else Character.Gender.FEMALE
				child.first_name = NameGenerator.get_random_first_name(child.gender)
				child.dynasty_name = father.dynasty_name # Inherit from father
				
				child.set_initial_age(randi_range(1, 12)) # Ages 1-12
				child.stewardship = randi_range(0, 3) # Children have low stats
				child.diplomacy = randi_range(0, 3)
				child.martial = randi_range(0, 3)
				child.intrigue = randi_range(0, 3)
				child.vigor = randi_range(0, 3)
				child.charisma = randi_range(0, 3)
				var personality_count = Character.CharacterPersonality.size()
				# 2. Pick a random index from 0 to the size-1
				var random_personality_index = randi() % personality_count
				# 3. Assign the enum value at that index
				child.personality = random_personality_index
				# Link family
				child.father = father
				child.mother = woman
				father.children.append(child)
				woman.children.append(child)
				
				add_character_to_world(child, kingdom)
				# print("Generated child %s for %s and %s" % [child.full_name, father.full_name, woman.full_name])

				# Decrease the chance for the next child significantly
				child_chance *= 0.55 
			else:
				# If the random check fails, they have no more children
				break

# Creates a dictionary mapping each kingdom to a list of its living courtiers.
func get_characters_grouped_by_court() -> Dictionary:
	var courts_dict = {}
	
	# Step 1: Initialize the dictionary with all kingdoms as keys.
	# This ensures that even a kingdom with zero living members will be listed.
	for kingdom in all_kingdoms:
		courts_dict[kingdom] = []
		
	# Step 2: Populate the lists by iterating through all characters.
	for character in all_characters_in_world:
		# We only care about living characters for the census.
		if character.is_alive and is_instance_valid(character.current_court):
			# Check if the court still exists in our dictionary (it should)
			if courts_dict.has(character.current_court):
				courts_dict[character.current_court].append(character)
				
	return courts_dict
	
func get_eligible_courting_targets(ruler: Character, count: int = 3) -> Array[Character]:
	# --- Guard Clause ---
	# If the ruler is invalid for any reason, return an empty list.
	if not is_instance_valid(ruler):
		printerr("get_eligible_courting_targets: Invalid ruler provided.")
		return []

	var eligible_targets: Array[Character] = []
	
	# --- Main Loop: Check every character in the world ---
	for character in all_characters_in_world:
		# --- Rule 1: Must be alive ---
		if not character.is_alive:
			continue
			
		# --- Rule 2: Must be of courting age (e.g., 16-45) ---
		var age = character.get_age()
		if age < 16 or age > 45:
			continue
			
		# --- Rule 3: Must be unmarried ---
		if is_instance_valid(character.spouse):
			continue
			
		# --- Rule 4: Must be of the opposite gender (for this implementation) ---
		if character.gender == ruler.gender:
			continue
			
		# --- Rule 5: Must not be the ruler themselves ---
		if character == ruler:
			continue
			
		# --- Rule 6: Must not be closely related ---
		# We delegate this complex check to a helper function for cleanliness.
		if _is_closely_related(ruler, character):
			continue
			
		# --- Rule 7: Must be in the player's court (for simplicity) ---
		# You could remove or change this later to allow for foreign marriages.
		if character.current_court != ruler.current_court:
			continue
			
		# --- If all checks pass, the character is eligible! ---
		eligible_targets.append(character)
	
	# --- Sort and Trim the List ---
	# Now that we have all eligible candidates, let's sort them so the "best" ones
	# are at the top of the list. Let's sort by a combination of Diplomacy and Vigor.
	eligible_targets.sort_custom(func(a, b): return (a.diplomacy + a.vigor) > (b.diplomacy + b.vigor))
	
	# Return only the top 'count' number of candidates (e.g., the top 3).
	return eligible_targets.slice(0, count)
	
# --- NEW HELPER FUNCTION ---
# Checks if two characters are immediate family (parent, child, or sibling).
# A private function, indicated by the underscore, as it's only used by this script.
func _is_closely_related(char1: Character, char2: Character) -> bool:
	# Check for parent/child relationship (both ways)
	if is_instance_valid(char1.father) and char1.father == char2: return true
	if is_instance_valid(char1.mother) and char1.mother == char2: return true
	if is_instance_valid(char2.father) and char2.father == char1: return true
	if is_instance_valid(char2.mother) and char2.mother == char1: return true
	
	# Check for sibling relationship (sharing at least one parent)
	# We must check if parents are valid before comparing them.
	if is_instance_valid(char1.father) and is_instance_valid(char2.father):
		if char1.father == char2.father:
			return true # They are at least half-siblings
			
	if is_instance_valid(char1.mother) and is_instance_valid(char2.mother):
		if char1.mother == char2.mother:
			return true # They are at least half-siblings
			
	# If no close relations were found, return false.
	return false

func find_character_by_id(character_id: String) -> Character:
	# Check if the ID is valid and exists in our map.
	if character_id.is_empty() or not _character_id_map.has(character_id):
		# It's good practice to print a warning if an ID is not found.
		# This helps catch bugs where an event outcome targets a dead character.
		# print("WARNING: Could not find character with ID: ", character_id)
		return null
		
	# Retrieve the character from the dictionary.
	var found_character = _character_id_map[character_id]
	
	# An extra safety check: ensure the character is still valid and hasn't been accidentally freed.
	if not is_instance_valid(found_character):
		return null
		
	return found_character

func check_for_critical_state_events() -> PreparedEvent:
	var player_ruler = player_kingdom.ruler
	
	print ("checking critical states")
	# --- BANKRUPTCY CHECK ---
	
	# --- Check 0: Is the Player Ruler ALIVE? (THE NEW, TOP-PRIORITY CHECK) ---
	if player_succession_pending:
		print("CRITICAL: Player ruler is null! Triggering death/succession event.")
		var event_res = EventManager.get_event_by_id("SP005")
		if event_res:
			# We need to format the text with the *previous* ruler's info
			# This requires a new variable, e.g., 'last_ruler_who_died'
			var context = {"dead_ruler": player_kingdom.ruler}
			return EventManager.prepare_event_for_display(event_res, context)
			
	if is_instance_valid(player_kingdom) and player_kingdom.treasury <= 0:
		print("CRITICAL: Player is bankrupt! Triggering overthrow event.")
		# Find the specific event resource for this situation.
		var overthrow_event = EventManager.get_event_by_id("SP001")
		
		if overthrow_event:
			# 2. Prepare the formatting arguments
			var prepared_event=EventManager.prepare_event_for_display(overthrow_event)
	
			return prepared_event
			
	if is_instance_valid(player_kingdom) and player_kingdom.food <= 0:
		print("CRITICAL: Kingdom is starving! Triggering revolution event.")
		# Find the specific event resource for this situation.
		var overthrow_event = EventManager.get_event_by_id("SP006")
		
		if overthrow_event:
			# 2. Prepare the formatting arguments
			var prepared_event=EventManager.prepare_event_for_display(overthrow_event)
	
			return prepared_event
			
	# --- WAR CHECKS ---
	var war = WarManager.get_player_war()
	if is_instance_valid(war):
		var enemy = WarManager.get_player_war_opponent()
		
		# --- TOTAL WAR WON CHECK ---
		if is_instance_valid(enemy) and enemy.provinces_owned.is_empty():
			print("CRITICAL: Player's war opponent has no provinces left!")
			# Get the event template
			var destroyed_event_res = EventManager.get_event_by_id("SP003")
			if destroyed_event_res:
				# Prepare it with the enemy's data so the text is correct
				var prepared_event = EventManager.prepare_event_for_display(destroyed_event_res)
				return prepared_event # Return the prepared event
				
		
	
		# --- Enemy Surrender CHECK ---
		# This is checked only if the enemy is not already totally defeated.
		if Aimanager.check_if_ai_will_surrender(enemy, war):
			print("CRITICAL: Player's war opponent wants to surrender!")
			var event_res = EventManager.get_event_by_id("SP002")
			if event_res:
				return EventManager.prepare_event_for_display(event_res)
				
	# No critical states found, the turn can proceed normally.
	return null
	
	
func _generate_world_map() -> Array[Province]:
	var all_provinces: Array[Province] = []
	var temp_provinces_by_id: Dictionary = {} # For fast lookups in the linking phase
	
	const MAP_FILE_PATH = "res://data/map/map.json"
	
	# 1. First, check if the file even exists. This is good practice.
	if not FileAccess.file_exists(MAP_FILE_PATH):
		printerr("CRITICAL ERROR: map_data.json not found at path: ", MAP_FILE_PATH)
		return []
	
	var content = FileAccess.get_file_as_string(MAP_FILE_PATH)
	var json_data = JSON.parse_string(content)
	
	if not json_data or not json_data.has("provinces"):
		printerr("CRITICAL ERROR: Failed to parse map_data.json or 'provinces' key is missing.")
		return []

	# --- PASS 1: Create all Province objects using your script ---
	# We loop through the JSON and create an instance for each province.
	print("DEBUG: World Gen - Pass 1: Creating province objects...")
	for p_data in json_data.provinces:
		# Here we call the _init() constructor from your province.gd script
		var new_province = Province.new(p_data.provinceId, p_data.name)
		new_province.is_coastal = p_data.get("coastal", false)
		
		var rand_roll = randi() % 100 # Roll d100
		
		if new_province.is_coastal and rand_roll < 20: # 20% of coastal provinces are special
			new_province.type = Province.ProvinceType.COASTAL_FISHING_VILLAGE
		elif rand_roll < 10: # 10% chance for Bountiful
			new_province.type = Province.ProvinceType.BOUNTIFUL
		elif rand_roll < 25: # 15% chance for Mountainous
			new_province.type = Province.ProvinceType.MOUNTAINOUS
		elif rand_roll < 45: # 20% chance for Forest
			new_province.type = Province.ProvinceType.FOREST
		else: # The rest are Plains
			new_province.type = Province.ProvinceType.PLAINS
		
		# --- NEW: Apply the automatic effects of the type ---
		# A mountainous province ALWAYS has a mine.
		if new_province.type == Province.ProvinceType.MOUNTAINOUS:
			if not new_province.buildings.has(Province.BuildingType.MINE):
				new_province.buildings.append(Province.BuildingType.MINE)
				
		var random_building_index = randi_range(1, 3)
		new_province.buildings.append(random_building_index)
		all_provinces.append(new_province)
		temp_provinces_by_id[p_data.provinceId] = new_province
	
	# --- PASS 2: Link all the neighbors ---
	# We must do this in a second pass, after all province objects exist.
	print("DEBUG: World Gen - Pass 2: Linking province neighbors...")
	for p_data in json_data.provinces:
		var current_province = temp_provinces_by_id[p_data.provinceId]
		# Loop through the neighbor IDs from the JSON (e.g., [1, 5])
		for neighbor_id in p_data.neighbors:
			# Find the actual Province object that corresponds to that ID
			var neighbor_province = temp_provinces_by_id[neighbor_id]
			# Use the add_neighbor method from your province.gd script
			current_province.add_neighbor(neighbor_province)
			
	print("DEBUG: World Gen - Map created and linked successfully.")
	return all_provinces
	
func find_kingdom_by_relationship(relationship_type: TargetRelationshipType) -> Kingdom:
	# --- The only check we need for the player is that their kingdom is valid ---
	if not is_instance_valid(player_kingdom):
		return null

	var potential_targets: Array[Kingdom] = []
	
	for kingdom in all_kingdoms:
		# --- Filter out invalid targets ---
		
		# 1. Can't target yourself
		if kingdom == player_kingdom:
			continue
			
		# 2. Can't target a kingdom without a ruler (still a good check)
		if not is_instance_valid(kingdom.ruler):
			continue
			
		# --- MODIFIED LOGIC: Get the kingdom-level relations value ---
		# We get the relations value from the player's kingdom dictionary,
		# using the target kingdom's ID as the key.
		# .get(key, 0) is a safe way to get the value, defaulting to 0 if the key doesn't exist.
		var kingdom_relations = player_kingdom.relations.get(kingdom.id, 0)
		
		# --- Apply the specific logic based on the requested type ---
		match relationship_type:
			TargetRelationshipType.FRIENDLY_NON_ALLY:
				# Condition: Relations must be high (e.g., > 30)
				# Condition: Must NOT already be an ally
				if kingdom_relations > 30 and not player_kingdom.allies.has(kingdom.id):
					potential_targets.append(kingdom)
					
			TargetRelationshipType.UNFRIENDLY_NON_RIVAL:
				# Condition: Relations must be low (e.g., < -30)
				# Condition: Must NOT already be a rival
				if kingdom_relations < -30 and not player_kingdom.rivals.has(kingdom.id):
					potential_targets.append(kingdom)
	
	# --- Return the result (no changes here) ---
	if potential_targets.is_empty():
		return null
	else:
		return potential_targets.pick_random()
		
func get_court_size(kingdom: Kingdom) -> int:
	if not is_instance_valid(kingdom):
		return 0
		
	var count = 0
	for character in all_characters_in_world:
		if character.is_alive and character.current_court == kingdom:
			count += 1
	return count
	
# --- NEW FUNCTION: Finds a kingdom object by its ID ---
func find_kingdom_by_id(kingdom_id: int) -> Kingdom:
	if _kingdom_id_map.has(kingdom_id):
		return _kingdom_id_map[kingdom_id]
	return null

func _annex_province(province_name_raw: String):
	# --- 1. Find the Province Object ---
	var target_province: Province = null
	# Make the search case-insensitive by converting both to lower case.
	var province_name_lower = province_name_raw.to_lower()
	
	target_province=find_province_by_name(province_name_lower)
	
	#var all_neighbouring_provinces=player_kingdom.get_neighboring_unowned_provinces()
	#for province in all_neighbouring_provinces:
		#if province.province_name.to_lower() == province_name_lower:
			#target_province = province
			#break # We found it, so we can stop searching.
			
	# --- 2. Validate the Target ---
	# Guard clause: Check if we actually found a province with that name.
	if not is_instance_valid(target_province):
		printerr("ANNEXATION FAILED: Could not find any province named '%s'." % province_name_raw)
		return

	# Guard clause: Check if the province is already owned. This is a crucial safety check.
	#if is_instance_valid(target_province.owner):
		#printerr("ANNEXATION FAILED: Province '%s' is already owned by %s." % [target_province.province_name, target_province.owner.kingdom_name])
		#return
		
	update_geopolitical_state(target_province, player_kingdom)
	
	# --- 4. Provide Feedback ---
	var log_message = "VICTORY: We have successfully annexed the province of %s!" % target_province.province_name
	print(log_message)
	# Add this to the monthly log so the player sees it in the summary.
	monthly_event_log.append(log_message)
	#GameManager.monthly_chronicle.kingdom_logs[player_kingdom].append(log_message)
	
	
# This should be called whenever a province changes owner, by player or AI.
func update_geopolitical_state(annexed_province: Province, new_owner: Kingdom):
	var original_owner = annexed_province.owner
	
	var log_message ="GEOPOLITICAL UPDATE: Province '%s' is now owned by %s." % [annexed_province.province_name, new_owner.kingdom_name]
	print(log_message)
	monthly_event_log.append(log_message)
	GameManager.monthly_chronicle.kingdom_logs[new_owner].append(log_message)
	# --- 1. The province is no longer "unowned". Its owner is now set. ---
	annexed_province.owner = new_owner
	
	# --- 2. Update the new owner's direct data ---
	# Add the province to their list of owned territories.
	if not new_owner.provinces_owned.has(annexed_province):
		new_owner.provinces_owned.append(annexed_province)
	
	# --- 3. Remove the province from the original owner's territory ---
	if is_instance_valid(original_owner):
		if original_owner.provinces_owned.has(annexed_province):
			original_owner.provinces_owned.erase(annexed_province)
			
	# --- 4. Iterate through ALL kingdoms to update their relationships ---
	for kingdom in all_kingdoms:
		# A) For the new owner, we don't need to update their relations with themselves.
		if kingdom == new_owner:
			continue
			
		# B) For ALL OTHER kingdoms, check if the annexed province was a neighbor.
		#    We get their list of unowned neighbors BEFORE the update.
		var unowned_neighbors = kingdom.get_neighboring_unowned_provinces()
		
		if unowned_neighbors.has(annexed_province):
			# This kingdom used to border the now-annexed province when it was empty.
			# This means this kingdom is NOW a direct neighbor of the 'new_owner'.
			print("  - %s now borders the %s via %s." % [kingdom.kingdom_name, new_owner.kingdom_name, annexed_province.province_name])

			# Establish a neutral or slightly negative starting relationship.
			# Only set it if one doesn't already exist.
			if not kingdom.relations.has(new_owner.id):
				kingdom.relations[new_owner.id] = -5
			if not new_owner.relations.has(kingdom.id):
				new_owner.relations[kingdom.id] = -5
				
		#5) For PREVIOUS owner, check if they have any provinces left.
		
		if is_instance_valid(original_owner):
		# If the original owner now has no provinces left, they are destroyed.
			if original_owner.provinces_owned.is_empty():
				_handle_kingdom_destruction_after_annexation(original_owner)
				
	_update_player_stats()

# --- HELPER FUNCTION to handle the destruction logic ---
func _handle_kingdom_destruction_after_annexation(destroyed_kingdom: Kingdom):
	var log_message="DESTRUCTION: %s has lost its last province and is collapsing." % destroyed_kingdom.kingdom_name
	print(log_message)
	GameManager.monthly_chronicle.kingdom_logs[destroyed_kingdom].append(log_message)
	# --- 1. Check for any wars this kingdom was in ---
	var war = WarManager.get_kingdom_war(destroyed_kingdom)
	if is_instance_valid(war):
		# The kingdom was at war when it collapsed.
		var opponent: Kingdom
		if war.attacker == destroyed_kingdom:
			opponent = war.defender
		else:
			opponent = war.attacker
		
		# Now, check if this was a war against the player.
		if opponent == player_kingdom:
			# --- Case 3: War with the Player ---
			# We don't trigger the event immediately. Instead, we set a flag.
			# The _check_for_critical_state_events will pick this up at the end of the turn.
			# This is handled by your existing logic.
			print("  - Destruction was against the player. Critical event will fire.")
			
		else:
			# --- Case 1: AI vs AI War ---
			# The war ends immediately. The opponent is the victor.
			print("  - Destruction was against another AI. Ending their war.")
			WarManager.end_war_total_victory(opponent, destroyed_kingdom, war)
			# The end_war function already adds a log message.
	else:
		# --- Case 2: Not in a War ---
		# The kingdom was not at war, it was likely annexed via a peaceful event
		# or the AI expansion into a one-province minor.
		# We just destroy the kingdom and add a log message.
		var log_msg = "The Kingdom of %s has collapsed after losing its last territory." % destroyed_kingdom.kingdom_name
		monthly_event_log.append(log_msg)
		GameManager.monthly_chronicle.critical_events.append(log_msg)
		destroy_kingdom(destroyed_kingdom)
		
						
func find_province_by_id(p_id: int) -> Province:
	for province in all_provinces_in_world:
		if province.id == p_id:
			return province
	return null
	
func find_province_by_name(p_name: String) -> Province:
	for province in all_provinces_in_world:
		if province.province_name.to_lower() == p_name.to_lower():
			return province
	return null
	
func _calculate_monthly_economy():
	# Loop through every single kingdom in the world
	for kingdom in all_kingdoms:
		# Reset the trackers for this month
		var gold_change = 0.0
		var food_change = 0
		
		var base_gold_income = 0.0
		var base_food_production = 0
		
		# --- 1. Calculate Income & Food Production ---
		for province in kingdom.provinces_owned:
			match province.type:
				Province.ProvinceType.BOUNTIFUL:
					food_change += FOOD_BONUS_BOUNTIFUL
				Province.ProvinceType.FOREST:
					gold_change += GOLD_BONUS_FOREST
				Province.ProvinceType.COASTAL_FISHING_VILLAGE:
					food_change += FOOD_BONUS_FISHING_VILLAGE
			for building in province.buildings:
				match building:
					Province.BuildingType.FARM:
						gold_change += INCOME_PER_FARM_GOLD
						food_change += FOOD_PER_FARM
					Province.BuildingType.MINE:
						gold_change += INCOME_PER_MINE_GOLD
					Province.BuildingType.GRANARY:
						food_change += FOOD_PER_GRANARY
			if province.is_coastal and province.type != Province.ProvinceType.COASTAL_FISHING_VILLAGE:
				gold_change += INCOME_PER_COASTAL_PROVINCE
# --- 2. Apply Bonuses from Active Modifiers ---
		# --- 2. Apply FLAT Bonuses from Modifiers ---
		var flat_modifier_gold_bonus = 0.0
		var flat_modifier_food_bonus = 0
		var flat_modifier_manpower_bonus = 0
		
		var families = _get_family_count(kingdom)
		flat_modifier_gold_bonus += families * TAX_PER_FAMILY
		
		for modifier in kingdom.active_modifiers:
			match modifier.id:
				"NewFarmlands":
					flat_modifier_gold_bonus += 5
					flat_modifier_food_bonus += 10
				"TextileGuild":
					flat_modifier_gold_bonus += 20
				"RoyalArmory":
					flat_modifier_manpower_bonus +=20
				"IrrigationCanals":
					# Each stack of this modifier provides a flat food bonus.
					flat_modifier_food_bonus += FOOD_BONUS_IRRIGATION
				#add other matches here	
					
			if modifier.id.begins_with("TradeDeal_"):
				if modifier.id.begins_with("TradeDeal_FoodForGold"):
					# We are selling food and getting gold
					food_change -= TRADE_DEAL_FOOD_AMOUNT
					gold_change += TRADE_DEAL_GOLD_AMOUNT
				elif modifier.id.begins_with("TradeDeal_GoldForFood"):
					# We are buying food with gold
					gold_change -= TRADE_DEAL_GOLD_AMOUNT
					food_change += TRADE_DEAL_FOOD_AMOUNT
				
				elif modifier.id.begins_with("TradeDeal_FoodForGold_Bad"):
					food_change -= TRADE_DEAL_FOOD_AMOUNT
					gold_change += 10 # A much worse rate
				elif modifier.id.begins_with("TradeDeal_GoldForFood_Bad"):
					gold_change -= 30 # A much worse rate
					food_change += TRADE_DEAL_FOOD_AMOUNT
		
		# Add the flat bonuses to the base income
		gold_change = base_gold_income + flat_modifier_gold_bonus
		food_change = base_food_production + flat_modifier_food_bonus
		
		# --- 3. NEW: Apply PERCENTAGE Bonuses/Penalties from Modifiers ---
		var percentage_modifier_gold_bonus = 0.0
		var percentage_modifier_food_bonus = 0
		
		for modifier in kingdom.active_modifiers:
			match modifier.id:
				"ImprovedTools":
					# This gives a 5% bonus to the BASE income from provinces
					percentage_modifier_gold_bonus += base_gold_income * 0.05
					percentage_modifier_food_bonus += base_food_production * 0.05

				# --- THE NEW MODIFIERS ---
				"SilkRoadPact":
					# This gives a 10% bonus to the kingdom's TOTAL income so far
					percentage_modifier_gold_bonus += gold_change * 0.10
				"PoorTradeReputation":
					# This gives a -5% penalty to the kingdom's TOTAL income so far
					percentage_modifier_gold_bonus -= gold_change * 0.05
				"GreatProject":
					percentage_modifier_gold_bonus -= gold_change * 0.10
					percentage_modifier_food_bonus += base_food_production * 0.10
				# -------------------------
		
		# Add the calculated percentage bonuses to the totals
		gold_change += percentage_modifier_gold_bonus
		food_change += percentage_modifier_food_bonus
		
		# --- 3. Calculate Expenses & Food Consumption ---
		# a) Province Maintenance
		var total_maintenance = 0
		for province in kingdom.provinces_owned:
			total_maintenance += province.maintenance_cost
		gold_change -= total_maintenance
		
		# b) Army Maintenance
		var army_cost = (float(kingdom.manpower) / 100.0) * COST_PER_100_MANPOWER
		gold_change -= army_cost #original cost too much
		
		# c) Food Consumption
		#food_change -= families * FOOD_COST_PER_FAMILY
		var court_size = get_court_size(kingdom) # You already have this function
		var food_cost = (float(court_size) / 10.0) * FOOD_COST_PER_10_PEOPLE
		food_change -= int(food_cost)
		# --- 4. Apply and Store Changes ---
		kingdom.treasury += gold_change
		kingdom.food += food_change
		
		# Store the calculated changes so the UI can display them
		kingdom.monthly_gold_change = gold_change
		kingdom.monthly_food_change = food_change


# --- HELPER to count families ---
func _get_family_count(kingdom: Kingdom) -> int:
	if not is_instance_valid(kingdom): return 0
	
	var count = 0
	for character in all_characters_in_world:
		# A "family" is any living, married woman in the court.
		# This counts each couple once.
		if character.is_alive and character.current_court == kingdom:
			if character.gender == Character.Gender.FEMALE and is_instance_valid(character.spouse):
				count += 1
	# The ruler's own family is also counted if they are married.
	return count


func form_alliance(k1: Kingdom, k2: Kingdom):
	if not k1.allies.has(k2.id):
		k1.allies.append(k2.id)
	if not k2.allies.has(k1.id):
		k2.allies.append(k1.id)
		
	# An alliance should remove any existing rivalry.
	if k1.rivals.has(k2.id):
		k1.rivals.erase(k2.id)
	if k2.rivals.has(k1.id):
		k2.rivals.erase(k1.id)

	var log_msg = "DIPLOMACY: The %s and the %s have formed an alliance!" % [k1.kingdom_name, k2.kingdom_name]
	monthly_event_log.append(log_msg)
	GameManager.monthly_chronicle.critical_events.append(log_msg)
	print("AI ACTION: ", log_msg)

# Creates a mutual rivalry between two kingdoms.
func declare_rivalry(k1: Kingdom, k2: Kingdom):
	if not k1.rivals.has(k2.id):
		k1.rivals.append(k2.id)
	if not k2.rivals.has(k1.id):
		k2.rivals.append(k1.id)
		
	# Declaring a rivalry should break any existing alliance.
	if k1.allies.has(k2.id):
		k1.allies.erase(k2.id)
	if k2.allies.has(k1.id):
		k2.allies.erase(k1.id)
		
	var log_msg = "DIPLOMACY: The %s and the %s have declared a formal rivalry!" % [k1.kingdom_name, k2.kingdom_name]
	monthly_event_log.append(log_msg)
	GameManager.monthly_chronicle.critical_events.append(log_msg)
	print("AI ACTION: ", log_msg)
	
# Finds all provinces owned by a specific kingdom that border another kingdom.
func get_border_provinces(owner_kingdom: Kingdom, bordering_kingdom: Kingdom) -> Array[Province]:
	var border_provinces: Array[Province] = []
	for province in owner_kingdom.provinces_owned:
		for neighbor in province.neighbors:
			if neighbor.owner == bordering_kingdom:
				if not border_provinces.has(province):
					border_provinces.append(province)
	return border_provinces
	
func get_owned_provinces(owner_kingdom: Kingdom) -> Array[Province]:
	return owner_kingdom.provinces_owned
	
func get_characters_in_court(kingdom: Kingdom) -> Array[Character]:
	if not is_instance_valid(kingdom):
		return []
	return all_characters_in_world.filter(func(c): return c.current_court == kingdom)
	
func _update_player_stats():
	if is_instance_valid(player_kingdom):
		peak_province_count = max(peak_province_count, player_kingdom.provinces_owned.size())
