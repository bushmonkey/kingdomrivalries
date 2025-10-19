extends Node

signal battle_concluded(results)

var attacker_army: BattleArmy
var defender_army: BattleArmy
var current_turn_army: BattleArmy

# This will hold the AI's chosen unit during its turn.
var ai_chosen_attacker: BattleUnit = null
var ai_chosen_defender: BattleUnit = null
var player_chosen_defender: BattleUnit = null
var pre_combat_attacker_count: int = 0
var pre_combat_defender_count: int = 0
var calculated_attacker_casualties: int = 0
var calculated_defender_casualties: int = 0

func conclude_battle(victor: Kingdom, loser: Kingdom):
	print("BattleManager: Battle concluded. Victor: ", victor.kingdom_name)
	
	# 1. Calculate the final results.
	var attacker_casualties = attacker_army.kingdom.manpower - attacker_army.get_total_troops()
	var defender_casualties = defender_army.kingdom.manpower - defender_army.get_total_troops()
	
	# Apply the final manpower changes.
	attacker_army.kingdom.manpower -= attacker_casualties
	defender_army.kingdom.manpower -= defender_casualties
	
	# Calculate the War Score change. A decisive victory is a big swing.
	var war_score_change = 30.0
	if victor == defender_army.kingdom:
		war_score_change = -30.0

	# 2. Package the results into a dictionary.
	var results = {
		"victor": victor,
		"loser": loser,
		"attacker_casualties": attacker_casualties,
		"defender_casualties": defender_casualties,
		"war_score_change": war_score_change
	}
	
	# 3. Emit the signal to notify any listeners (like the WarManager).
	emit_signal("battle_concluded", results)
	
	# 4. Return to the main game view.
	get_tree().change_scene_to_file("res://scenes/main/main_view.tscn")
	
# This is called by WarManager to start the battle
func start_battle(attacker: Kingdom, defender: Kingdom):
	self.attacker_army = BattleArmy.new(attacker)
	self.defender_army = BattleArmy.new(defender)
	
	# Determine who goes first
	var attacker_initiative = attacker.ruler.martial
	var defender_initiative = defender.ruler.martial
	if attacker.ruler.personality in [Character.CharacterPersonality.WARLORD, Character.CharacterPersonality.RUTHLESS]:
		attacker_initiative += 3
		
	if attacker_initiative >= defender_initiative:
		current_turn_army = attacker_army
	else:
		current_turn_army = defender_army
		
	# Now, switch to the battle scene
	get_tree().change_scene_to_file("res://scenes/war/battle_view.tscn")

func simulate_ai_battle(kingdom_a: Kingdom, kingdom_b: Kingdom):
	print("SIMULATING AI BATTLE: %s vs %s" % [kingdom_a.kingdom_name, kingdom_b.kingdom_name])
	
	# 1. Assemble the armies.
	var army_a = BattleArmy.new(kingdom_a)
	var army_b = BattleArmy.new(kingdom_b)
	
	var rounds = 0
	const MAX_ROUNDS = 10 # A failsafe to prevent infinite loops
	
	# 2. Simulate rounds of combat until one side is defeated.
	while army_a.get_total_troops() > 0 and army_b.get_total_troops() > 0 and rounds < MAX_ROUNDS:
		# In each round, both sides attack.
		
		# a) Army A attacks Army B
		var attacker_a = get_ai_attack_choice(army_a)
		var defender_b = get_ai_defense_choice(army_b, attacker_a)
		if is_instance_valid(attacker_a) and is_instance_valid(defender_b):
			resolve_combat(attacker_a, defender_b,true)
		
		# b) Army B attacks Army A
		var attacker_b = get_ai_attack_choice(army_b)
		var defender_a = get_ai_defense_choice(army_a, attacker_b)
		if is_instance_valid(attacker_b) and is_instance_valid(defender_a):
			resolve_combat(attacker_b, defender_a,true)
			
		rounds += 1

	# 3. Determine the victor and calculate results.
	var victor = kingdom_a if army_a.get_total_troops() > 0 else kingdom_b
	var loser = kingdom_b if army_a.get_total_troops() > 0 else kingdom_a
	
	var casualties_a = kingdom_a.manpower - army_a.get_total_troops()
	var casualties_b = kingdom_b.manpower - army_b.get_total_troops()
	
	# Apply final manpower changes
	kingdom_a.manpower = army_a.get_total_troops()
	kingdom_b.manpower = army_b.get_total_troops()

	# 4. Return the results in a dictionary, just like the player battle.
	var results = {
		"victor": victor,
		"loser": loser,
		"attacker_casualties": casualties_a if victor == kingdom_b else casualties_b, # Simplified
		"defender_casualties": casualties_b if victor == kingdom_b else casualties_a, # Simplified
		"war_score_change": 30.0 if victor == kingdom_a else -30.0 # Assuming A was the original attacker
	}
	
	print("  - Battle Simulation Complete. Victor: ", victor.kingdom_name)
	return results
	
