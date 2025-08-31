extends Node

# --- Constants for easy balancing ---
const COLONIZATION_COST_GOLD = 100
const COLONIZATION_COST_MANPOWER = 100
const MIN_TREASURY_TO_EXPAND = 200 # An AI won't bankrupt itself to expand

const ALLIANCE_THRESHOLD = 80
const RIVALRY_THRESHOLD = -60

var debug_force_player_victory_surrender: bool = false

# This is the main function the GameManager will call.
func simulate_ai_turns():
	# Loop through every kingdom in the world.
	for kingdom in GameManager.all_kingdoms:
		# --- IMPORTANT: Skip the player's kingdom! ---
		if kingdom == GameManager.player_kingdom:
			continue
		
		# Process this AI kingdom's turn
		_process_ai_kingdom_turn(kingdom)


# Handles all decisions for a single AI kingdom for one month.
func _process_ai_kingdom_turn(kingdom: Kingdom):
	var war = WarManager.get_kingdom_war(kingdom)
	if is_instance_valid(war):
		# --- If at war, run wartime logic ---
		if _handle_ai_surrender_check(kingdom, war):
			return # The kingdom surrendered, their turn is over.
		_handle_ai_wartime_opportunism(kingdom) # Your existing land grab function
	else:
		_handle_ai_wartime_opportunism(kingdom)
		_handle_ai_expansion(kingdom)
		_handle_ai_war_declaration(kingdom)
	_handle_ai_court_marriages(kingdom)
	_handle_ai_relations(kingdom)
	
func check_if_ai_will_surrender(kingdom, war) -> bool:
	if debug_force_player_victory_surrender:
		print("DEBUG: Forcing AI surrender due to debug flag.")
		# CRITICAL: Reset the flag so it only works once.
		debug_force_player_victory_surrender = false
		return true
		
	if _handle_ai_surrender_check(kingdom, war):
		true
	else:
		false
	return false
# The core logic for an AI deciding to expand into empty land.
func _handle_ai_expansion(kingdom: Kingdom):
	# --- 1. Check Preconditions ---
	# Don't expand if the kingdom is poor.
	if kingdom.treasury < MIN_TREASURY_TO_EXPAND:
		return
	elif kingdom.manpower < COLONIZATION_COST_MANPOWER:
		return
		
	# Don't expand if the kingdom is at war.
	if WarManager.is_kingdom_at_war(kingdom): # We will need to create this helper
		return
		
	# --- 2. Find Opportunities ---
	# Get a list of adjacent, unowned provinces.
	var available_lands = kingdom.get_neighboring_unowned_provinces()
	if available_lands.is_empty():
		return # No place to expand.
		
	# --- 3. Decide IF to Expand (Personality Check) ---
	var ruler = kingdom.ruler
	var base_expansion_chance = ruler.expansion_desire
	var final_expansion_chance = base_expansion_chance
	
	# --- NEW: Modify chance based on personality ---
	match ruler.personality:
		Character.CharacterPersonality.WARLORD:
			final_expansion_chance += 20 # Warlords are very expansionist
		Character.CharacterPersonality.STUBBORN:
			final_expansion_chance += 10
		Character.CharacterPersonality.SHY, Character.CharacterPersonality.WEAK:
			final_expansion_chance -= 30 # Shy/Weak rulers rarely expand
			
	# Clamp the value to a reasonable range (0-95%)
	final_expansion_chance = clampi(final_expansion_chance, 0, 95)
	
	# Roll the dice using the final, modified chance.
	if randi() % 100 < final_expansion_chance:
		# --- 4. Execute the Expansion ---
		# Pick one of the available lands at random.
		var target_province = available_lands.pick_random()
		
		# Pay the cost.
		kingdom.treasury -= COLONIZATION_COST_GOLD
		kingdom.manpower -= COLONIZATION_COST_MANPOWER
		
		#update ownership
		GameManager.update_geopolitical_state(target_province, kingdom)
		
		# Log this event so the player sees it in the monthly summary!
		var log_message = "%s has peacefully expanded, claiming the province of %s." % [kingdom.kingdom_name, target_province.province_name]
		GameManager.monthly_event_log.append(log_message)
		GameManager.monthly_chronicle.kingdom_logs[kingdom].append(log_message)
		GameManager.monthly_chronicle.critical_events.append(log_message)
		print("AI ACTION: ", log_message)
		
	
