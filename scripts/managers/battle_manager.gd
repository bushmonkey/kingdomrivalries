extends Node

var attacker_army: BattleArmy
var defender_army: BattleArmy
var current_turn_army: BattleArmy

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
	get_tree().change_scene_to_file("res://scenes/battle/battle_view.tscn")

# This is the core rock-paper-scissors logic
func resolve_combat(attacker_unit: BattleUnit, defender_unit: BattleUnit):
	var attacker_type = attacker_unit.unit_type
	var defender_type = defender_unit.unit_type
	
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
			
	# Calculate casualties
	var base_damage = min(attacker_unit.count, defender_unit.count)
	var attacker_casualties = int(base_damage * 0.2) # Attackers always take some losses
	var defender_casualties = int(base_damage * damage_multiplier * 0.5)
	
	attacker_unit.count = max(0, attacker_unit.count - attacker_casualties)
	defender_unit.count = max(0, defender_unit.count - defender_casualties)
	
	# Switch turns
	current_turn_army = defender_army if current_turn_army == attacker_army else attacker_army

# AI logic for choosing units
func get_ai_attack_choice(ai_army: BattleArmy) -> BattleUnit:
	# Simple AI: pick the unit with the most troops
	var best_unit = null
	var max_count = -1
	for unit_type in ai_army.units:
		if ai_army.units[unit_type].count > max_count:
			max_count = ai_army.units[unit_type].count
			best_unit = ai_army.units[unit_type]
	return best_unit

func get_ai_defense_choice(ai_army: BattleArmy, attacking_unit: BattleUnit) -> BattleUnit:
	# Simple AI: find the best counter
	# TODO: Implement counter logic
	return get_ai_attack_choice(ai_army) # Fallback to biggest unit