# This is the core rock-paper-scissors logic
func resolve_combat(attacker_unit: BattleUnit, defender_unit: BattleUnit,is_simulation: bool = false):
	var attacker_type = attacker_unit.unit_type
	var defender_type = defender_unit.unit_type

	var attacker_start_count = float(attacker_unit.count)
	var defender_start_count = float(defender_unit.count)
	
	var damage_multiplier = 1.0 # Default damage
	
	match attacker_type:
		BattleUnit.UnitType.KNIGHT:
			damage_multiplier = 2.5 # Strong against everything
		BattleUnit.UnitType.CANNON:
			if defender_type in [BattleUnit.UnitType.PIKEMAN, BattleUnit.UnitType.FOOT_SOLDIER]:
				damage_multiplier = 3.0
			if defender_type == BattleUnit.UnitType.CAVALRY:
				damage_multiplier = 0.2 # Very weak vs cavalry
		BattleUnit.UnitType.CAVALRY:
			if defender_type in [BattleUnit.UnitType.CANNON, BattleUnit.UnitType.FOOT_SOLDIER]:
				damage_multiplier = 2.0
			if defender_type == BattleUnit.UnitType.PIKEMAN:
				damage_multiplier = 0.3 # Very weak vs pikemen
		BattleUnit.UnitType.PIKEMAN:
			if defender_type == BattleUnit.UnitType.CAVALRY:
				damage_multiplier = 3.5
			if defender_type == BattleUnit.UnitType.FOOT_SOLDIER:
				damage_multiplier = 1.2
		BattleUnit.UnitType.FOOT_SOLDIER:
			damage_multiplier = 1.0

		BattleUnit.UnitType.ARCHER:
			# Strong against all traditional infantry and cavalry
			if defender_type in [BattleUnit.UnitType.FOOT_SOLDIER, BattleUnit.UnitType.CAVALRY, BattleUnit.UnitType.PIKEMAN]:
				damage_multiplier = 2.5
			# Less effective against heavily armored Knights
			if defender_type == BattleUnit.UnitType.KNIGHT:
				damage_multiplier = 0.8
			# Ineffective against fortifications (represented by Cannon)
			if defender_type == BattleUnit.UnitType.CANNON:
				damage_multiplier = 0.5
				
	if defender_type == BattleUnit.UnitType.ARCHER:
		# If attacked by anything other than other archers, they take extra damage.
		if attacker_type != BattleUnit.UnitType.ARCHER:
			# We can do this by multiplying the final damage later, or by
			# adjusting the attacker's damage multiplier here. Let's do the latter.
			damage_multiplier *= 2.0 # The attacker's damage is doubled against archers.
			
# --- 3. THE NEW DAMAGE FORMULA ---
	
	# a) Calculate Attacker's "Power". Let's say 20% of their troops deal damage.
	var attacker_power = attacker_start_count * 0.20
	
	# b) Calculate Defender's "Toughness". This is how much damage they absorb.
	#    Let's say their toughness is 10% of their numbers.
	var defender_toughness = defender_start_count * 0.10
	
	# c) Calculate raw damage dealt by the attacker, including the RPS multiplier.
	var raw_damage = attacker_power * damage_multiplier
	
	# d) The final damage is the raw damage minus the defender's toughness.
	var final_damage_to_defender = raw_damage - defender_toughness
	
	# e) The attacker also suffers casualties, based on the defender's power.
	var defender_power = defender_start_count * 0.20
	var size_ratio = attacker_start_count / defender_start_count
	var damage_reduction = atan(size_ratio - 1.0) / (PI / 2.0) # Normalizes to a 0-1 range
# c) The final damage to the attacker is the defender's power reduced by this percentage.
#    We'll cap the reduction at 90% to ensure they always take at least 10% of the damage.
	var final_damage_to_attacker = defender_power * (1.0 - clamp(damage_reduction, 0.0, 0.90))
	
	# --- 4. Calculate Final Casualties ---
	# Ensure casualties are never negative and convert to integer.
	var attacker_casualties = int(max(0, final_damage_to_attacker))
	var defender_casualties = int(max(0, final_damage_to_defender))
	
	# --- 5. store Casualties ---
	calculated_attacker_casualties = attacker_casualties
	calculated_defender_casualties = defender_casualties
	
	
	#attacker_unit.count = max(0, attacker_unit.count - attacker_casualties)
	#defender_unit.count = max(0, defender_unit.count - defender_casualties)
	
	# Switch turns
	#if not is_simulation:
		#current_turn_army = defender_army if current_turn_army == attacker_army else attacker_army

# AI logic for choosing units
func get_ai_attack_choice(ai_army: BattleArmy) -> BattleUnit:
	# Simple AI: pick the unit with the most troops
	var best_unit = null
	var max_count = 0
	for unit_type in ai_army.units:
		if ai_army.units[unit_type].count > max_count:
			max_count = ai_army.units[unit_type].count
			best_unit = ai_army.units[unit_type]
	return best_unit

func get_ai_defense_choice(defending_army: BattleArmy, attacking_unit: BattleUnit) -> BattleUnit:
	# Simple AI: find the best counter
	# TODO: Implement counter logic
	return get_ai_attack_choice(defending_army)
