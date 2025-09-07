extends VBoxContainer

signal back_pressed

#@onready var back_button = %BackButton
@onready var relations_text_label = %RelationsText

func _ready():
	#back_button.pressed.connect(func(): emit_signal("back_pressed"))
	relations_text_label.bbcode_enabled = true

# This is the public "front door" function.
func display_relations_for_kingdom(kingdom: Kingdom):
	relations_text_label.clear()
	
	var allies: Array[String] = []
	var rivals: Array[String] = []
	var neutrals: Array[String] = []
	
	# Loop through the kingdom's 'relations' dictionary
	for other_kingdom_id in kingdom.relations:
		var other_kingdom = GameManager.find_kingdom_by_id(other_kingdom_id)
		if not is_instance_valid(other_kingdom): continue
		
		var relation_value = kingdom.relations[other_kingdom_id]
		
		# Format the string for this entry
		var line = "- %s (%d)" % [other_kingdom.kingdom_name, relation_value]
		
		# Sort the entry into the correct list
		if kingdom.allies.has(other_kingdom_id):
			allies.append(line)
		elif kingdom.rivals.has(other_kingdom_id):
			rivals.append(line)
		else:
			neutrals.append(line)
			
	# --- Now, build the final display text ---
	
	relations_text_label.append_text("[b][u]Allies:[/u][/b]\n")
	if allies.is_empty():
		relations_text_label.append_text("[i]- None[/i]\n")
	else:
		relations_text_label.append_text("\n".join(allies) + "\n")
		
	relations_text_label.append_text("\n[b][u]Rivals:[/u][/b]\n")
	if rivals.is_empty():
		relations_text_label.append_text("[i]- None[/i]\n")
	else:
		relations_text_label.append_text("\n".join(rivals) + "\n")
		
	relations_text_label.append_text("\n[b][u]Neutral Kingdoms:[/u][/b]\n")
	if neutrals.is_empty():
		relations_text_label.append_text("[i]- None[/i]\n")
	else:
		relations_text_label.append_text("\n".join(neutrals) + "\n")
