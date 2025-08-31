extends Node

var active_wars: Array[War] = []



func declare_war(attacker: Kingdom, defender: Kingdom, target_province: Province):
	# ... check if neighbors ...
	var new_war = War.new(attacker, defender, target_province) # Assuming War has an _init method
	active_wars.append(new_war)
	print("%s has declared war on %s!" % [attacker.kingdom_name, defender.kingdom_name])
	
func update_monthly_warfare():
	var finished_wars: Array[War] = []
	for war in active_wars:
		# 1. Calculate battle outcome
		var attacker_strength = war.attacker.get_military_strength()
		var defender_strength = war.defender.get_military_strength()
		
		# --- 2. NEW: Apply Modifiers to Strength ---
		var attacker_modifier_bonus = 1.0 # Start with a multiplier of 1.0 (no change)
		var defender_modifier_bonus = 1.0
		
		# a) Check Attacker's Modifiers
		if war.attacker.has_modifier("HighMorale"):
			attacker_modifier_bonus += 0.10 # +10% strength
		if war.attacker.has_modifier("LowMorale"):
			attacker_modifier_bonus -= 0.10 # -10% strength
			
		# b) Check Defender's Modifiers
		if war.defender.has_modifier("HighMorale"):
			defender_modifier_bonus += 0.10
		if war.defender.has_modifier("LowMorale"):
			defender_modifier_bonus -= 0.10
		
		# c) Check for Border Fortifications
		# This is a special modifier that only helps the DEFENDER,
		# and only if the battle is "happening" on their fortified border.
		# The original_war_goal is a good proxy for the location of the main conflict.
		var fortified_border_modifier_id = "BorderFortifications_%d" % war.attacker.id
		if war.defender.has_modifier(fortified_border_modifier_id):
			# The defender has fortifications specifically against this attacker!
			defender_modifier_bonus += 0.20 # +20% strength for the defender
		
		# Apply the calculated multipliers to the final strength values.
		# We use max() to ensure a modifier can't reduce strength below a certain point (e.g., 50%).
		var final_attacker_strength = attacker_strength * max(0.5, attacker_modifier_bonus)
		var final_defender_strength = defender_strength * max(0.5, defender_modifier_bonus)
		
		# --- 3. Add Randomness and Determine Outcome ---
		attacker_strength = final_attacker_strength * randf_range(0.8, 1.2)
		defender_strength = final_defender_strength * randf_range(0.8, 1.2)
		
		var diff = attacker_strength - defender_strength
		var score_change = (diff / (attacker_strength + defender_strength)) * 20.0
		war.war_score = clampf(war.war_score + score_change, -100.0, 100.0)
		
# 2. Increase War Exhaustion
		# Losing battles and the passage of time makes a kingdom tired of war.
		if score_change > 0: # Attacker won
			war.defender_war_exhaustion += 2.0
			war.attacker_war_exhaustion += 1.0
		else: # Defender won
			war.attacker_war_exhaustion += 2.0
			war.defender_war_exhaustion += 1.0
			
		war.attacker_war_exhaustion = min(100.0, war.attacker_war_exhaustion)
		war.defender_war_exhaustion = min(100.0, war.defender_war_exhaustion)

		# 3. Check for automatic conclusion (total victory)
		if war.war_score >= 100:
			end_war_total_victory(war.attacker, war.defender, war)
			# ... remove war from active list
		elif war.war_score <= -100:
			end_war_total_victory(war.defender, war.attacker, war)
			# ... remove war from active list

	for finished_war in finished_wars:
		active_wars.erase(finished_war)

func _end_war(war: War, winner: Kingdom):
	var loser = war.defender if winner == war.attacker else war.attacker
	if winner == war.attacker:
		# Attacker wins, transfer province
		var target = war.war_goal
		loser.provinces_owned.erase(target)
		winner.provinces_owned.append(target)
		target.owner = winner
		print("%s has seized %s!" % [winner.kingdom_name, target.province_name])
		
		# Check for realm destruction
		if loser.provinces_owned.is_empty():
			GameManager.destroy_kingdom(loser)
	else:
		# Defender wins
		print("%s has defended their lands!" % winner.kingdom_name)
		
# Checks if the player's kingdom is currently involved in any active war.
# Returns: true if the player is at war, false otherwise.
func is_player_at_war() -> bool:
	# First, get a reference to the player's kingdom from the GameManager.
	# GameManager is the single source of truth for who the player is.
	var player_kingdom = GameManager.player_kingdom

	# A crucial safety check: If the player_kingdom hasn't been set yet
	# (e.g., the game is still loading), they can't be at war.
	if not is_instance_valid(player_kingdom):
		return false

	# Loop through every single active war in the simulation.
	for war in active_wars:
		# Check if the player's kingdom is either the attacker OR the defender.
		if war.attacker == player_kingdom or war.defender == player_kingdom:
			# If we find even one war they are in, we know the answer is true.
			# We can stop searching and return immediately for efficiency.
			return true

	# If the loop finishes without finding any war involving the player,
	# then we know they are not at war.
	return false
	
