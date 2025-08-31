# res://scenes/ui/outcome_panel.gd
extends PanelContainer
class_name OutcomePanel

signal outcome_acknowledged

@onready var result_title_label = %ResultTitle
@onready var flavor_text_label = %FlavorText
@onready var outcomes_list_container = %OutcomesList
@onready var continue_button = %ContinueButton
@onready var roll_breakdown_text_label = %RollBreakdownText

func _ready():
	continue_button.pressed.connect(func(): emit_signal("outcome_acknowledged"))
	# Make sure the text label wraps correctly
	flavor_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	roll_breakdown_text_label.bbcode_enabled = true # Enable BBCode
	
func display_outcome(is_success: bool, flavor_text_template: String, outcomes: Array[EventOutcome], format_args: Dictionary, roll_results: Dictionary):
	# --- Set Title and Flavor Text ---

		
	if is_success:
		var greenColor = Color(0.0,0.69,0.0,1.0)
		result_title_label.add_theme_color_override("font_color", greenColor)
		result_title_label.text = "Success!"  
	else:
		var redColor = Color(1.0,0.0,0.0,1.0)
		result_title_label.add_theme_color_override("font_color", redColor)
		result_title_label.text = "Failure..."
	
	flavor_text_label.text = flavor_text_template.format(format_args, "{_}")
	
	# --- NEW: Check for custom roll breakdown ---
	if roll_results.get("is_custom", false):
		roll_breakdown_text_label.show()
		roll_breakdown_text_label.clear()
		roll_breakdown_text_label.append_text("\n[i]%s[/i]" % roll_results.breakdown)
		roll_breakdown_text_label.append_text("\n[b]%s[/b]" % roll_results.success_chance_text)
	elif roll_results.get("difficulty", 0) == 0:
		#roll_breakdown_text_label.hide()
		roll_breakdown_text_label.append_text("\n[i]Automatic success. No dice roll.[/i]")
	else:
		roll_breakdown_text_label.show()
		roll_breakdown_text_label.clear() # Clear any old text
		
		var breakdown = ""
		
		# Base Stat + Roll
		breakdown += "Your [b]%s[/b] (%d) + Dice Roll (%d)" % [roll_results.stat_name, roll_results.base_stat, roll_results.roll]
		
		# Add optional bonuses/penalties
		if roll_results.personality_bonus != 0:
			breakdown += " + Personality (%d)" % roll_results.personality_bonus
			
		if roll_results.get("tech_bonus", 0) != 0:
			breakdown += " [color=cyan]Innovation Bonus[/color] (%d)" % roll_results.tech_bonus
			
			
		if roll_results.modifier_penalty != 0:
			breakdown += " [color=red]Penalty[/color] (%d from %s)" % [roll_results.modifier_penalty, roll_results.penalty_reason]
			
		# Final result
		breakdown += " = [b]Total %d[/b]" % roll_results.total_score
		breakdown += " (Needed [b]%d[/b] to succeed)" % roll_results.difficulty
		
		roll_breakdown_text_label.append_text("\n[i]%s[/i]" % breakdown)
	
	self.show()
	
	
	# --- Clear previous mechanical results ---
	for child in outcomes_list_container.get_children():
		child.queue_free()
		
	# --- Display the new mechanical results ---
	for outcome in outcomes:
		var effect_label = Label.new()
		# We'll create a nice, human-readable string for each effect
		effect_label.text = _format_outcome_text(outcome)
		outcomes_list_container.add_child(effect_label)
	
	self.show()

# Helper function to make the outcome text look good
func _format_outcome_text(outcome: EventOutcome) -> String:
	var text = ""
	match outcome.type:
		"ChangeResource":
			if outcome.value > 0:
				text = "+%d %s" % [outcome.value, outcome.target]
			else:
				text = "%d %s" % [outcome.value, outcome.target] # Value is already negative
		"ChangeOpinion":
			if outcome.value > 0:
				text = "%s Opinion: +%d" % [outcome.target, outcome.value]
			else:
				text = "%s Opinion: %d" % [outcome.target, outcome.value]
		"AddModifier":
			if outcome.duration>0:
				text = "Gained modifier %s for %d months" % [outcome.target, outcome.duration]
			elif outcome.duration==-1:
				text = "Gained modifier %s forever" % [outcome.target]
		# Add more cases as you add more outcome types
		"StartCourting":
			text = "Starting courting lady %s" % GameManager.find_character_by_id(outcome.target.to_lower()).full_name
		"ChangeAffection":
			if GameManager.player_kingdom.ruler.spouse ==null:
				#not married yet
				if GameManager.player_kingdom.ruler.girlfriend ==null: 
					#not going out yet
					if outcome.value > 0:
						text = "lady %s's affection of you grew" % GameManager.find_character_by_id(outcome.target.to_lower()).full_name
					else:
						text = "lady %s's affection of you has gone down" % GameManager.find_character_by_id(outcome.target.to_lower()).full_name
				else:
					if outcome.value > 0:
						text = "lady %s's affection of you grew" % GameManager.player_kingdom.ruler.girlfriend.full_name
					else:
						text = "lady %s's affection of you has gone down" % GameManager.player_kingdom.ruler.girlfriend.full_name
			else:
				if outcome.value > 0:
					text = "your wife's affection grew"
				else:
					text = "your wife's affection has gone down"
		"ChangeStat":
			if outcome.value > 0:
				text = "+%d %s" % [outcome.value, outcome.target]
			else:
				text = "%d %s" % [outcome.value, outcome.target]
		"MarryCharacter":
			text="you and lady %s are now married" % GameManager.player_kingdom.ruler.spouse.full_name
		"EndCourting":
			text="you and lady %s have now gone your separate ways" % GameManager.player_kingdom.ruler.ex_girlfriend.full_name
			
		"AddProvince":
			text="you annex %s, growing your kingdom" % outcome.target
		_:	
			text = "Unknown effect."
			
	return text
