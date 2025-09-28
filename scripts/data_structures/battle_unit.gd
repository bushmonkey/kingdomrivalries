class_name BattleUnit
extends RefCounted

enum UnitType {
	FOOT_SOLDIER,
	CAVALRY,
	PIKEMAN,
	KNIGHT,
	CANNON
}
var unit_type: UnitType
var count: int = 0