# Example of a new AI action: Declaring War
func _handle_ai_war_declaration(kingdom: Kingdom):
	var ruler = kingdom.ruler
	
	# Warlords and Ruthless rulers are the most likely to start wars.
	# Others might never do it.
	var will_declare_war = false
	match ruler.personality:
		Character.CharacterPersonality.WARLORD:
			if randf() < 0.25: will_declare_war = true # 25% chance each month
		Character.CharacterPersonality.RUTHLESS:
			if randf() < 0.10: will_declare_war = true # 10% chance each month
		_:
			# All other personalities will not start wars in this simple model
			pass 
			
	if will_declare_war:
		# Find a valid target (e.g., a weaker, non-allied neighbor)
		var target = _find_weakest_neighbor(kingdom)
		if is_instance_valid(target):
			# WarManager.declare_war(kingdom, target, target_province_goal)
			print("AI ACTION: %s (%s) has declared war on %s!" % [ruler.full_name, ruler.personality, target.kingdom_name])


func _find_weakest_neighbor(kingdom: Kingdom) -> Kingdom:
	var best_target: Kingdom = null
	var lowest_strength_score = INF # Start with an infinitely high score

	# 1. Get a list of all neighboring kingdoms.
	var neighbors = kingdom.get_neighboring_kingdoms()
	if neighbors.is_empty():
		return null # No neighbors to attack.

	# 2. Loop through each neighbor to evaluate them as a potential target.
	for neighbor in neighbors:
		# --- A series of checks to disqualify bad targets ---
		
		# a) Don't attack an ally.
		if kingdom.allies.has(neighbor.id):
			continue
			
		# b) Don't attack someone much stronger.
		#    We get the military strength, which is a calculation based on manpower,
		#    treasury, and the ruler's martial skill.
		var kingdom_strength = kingdom.get_military_strength()
		var neighbor_strength = neighbor.get_military_strength()
		
		# The AI will only attack if its strength is at least 120% of the neighbor's.
		# This prevents suicidal wars.
		if kingdom_strength < (neighbor_strength * 1.2):
			continue
			
		# c) Don't attack a kingdom that has powerful allies.
		#    We need to check the strength of the neighbor AND their allies.
		var total_defensive_strength = neighbor_strength
		for ally_id in neighbor.allies:
			var ally_kingdom = GameManager.find_kingdom_by_id(ally_id)
			if is_instance_valid(ally_kingdom):
				total_defensive_strength += ally_kingdom.get_military_strength()
		
		# Re-run the strength check against the entire defensive pact.
		if kingdom_strength < (total_defensive_strength * 1.2):
			continue

		# --- If the target is valid, see if it's the weakest we've found so far ---
		
		# We use the total defensive strength as our score. The lower, the better.
		if total_defensive_strength < lowest_strength_score:
			lowest_strength_score = total_defensive_strength
			best_target = neighbor

	# 3. After checking all neighbors, return the best target we found.
	#    If no valid targets were found, this will still be null.
	return best_target

