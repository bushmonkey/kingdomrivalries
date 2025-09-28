class_name BattleArmy
extends RefCounted

var kingdom: Kingdom
var ruler: Character
var units: Dictionary = {} # Key: UnitType, Value: BattleUnit object

func _init(p_kingdom: Kingdom):
	self.kingdom = p_kingdom
	self.ruler = p_kingdom.ruler
	_assemble_army()

# This function calculates the army composition
func _assemble_army():
	var total_manpower = kingdom.manpower
	
	# Foot Soldiers (70%)
	var foot_soldiers = BattleUnit.new()
	foot_soldiers.unit_type = BattleUnit.UnitType.FOOT_SOLDIER
	foot_soldiers.count = int(total_manpower * 0.70)
	units[BattleUnit.UnitType.FOOT_SOLDIER] = foot_soldiers
	
	# Cavalry (30%)
	var cavalry = BattleUnit.new()
	cavalry.unit_type = BattleUnit.UnitType.CAVALRY
	cavalry.count = int(total_manpower * 0.30)
	units[BattleUnit.UnitType.CAVALRY] = cavalry
	
	# Special Units
	var pikemen = BattleUnit.new(); pikemen.unit_type = BattleUnit.UnitType.PIKEMAN
	var knights = BattleUnit.new(); knights.unit_type = BattleUnit.UnitType.KNIGHT
	var cannon = BattleUnit.new(); cannon.unit_type = BattleUnit.UnitType.CANNON

	if kingdom.has_modifier("PikemenRegiment"): pikemen.count = 200 # Example
	if kingdom.has_modifier("AdvancedArchitecture"): cannon.count = 1
	
	knights.count = 0
	for char in GameManager.get_characters_in_court(kingdom):
		if char.is_knight: knights.count += 1
		
	units[BattleUnit.UnitType.PIKEMAN] = pikemen
	units[BattleUnit.UnitType.KNIGHT] = knights
	units[BattleUnit.UnitType.CANNON] = cannon

func get_total_troops() -> int:
	var total = 0
	for unit_type in units:
		total += units[unit_type].count
	return total
