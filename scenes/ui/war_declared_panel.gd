extends PanelContainer

signal acknowledged

@onready var declaration_text_label = %DeclarationText
@onready var continue_button = %ContinueButton

func _ready():
	continue_button.pressed.connect(func(): emit_signal("acknowledged"))

# This function populates the panel with the details of the war.
func set_war_declaration_info(attacker: Kingdom, defender: Kingdom, war_goal: Province):
	var text = "The [b]%s[/b] has declared war upon you!\n\n" % attacker.kingdom_name
	text += "Led by [b]%s[/b], their armies march to seize the province of [b]%s[/b].\n\n" % [attacker.ruler.full_name, war_goal.province_name]
	text += "You must rally your banners and defend the realm!"
	declaration_text_label.text = text