# This would be called from _process_ai_kingdom_turn for each kingdom
func _handle_ai_relations(kingdom: Kingdom):
	var ruler = kingdom.ruler
	if not is_instance_valid(ruler):
		return

	# Each turn, an AI ruler interacts with ONE other random ruler.
	# This prevents the log from being spammed with dozens of relation changes per turn.
	
	# 1. Find a valid target to interact with.
	var other_kingdoms = GameManager.all_kingdoms.filter(func(k): return k != kingdom)
	if other_kingdoms.is_empty():
		return # No one else to interact with.
		
	var target_kingdom = other_kingdoms.pick_random()
	var target_ruler = target_kingdom.ruler
	if not is_instance_valid(target_ruler):
		return

	# --- 2. Calculate the "Drift" based on personalities ---
	# This is the core logic. We calculate a change value.
	var relation_change = 0
	var opinion_change = 0

	# --- Part A: Ruler's Personality ---
	# How does the active ruler's personality affect their view of the target?
	match ruler.personality:
		Character.CharacterPersonality.FRIENDLY:
			relation_change += randi_range(1, 3) # Friendly rulers tend to improve relations.
			opinion_change += randi_range(1, 5)  # And form positive personal opinions.
		Character.CharacterPersonality.RUTHLESS:
			relation_change -= randi_range(0, 2) # Ruthless rulers see others as pawns.
			# They respect strength, despise weakness.
			opinion_change += (target_ruler.martial - ruler.martial) # Compare martial skill
		Character.CharacterPersonality.WARLORD:
			relation_change -= randi_range(1, 3) # Warlords see neighbors as future conquests.
			# They only respect high martial skill in others.
			if target_ruler.martial > 7: opinion_change += randi_range(0, 3)
			else: opinion_change -= randi_range(1, 4)
		Character.CharacterPersonality.CHARMING:
			# Charming rulers are good at making friends, improving relations.
			relation_change += randi_range(0, 2)
			opinion_change += randi_range(1, 4) + ruler.charisma # Their charisma naturally helps
		Character.CharacterPersonality.CUNNING:
			# Cunning rulers are suspicious.
			relation_change -= randi_range(0, 1)
			# They respect high intrigue.
			if target_ruler.intrigue > ruler.intrigue: opinion_change += randi_range(0, 2)
			else: opinion_change -= randi_range(0, 2)
		Character.CharacterPersonality.SHY, Character.CharacterPersonality.WEAK:
			# Shy/Weak rulers don't interact much, leading to slow decay.
			relation_change -= randi_range(0, 1)
		_:
			# Default behavior for STUBBORN, STRONG, etc. is a slight random drift.
			relation_change += randi_range(-1, 1)
			opinion_change += randi_range(-2, 2)

	# --- Part B: Target Ruler's Personality ---
	# The target's personality also affects the relationship, but usually less.
	match target_ruler.personality:
		Character.CharacterPersonality.FRIENDLY:
			relation_change += randi_range(0, 1)
		Character.CharacterPersonality.STUBBORN, Character.CharacterPersonality.RUTHLESS:
			relation_change -= randi_range(0, 2) # Difficult personalities erode relations.

	# --- 3. Apply the Changes ---
	
	# Update Kingdom Relations (Symmetrical)
	var current_relations = kingdom.relations.get(target_kingdom.id, 0)
	var new_relations = clampi(current_relations + relation_change, -100, 100)
	kingdom.relations[target_kingdom.id] = new_relations
	target_kingdom.relations[kingdom.id] = new_relations # Make it mutual
	
	# Update Ruler Opinion (Asymmetrical)
	var current_opinion = ruler.opinion_of.get(target_ruler.id, 0)
	var new_opinion = clampi(current_opinion + opinion_change, -100, 100)
	ruler.opinion_of[target_ruler.id] = new_opinion
	
	if abs(relation_change) > 2:
		var log_msg = "Relations have shifted between %s and %s (Now at %d)" % [kingdom.kingdom_name, target_kingdom.kingdom_name, kingdom.relations[target_kingdom.id] ]
		GameManager.monthly_event_log.append(log_msg)
		GameManager.monthly_chronicle.kingdom_logs[kingdom].append(log_msg)
		GameManager.monthly_chronicle.kingdom_logs[target_kingdom].append(log_msg)
	
	if new_relations >= ALLIANCE_THRESHOLD and not kingdom.allies.has(target_kingdom.id):
		# Form the alliance! We also need to consider the personality of the ruler.
		# A Warlord might be friendly but still refuse an alliance.
		var will_ally = true
		match kingdom.ruler.personality:
			Character.CharacterPersonality.WARLORD, Character.CharacterPersonality.RUTHLESS:
				# Warlords are less likely to form alliances, even with friends.
				if randf() > 0.3: # Only a 30% chance to agree
					will_ally = false
		
		if will_ally:
			GameManager.form_alliance(kingdom, target_kingdom)
			var log_msg = "%s and %s are now staunch allies." % [kingdom.kingdom_name, target_kingdom.kingdom_name]
			GameManager.monthly_event_log.append(log_msg)
			GameManager.monthly_chronicle.critical_events.append(log_msg)
			
	# b) Check for Rivalry Declaration
	# Condition: Relations are very low AND they are not already rivals.
	if new_relations <= RIVALRY_THRESHOLD and not kingdom.rivals.has(target_kingdom.id):
		# Declare the rivalry! Some personalities are quicker to do this.
		var will_rival = true
		match kingdom.ruler.personality:
			Character.CharacterPersonality.FRIENDLY, Character.CharacterPersonality.SHY:
				# Friendly rulers are hesitant to declare formal rivalries.
				if randf() > 0.2: # Only a 20% chance to make it official
					will_rival = false

		if will_rival:
			GameManager.declare_rivalry(kingdom, target_kingdom)
			var log_msg = "%s and %s are now sworn enemies." % [kingdom.kingdom_name, target_kingdom.kingdom_name]
			GameManager.monthly_event_log.append(log_msg)
			GameManager.monthly_chronicle.critical_events.append(log_msg)
			