func is_kingdom_at_war(kingdom_to_check: Kingdom) -> bool:
	if not is_instance_valid(kingdom_to_check):
		return false

	for war in active_wars:
		if war.attacker == kingdom_to_check or war.defender == kingdom_to_check:
			return true

	return false
	
func get_player_war() -> War:
	var player_k = GameManager.player_kingdom
	for war in active_wars:
		if war.attacker == player_k or war.defender == player_k:
			return war
	return null
	
func get_player_war_opponent() -> Kingdom:
	var player_k = GameManager.player_kingdom
	for war in active_wars:
		if war.attacker == player_k:
			return war.defender
		elif war.defender == player_k:
			return war.attacker
	return null
	
# Generic version of get_player_war
func get_kingdom_war(kingdom_to_check: Kingdom) -> War:
	if not is_instance_valid(kingdom_to_check):
		return null
	for war in active_wars:
		if war.attacker == kingdom_to_check or war.defender == kingdom_to_check:
			return war
	return null
	
# --- NEW: Function for when a side gives up before total defeat ---
# This is called by the AIManager for an AI, or by a player event outcome.
func _handle_war_end_by_surrender(winner: Kingdom, loser: Kingdom, war: War):
	var log_msg_base = "The war between %s and %s has ended. %s has surrendered." % [winner.kingdom_name, loser.kingdom_name, loser.kingdom_name]
	
	# --- Determine the terms of surrender based on the loser's state ---
	
	# Check if the loser has more than one province left.
	if loser.provinces_owned.size() > 1:
		# Loser has land to give. They will cede the original war goal province.
		var province_to_cede = war.original_war_goal
		
		# A safety check to make sure the loser still owns the war goal.
		# If they lost it in a raid, we pick another border province.
		if not loser.provinces_owned.has(province_to_cede):
			var border_provinces = GameManager.get_border_provinces(loser, winner)
			if not border_provinces.is_empty():
				province_to_cede = border_provinces.pick_random()
			else:
				# This is a rare edge case where they have no border provinces left.
				# We'll default to taking resources instead.
				_handle_resource_transfer(winner, loser)
				return # Exit early
		
		# Execute the land transfer using our master geopolitical function.
		GameManager.update_geopolitical_state(province_to_cede, winner)
		
		var log_msg_details = "The %s has ceded the province of %s to the %s." % [loser.kingdom_name, province_to_cede.province_name, winner.kingdom_name]
		GameManager.monthly_event_log.append(log_msg_base)
		GameManager.monthly_event_log.append(log_msg_details)
		print("WAR END (SURRENDER): ", log_msg_details)

	else:
		# Loser only has their capital left. They must give resources.
		_handle_resource_transfer(winner, loser)

	# Finally, remove the war from the list of active wars.
	if active_wars.has(war):
		active_wars.erase(war)
	
# This is called when war score reaches 100/-100 or the last province is taken.
func end_war_total_victory(winner: Kingdom, loser: Kingdom, war: War):
	var log_msg_base = "A total victory! The %s has been utterly defeated by the %s." % [loser.kingdom_name, winner.kingdom_name]
	GameManager.monthly_event_log.append(log_msg_base)
	print("WAR END (TOTAL VICTORY): ", log_msg_base)
	
	# --- The loser is completely annexed ---
	# We create a copy of the province list because we will be modifying it.
	var provinces_to_annex = loser.provinces_owned.duplicate()
	for province in provinces_to_annex:
		GameManager.update_geopolitical_state(province, winner)
	
	# The loser's kingdom is destroyed.
	GameManager.destroy_kingdom(loser)
	
	# Remove the war from the active list.
	if active_wars.has(war):
		active_wars.erase(war)


# --- NEW: Helper function for handling resource transfers ---
# This is used in both surrender and potentially other peace deals.
func _handle_resource_transfer(winner: Kingdom, loser: Kingdom):
	var gold_transfer = int(loser.treasury / 2.0)
	var manpower_transfer = int(loser.manpower / 2.0)
	
	# Perform the transfer
	loser.treasury -= gold_transfer
	winner.treasury += gold_transfer
	
	loser.manpower -= manpower_transfer
	winner.manpower += manpower_transfer
	# Clamp manpower to prevent negative values on the loser's side
	loser.manpower = max(0, loser.manpower)
	
	var log_msg = "As tribute, the %s pays %d gold and provides %d men to the %s." % [loser.kingdom_name, gold_transfer, manpower_transfer, winner.kingdom_name]
	GameManager.monthly_event_log.append(log_msg)
	print("WAR END (RESOURCE TRANSFER): ", log_msg)

func enact_surrender(loser: Kingdom, war: War):
	print("WarManager: Enacting surrender for %s." % loser.kingdom_name)

	# Safety check
	if not is_instance_valid(loser) or not is_instance_valid(war):
		printerr("enact_surrender called with invalid arguments.")
		return
		
	# Determine the winner
	var winner: Kingdom
	if war.attacker == loser:
		winner = war.defender
	else:
		winner = war.attacker
		
	# Now, call our internal, private function to handle the details.
	_handle_war_end_by_surrender(winner, loser, war)
