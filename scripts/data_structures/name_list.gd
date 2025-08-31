# Defines a resource that holds lists of names.
class_name NameList
extends Resource

# Use @export to make these arrays editable in the Godot Inspector.
@export var male_names: Array[String]
@export var female_names: Array[String]
@export var dynasty_names: Array[String]
@export var common_names: Array[String]