# --- NEW: AI function for opportunistic land grabs during war ---
func _handle_ai_wartime_opportunism(kingdom: Kingdom):
	# 1. Check if the kingdom is at war.
	var war = WarManager.get_kingdom_war(kingdom) # We need a generic version of get_player_war
	if not is_instance_valid(war):
		return # Not at war, do nothing.
		
	# 2. Determine who the enemy is.
	var enemy_kingdom: Kingdom
	if war.attacker == kingdom:
		enemy_kingdom = war.defender
	else:
		enemy_kingdom = war.attacker
		
	# 3. Personality Check: Only aggressive personalities will attempt this.
	var ruler = kingdom.ruler
	var chance_to_attempt = 0.0
	match ruler.personality:
		Character.CharacterPersonality.WARLORD:
			chance_to_attempt = 0.30 # 30% chance each month
		Character.CharacterPersonality.RUTHLESS, Character.CharacterPersonality.CUNNING:
			chance_to_attempt = 0.15 # 15% chance
		_:
			return # Other personalities are too cautious.

	if randf() > chance_to_attempt:
		return # Decided not to try this month.
		
	# 4. Find a valid target province to steal.
	# We want a border province owned by the main enemy OR any of their allies at war with us.
	var valid_target_provinces: Array[Province] = []
	# a) Get provinces from the main enemy
	valid_target_provinces.append_array(GameManager.get_border_provinces(enemy_kingdom, kingdom))
	# b) Get provinces from the enemy's allies
	for ally_id in enemy_kingdom.allies:
		var ally_kingdom = GameManager.find_kingdom_by_id(ally_id)
		# Make sure the ally is actually in the war (this would be a more advanced check)
		if is_instance_valid(ally_kingdom):
			valid_target_provinces.append_array(GameManager.get_border_provinces(ally_kingdom, kingdom))

	if valid_target_provinces.is_empty():
		return # No valid border provinces to attack.
		
	var target_province = valid_target_provinces.pick_random()

	# 5. Calculate Success Chance (using the same logic as the player's event)
	var manpower_advantage = kingdom.manpower - enemy_kingdom.manpower
	var base_chance = 50 + (manpower_advantage / 100.0)
	var random_factor = randi_range(-15, 15)
	var personality_bonus = 0
	match ruler.personality:
		Character.CharacterPersonality.WARLORD: personality_bonus = 10
		Character.CharacterPersonality.RUTHLESS: personality_bonus = 5
		
	var final_chance = clampi(base_chance + random_factor + personality_bonus, 5, 95)
	
	# 6. Roll the dice and execute the outcome.
	if randi() % 100 <= final_chance:
		# --- SUCCESS ---
		var casualties = randi_range(250, 400)
		kingdom.manpower -= casualties
		
		var original_owner = target_province.owner
		
		# Use our master function to handle the geopolitical shift!
		GameManager.update_geopolitical_state(target_province, kingdom)
		
		# Log the event for the player to see!
		var log_msg = "WAR: The %s has launched a successful raid, seizing %s from The %s!" % [kingdom.kingdom_name, target_province.province_name, original_owner.kingdom_name]
		GameManager.monthly_event_log.append(log_msg)
		GameManager.monthly_chronicle.kingdom_logs[kingdom].append(log_msg)
		print("AI ACTION: ", log_msg)
	else:
		# --- FAILURE ---
		var casualties = randi_range(600, 800)
		kingdom.manpower -= casualties
		
		var log_msg = "WAR: A raid by The %s on the province of %s was repulsed with heavy losses." % [kingdom.kingdom_name, target_province.province_name]
		GameManager.monthly_event_log.append(log_msg)
		GameManager.monthly_chronicle.kingdom_logs[kingdom].append(log_msg)
		print("AI ACTION: ", log_msg)
		
