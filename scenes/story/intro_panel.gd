extends PanelContainer
class_name IntroPanel

signal intro_acknowledged

@onready var title_label = %Title
@onready var intro_text_label = %IntroText
@onready var unlock_icons_container = %UnlockIconsContainer

@onready var info_pages = %InfoPages
@onready var ruler_info_page = %RulerInfoPage
@onready var kingdom_info_page = %KingdomInfoPage
@onready var world_info_page = %WorldInfoPage
@onready var next_button = %NextButton

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

#State Management ---
var _current_page_index = 0

func _ready():
	next_button.pressed.connect(_on_next_button_pressed)
	intro_text_label.bbcode_enabled = true # Enable bolding, italics, etc.
	ruler_info_page.bbcode_enabled = true

# This function takes the player's kingdom and formats the intro text.
func display_intro(player_kingdom: Kingdom):
	_populate_ruler_page(player_kingdom)
	_populate_kingdom_page(player_kingdom)
	_populate_world_page(player_kingdom)
	
	
	
	for child in unlock_icons_container.get_children():
		child.queue_free()
	if not is_instance_valid(player_kingdom) or not is_instance_valid(player_kingdom.ruler):
		intro_text_label.text = "Error: Could not load player data."
		return
		
	var ruler = player_kingdom.ruler
	var neighbors = player_kingdom.get_neighboring_kingdoms()
	var unowned_lands = player_kingdom.get_neighboring_unowned_provinces()
	
	
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
	
	_current_page_index = 0
	info_pages.current_tab = _current_page_index
	next_button.text = "Next >"
	self.show()
	
func _populate_ruler_page(kingdom: Kingdom):
	var ruler = kingdom.ruler
	var ruler_age=GameManager.current_year-ruler.birth_year
	var ruler_personality_name = ruler.CharacterPersonality.keys()[ruler.personality]

	var page_text="A new reign begins \n\nYou are [b]%s[/b], the [i]%s[/i] ruler of [b]%s[/b].\n" % [ruler.full_name, ruler_personality_name.to_lower(),kingdom.kingdom_name]
		# --- NEW SECTION FOR CAPITAL ---
	if is_instance_valid(kingdom.capital):
		page_text +="Your seat of power is the city of [b]%s[/b].\n" % kingdom.capital.province_name
	page_text +="At %d years of age, the fate of your dynasty rests upon your shoulders.\n\n" % ruler_age
		# Spouse
	if is_instance_valid(ruler.spouse):
		page_text +="- You are married to [b]%s[/b].\n" % ruler.spouse.get_full_name()
	else:
		page_text +="- You are unmarried.\n"
	
	# Children
	if ruler.children.is_empty():
		page_text +="- You have no children.\n"
	else:
		var child_names: Array[String] = []
		for child in ruler.children:
			child_names.append(child.first_name)
		page_text +="- Your children are: [i]%s[/i].\n" % ", ".join(child_names)
		
	ruler_info_page.text = page_text
	
func _populate_kingdom_page(kingdom: Kingdom):
	kingdom_info_page.bbcode_enabled = true
	var neighbors = kingdom.get_neighboring_kingdoms()
	var page_text = "[u]Your Realm's Status:[/u]\n"
	page_text += "- Treasury: [b]%d[/b] Gold\n" % int(kingdom.treasury)
	page_text += "- Manpower: [b]%d[/b] Men\n" % kingdom.manpower
	page_text += "- Court Size: [b]%d[/b] Courtiers\n" % GameManager.get_court_size(kingdom)
	
	page_text +="\n[u]Your Neighbors:[/u]\n"
	if neighbors.is_empty():
		page_text +="- Your kingdom is surrounded by wilderness and unclaimed lands.\n"
	else:
		for neighbor_kingdom in neighbors:
			page_text +="- [b]%s[/b], ruled by %s.\n" % [neighbor_kingdom.kingdom_name, neighbor_kingdom.ruler.full_name]
			
	page_text += "\nYour kingdom relies on you to make incisive decisions every season to flourish. \nYou can either lead your court to Greatness or Misery. Their fate is in your hands."
	
	kingdom_info_page.text = page_text
	
func _populate_world_page(player_kingdom: Kingdom):
	world_info_page.bbcode_enabled = true
	world_info_page.clear() # Clear it first
	var neighbors = player_kingdom.get_neighboring_kingdoms()
	var unowned_lands = player_kingdom.get_neighboring_unowned_provinces()
	# Neighbors
	world_info_page.append_text("[u]The continent is also home to other kingdoms vying to conquer the world:[/u]\n\n")
	
	var other_realms_found = false
	# Loop through every single kingdom in the world
	for kingdom in GameManager.all_kingdoms:
		# --- Filter out kingdoms we don't want to show in this section ---
		if kingdom == player_kingdom: continue # Skip the player
		
		# If we get here, this is a kingdom to display.
		other_realms_found = true
		var ruler = kingdom.ruler
		var personality_name = Character.CharacterPersonality.keys()[ruler.personality].capitalize()
		
		# Format the string with the kingdom, ruler, and their personality.
		var kingdom_string = "- [b]%s[/b], ruled by the [i]%s[/i] %s.\n\n" % [kingdom.kingdom_name, personality_name,ruler.full_name]
		world_info_page.append_text(kingdom_string)
	
func _on_next_button_pressed():
	_current_page_index += 1
	
	if _current_page_index < info_pages.get_tab_count():
		# If there's another page, go to it.
		info_pages.current_tab = _current_page_index
		
		var current_tab_node = info_pages.get_child(info_pages.current_tab)
		
		if current_tab_node.get_child_count() > 0:
			var rich_text_label = current_tab_node.get_child(0)
			rich_text_label.show()
		
		# If it's the LAST page, change the button text.
		if _current_page_index == info_pages.get_tab_count() - 1:
			next_button.text = "Begin Your Reign"
	else:
		# We were on the last page, so the button press means we're finished.
		emit_signal("intro_acknowledged")
