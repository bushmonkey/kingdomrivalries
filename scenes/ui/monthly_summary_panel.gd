extends PanelContainer
class_name MonthlySummaryPanel

signal summary_acknowledged

@onready var summary_text_label = $VBoxContainer/SummaryText
@onready var continue_button = $VBoxContainer/ContinueButton

func _ready():
	continue_button.pressed.connect(func(): emit_signal("summary_acknowledged"))
	summary_text_label.bbcode_enabled = true

func display_summary(log: Array[String], courts_data: Dictionary):
	summary_text_label.clear()
	
	# --- Display Logged Events First (Births/Deaths) ---
	summary_text_label.append_text("[b]This Month's Events:[/b]\n")
	if log.is_empty():
		summary_text_label.append_text("- A quiet month.\n")
	else:
		for line in log:
			summary_text_label.append_text("- %s\n" % line)
	
	summary_text_label.append_text("\n\n") # Add some space
	
	var living_characters = GameManager.all_characters_in_world.filter(func(c): return c.is_alive)
	# --- Display the World Census ---
	summary_text_label.append_text("[b]World Census:[/b]\n")
	var count_of_characters: int =living_characters.size()
	summary_text_label.append_text("%d alive in the world\n" % count_of_characters)
	for kingdom in courts_data.keys():
		var courtiers = courts_data[kingdom]
		
		# --- Add the Court Heading ---
		summary_text_label.append_text("\n[u][b]Court of %s[/b][/u]\n" % kingdom.kingdom_name)
		if kingdom.kingdom_name==GameManager.player_kingdom.kingdom_name:
			summary_text_label.append_text("[i]Your Kingdom[/i]\n")
			summary_text_label.append_text("************\n")
		if courtiers.is_empty():
			summary_text_label.append_text("- This court is empty.\n")
			continue # Move to the next kingdom in the loop
			
		# --- Loop through the characters IN THIS COURT ---
		for character in courtiers:
					# We only want to display living characters in the census
			#var living_characters = courtiers.character.filter(func(c): return c.is_alive)
			#
			#if living_characters.is_empty():
				#summary_text_label.append_text("- All are dead.\n")
				#return
				#
			#for courtier_character in living_characters:
				# Build the string for each character piece by piece
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
					
				
				summary_text_label.append_text(character_string + "\n")
				
				# Parents
				var parents_string = "  [i]Parents:[/i] "
				if is_instance_valid(character.father) and is_instance_valid(character.mother):
					parents_string += "%s & %s %s." % [character.father.first_name, character.mother.first_name, character.father.dynasty_name]
					summary_text_label.append_text(parents_string + "\n")
				
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
					summary_text_label.append_text(children_string + "\n")
				
				# Add a separator for readability
				summary_text_label.append_text("-------------------\n")
	
	
	
	
	
	
	
	
	
	
	#
	## We only want to display living characters in the census
	#var living_characters = all_characters.filter(func(c): return c.is_alive)
	#
	#if living_characters.is_empty():
		#summary_text_label.append_text("- All are dead.\n")
		#return
		#
	#for character in living_characters:
		## Build the string for each character piece by piece
		#var character_string = ""
		#
		## Name and Age
		#var age = GameManager.current_year - character.birth_year
		#character_string += "[b]%s[/b] (Age: %d)" % [character.full_name, age]
		#
		## Spouse
		#if is_instance_valid(character.spouse):
			#character_string += " - Married to %s." % character.spouse.full_name
		#else:
			#if age > 15:
				#character_string += " - Unmarried."
			#
		#
		#summary_text_label.append_text(character_string + "\n")
		#
		## Parents
		#var parents_string = "  [i]Parents:[/i] "
		#if is_instance_valid(character.father) and is_instance_valid(character.mother):
			#parents_string += "%s & %s." % [character.father.first_name, character.mother.first_name]
		#else:
			#parents_string += "Unknown."
		#summary_text_label.append_text(parents_string + "\n")
		#
		## Children
		#var children_string = "  [i]Children:[/i] "
		#if character.children.is_empty():
			#children_string += "None."
		#else:
			#var child_names: Array[String] = []
			#for child in character.children:
				## Only list living children in this section
				#if child.is_alive:
					#child_names.append(child.first_name)
			#children_string += ", ".join(child_names)
			#if child_names.is_empty(): # In case all children are dead
				#children_string = "  [i]Children:[/i] None living."
		#
		#if age < 16:
			#children_string=""
		#summary_text_label.append_text(children_string + "\n")
		#
		## Add a separator for readability
		#summary_text_label.append_text("-------------------\n")