# --- NEW: AI function to check for surrender ---
func _handle_ai_surrender_check(kingdom: Kingdom, war: War) -> bool:
	var ruler = kingdom.ruler
	var exhaustion = war.defender_war_exhaustion if war.attacker == kingdom else war.attacker_war_exhaustion
	var strength_ratio = kingdom.get_military_strength() / (war.attacker.get_military_strength() + war.defender.get_military_strength())
	
	# Calculate "will to fight"
	var will_to_fight = 100.0 - exhaustion - (kingdom.treasury / 100.0)
	
	print ("Checking surrender status")
	# Personality modifier
	match ruler.personality:
		Character.CharacterPersonality.STUBBORN, Character.CharacterPersonality.WARLORD:
			will_to_fight += 30
			print ("AI is stubborn / warlord +30 will to fight")
		Character.CharacterPersonality.WEAK, Character.CharacterPersonality.SHY:
			will_to_fight -= 40
			print ("AI is weak / shy -40 will to fight")
			
	# If will to fight is very low, they surrender.
	print ("final will to fight:",will_to_fight)
	if will_to_fight < 10:
		var winner = war.defender if war.attacker == kingdom else war.attacker
		print("surrendering.")
		WarManager.Enact_surrender(winner, kingdom, war)
		return true # Surrendered
		
	print("fighting on.")	
	return false

func _handle_ai_court_marriages(kingdom: Kingdom):
	# To avoid too many calculations per turn, we'll only try to marry off
	# one or two couples per kingdom per month.
	var marriage_attempts = randi_range(1, 2)
	
	for i in range(marriage_attempts):
		# --- 1. Find all eligible bachelors and bachelorettes in THIS court ---
		var bachelors: Array[Character] = []
		var bachelorettes: Array[Character] = []
		
		# We need to get a list of all characters in this specific court
		var courtiers = GameManager.get_characters_in_court(kingdom) # New helper needed
		
		for courtier in courtiers:
			if not is_instance_valid(courtier.spouse): # Must be unmarried
				var age = courtier.get_age()
				if courtier.gender == Character.Gender.MALE and age >= 18:
					bachelors.append(courtier)
				elif courtier.gender == Character.Gender.FEMALE and age >= 16:
					bachelorettes.append(courtier)
					
		# If there's no one to marry, we can't do anything.
		if bachelors.is_empty() or bachelorettes.is_empty():
			return # No possible couples in this court.
			
		# --- 2. Pick a random bachelor and find the "best" match for him ---
		var suitor = bachelors.pick_random()
		var best_match: Character = null
		var highest_score = -INF
		
		for potential_partner in bachelorettes:
			# Don't marry close relatives!
			if GameManager._is_closely_related(suitor, potential_partner):
				continue
				
			# --- 3. Score the potential match ---
			# The AI ruler's personality influences what they look for in a match for their court.
			var score = 0
			var ruler_personality = kingdom.ruler.personality
			
			match ruler_personality:
				Character.CharacterPersonality.WARLORD, Character.CharacterPersonality.STRONG:
					# Warlords value strong heirs
					score += potential_partner.vigor * 3
					score += potential_partner.martial * 2
				Character.CharacterPersonality.CUNNING, Character.CharacterPersonality.RUTHLESS:
					# Cunning rulers value intrigue and useful connections
					score += potential_partner.intrigue * 3
					score += potential_partner.diplomacy
				Character.CharacterPersonality.FRIENDLY, Character.CharacterPersonality.CHARMING:
					# Friendly rulers value charisma and good relationships
					score += potential_partner.charisma * 2
					score += potential_partner.diplomacy * 2
				_:
					# Default: a balanced appreciation for all stats
					score += potential_partner.vigor + potential_partner.diplomacy + potential_partner.charisma
			
			# Add a bit of randomness so it's not always the same choice
			score += randi_range(-5, 5)
			
			if score > highest_score:
				highest_score = score
				best_match = potential_partner
				
		# --- 4. If a match was found, perform the marriage ---
		if is_instance_valid(best_match):
			suitor.spouse = best_match
			best_match.spouse = suitor
			
			# Log the event for the player's summary
			var log_msg = "A marriage has been arranged in the court of %s between %s and %s." % [kingdom.kingdom_name, suitor.full_name, best_match.full_name]
			GameManager.monthly_event_log.append(log_msg)
			GameManager.monthly_chronicle.kingdom_logs[kingdom].append(log_msg)
			print("AI ACTION: ", log_msg)
