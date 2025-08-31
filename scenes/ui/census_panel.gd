extends PanelContainer

signal closed

@onready var title_label = %TitleLabel
@onready var census_text_label = %CensusText
@onready var close_button = %CloseButton

func _ready():
	close_button.pressed.connect(_on_close_button_pressed)
	census_text_label.bbcode_enabled = true

# --- This is the public "front door" function ---
# It takes a Kingdom object and displays a census for it.
func display_census_for_kingdom(kingdom: Kingdom):
	if not is_instance_valid(kingdom):
		title_label.text = "Error"
		census_text_label.text = "Invalid kingdom provided."
		return

	title_label.text = "Census for The %s" % kingdom.kingdom_name
	census_text_label.clear()
	
	# Get all living characters in this specific court
	var courtiers = GameManager.get_characters_in_court(kingdom)
	courtiers = courtiers.filter(func(c): return c.is_alive)
	
	if courtiers.is_empty():
		census_text_label.append_text("- This court is empty.")
		return
	census_text_label.append_text("[b]Total Population in this court: %d[/b]\n\n" % courtiers.size())
	# --- The Reusable Formatting Logic ---
	for character in courtiers:
				# ... format and append text for character, spouse, children, etc.
				var character_string = ""
				
				# Name and Age
				var age = GameManager.current_year - character.birth_year
				character_string += "[b]%s[/b] (Age: %d)" % [character.full_name, age]
				var personality_name = Character.CharacterPersonality.keys()[character.personality]

				if kingdom.ruler==character:
					character_string += ": the [i]%s[/i]" % personality_name.to_lower()
					character_string+=" Ruler of the kingdom"
				# Spouse
				if is_instance_valid(character.spouse):
					if character.spouse.is_alive:
						character_string += " - Married to %s." % character.spouse.full_name
					else:
						character_string += " - Widow of %s." % character.spouse.full_name
				else:
					if age > 15:
						character_string += " - Unmarried."
					
				
				census_text_label.append_text(character_string + "\n")
				
				# Parents
				var parents_string = "  [i]Parents:[/i] "
				if is_instance_valid(character.father) and is_instance_valid(character.mother):
					parents_string += "%s & %s %s." % [character.father.first_name, character.mother.first_name, character.father.dynasty_name]
					census_text_label.append_text(parents_string + "\n")
				
				# Children
				var children_string = "  [i]Children:[/i] "
				if character.children.is_empty():
					children_string += "None."
				else:
					var child_names: Array[String] = []
					for child in character.children:
						# Only list living children in this section
						if child.is_alive:
							child_names.append(child.first_name)
					children_string += ", ".join(child_names)
					if child_names.is_empty(): # In case all children are dead
						children_string = "  [i]Children:[/i] None living."
				
				if age > 15:
					census_text_label.append_text(children_string + "\n")
					
					# Add a separator for readability
				census_text_label.append_text("-------------------\n")
				
func _on_close_button_pressed():
	# Emit the signal and then remove the popup from the scene.
	emit_signal("closed")
	queue_free()
