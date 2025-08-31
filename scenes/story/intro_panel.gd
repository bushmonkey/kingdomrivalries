extends PanelContainer
class_name IntroPanel

signal intro_acknowledged

@onready var title_label = %Title
@onready var intro_text_label = %IntroText
@onready var begin_button = %BeginButton
@onready var unlock_icons_container = %UnlockIconsContainer

const UNLOCK_DATA = {
	"INCREASED_INFLUENCE": {
		"icon_path": "res://assets/icons/unlocks/increased_influence_icon.png",
		"tooltip": "Increased Influence: Start with an additional province."
	},
	"ROYAL_TREASURY_GRANT": {
		"icon_path": "res://assets/icons/unlocks/royal_treasury_grant_icon.png",
		"tooltip": "Royal Treasury Grant: Start with an additional 250 Treasury."
	},
	"VETERAN_TRAINING": {
		"icon_path": "res://assets/icons/unlocks/veteran_training_icon.png",
		"tooltip": "Veteran Training: Start with an additional 500 Manpower."
	}
}

func _ready():
	begin_button.pressed.connect(func(): emit_signal("intro_acknowledged"))
	intro_text_label.bbcode_enabled = true # Enable bolding, italics, etc.

# This function takes the player's kingdom and formats the intro text.
func display_intro(player_kingdom: Kingdom):
	for child in unlock_icons_container.get_children():
		child.queue_free()
	if not is_instance_valid(player_kingdom) or not is_instance_valid(player_kingdom.ruler):
		intro_text_label.text = "Error: Could not load player data."
		return
		
	var ruler = player_kingdom.ruler
	var neighbors = player_kingdom.get_neighboring_kingdoms()
	var unowned_lands = player_kingdom.get_neighboring_unowned_provinces()
	
	# Clear any previous text
	intro_text_label.clear()
	var ruler_age=GameManager.current_year-ruler.birth_year
	var ruler_personality_name = ruler.CharacterPersonality.keys()[ruler.personality]
	var ruler_court_size = GameManager.get_court_size(player_kingdom)
	var ruler_treasury_amount = int(player_kingdom.treasury)
	# Build the text using BBCode for formatting
	intro_text_label.append_text("A new reign begins \n\nYou are [b]%s[/b], the [i]%s[/i] ruler of [b]%s[/b].\n" % [ruler.full_name, ruler_personality_name.to_lower(),player_kingdom.kingdom_name])
		# --- NEW SECTION FOR CAPITAL ---
	if is_instance_valid(player_kingdom.capital):
		intro_text_label.append_text("Your seat of power is the city of [b]%s[/b].\n" % player_kingdom.capital.province_name)
	intro_text_label.append_text("At %d years of age, the fate of your dynasty rests upon your shoulders.\n\n" % ruler_age)
		# Spouse
	if is_instance_valid(ruler.spouse):
		intro_text_label.append_text("- You are married to [b]%s[/b].\n" % ruler.spouse.get_full_name())
	else:
		intro_text_label.append_text("- You are unmarried.\n")
	
	# Children
	if ruler.children.is_empty():
		intro_text_label.append_text("- You have no children.\n")
	else:
		var child_names: Array[String] = []
		for child in ruler.children:
			child_names.append(child.first_name)
		intro_text_label.append_text("- Your children are: [i]%s[/i].\n" % ", ".join(child_names))
		
	intro_text_label.append_text("\n[u]Your kingdom:[/u]\n")
	intro_text_label.append_text("[i]Treasury:[/i] %d | [i]Court Size:[/i] %d\n" % [ruler_treasury_amount, ruler_court_size])

	intro_text_label.append_text("\n[u]Your Neighbors:[/u]\n")
	if neighbors.is_empty():
		intro_text_label.append_text("- Your kingdom is surrounded by wilderness and unclaimed lands.\n")
	else:
		for neighbor_kingdom in neighbors:
			intro_text_label.append_text("- [b]%s[/b], ruled by %s.\n" % [neighbor_kingdom.kingdom_name, neighbor_kingdom.ruler.full_name])
			
 #--- NEW: Section for Unclaimed Borderlands ---
	if unowned_lands.is_empty():
		pass
	else:
	# Create a list of the names of the unowned provinces
		intro_text_label.append_text("\n[u]Unclaimed Borderlands:[/u]\n")
		var land_names: Array[String] = []
		for province in unowned_lands:
			land_names.append("[b]%s[/b]" % province.province_name)
		intro_text_label.append_text("- The lands of %s lie open for expansion.\n" % ", ".join(land_names))
# --- END NEW SECTION ---

	intro_text_label.append_text("\n[u]Your Rivals:[/u]\n")
	
	if player_kingdom.rivals.is_empty():
		intro_text_label.append_text("- You begin your reign with no declared rivals.\n")
	else:
		for rival_id in player_kingdom.rivals:
			var rival_kingdom = GameManager.find_kingdom_by_id(rival_id)
			
			# Safety check in case something went wrong
			if not is_instance_valid(rival_kingdom):
				continue

			# Gather all the information we need
			var ruler_name = rival_kingdom.ruler.full_name
			var kingdom_name = rival_kingdom.kingdom_name
			var capital_name = rival_kingdom.capital.province_name
			var treasury_amount = int(rival_kingdom.treasury)
			var court_size = GameManager.get_court_size(rival_kingdom)

			# Format the information into a multi-line string for readability
			var rival_string = "[b]%s of %s[/b]\n" % [ruler_name, kingdom_name]
			var personality_name = rival_kingdom.ruler.CharacterPersonality.keys()[rival_kingdom.ruler.personality]
			rival_string += " [i]Personality:[/i] %s | " % personality_name.to_lower()
			rival_string += "  [i]Capital:[/i] %s | [i]Treasury:[/i] %d | [i]Court Size:[/i] %d\n" % [capital_name, treasury_amount, court_size]
			
			intro_text_label.append_text(rival_string)
			intro_text_label.append_text("-------------------\n")
			
	intro_text_label.append_text("\nYour kingdom relies on you to make incisive decisions every month to flourish. You can either lead your court to Greatness or Misery. Their fate is in your hands.")
	
	for unlock_id in MetaProgression.unlocks:
		var is_active = MetaProgression.unlocks[unlock_id]
		
		# If this unlock is active AND we have data for it...
		if is_active and UNLOCK_DATA.has(unlock_id):
			var data = UNLOCK_DATA[unlock_id]
			
			# a) Create a new TextureRect for the icon.
			var icon = TextureRect.new()
			icon.texture = load(data.icon_path)
			
			# b) Set its tooltip text.
			icon.tooltip_text = data.tooltip
			
			# c) Set a minimum size so it's not tiny.
			icon.custom_minimum_size = Vector2(64, 64)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			
			# d) Add the configured icon to our container.
			unlock_icons_container.add_child(icon)
	
	self.show()
