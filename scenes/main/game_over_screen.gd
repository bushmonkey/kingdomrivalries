extends Control

@onready var summary_text_label = %SummaryText
@onready var new_game_button = %NewGameButton

func _ready():
	new_game_button.pressed.connect(_on_new_game_button_pressed)
	# Initially hide the screen, as it will be populated before being shown
	hide()

# This public function will be called by MainView to set up the screen.
func display_summary(summary_data: Dictionary):
	var text = ""
	text += "The [b]%s[/b] Dynasty ruled for [b]%d[/b] years.\n" % [summary_data.dynasty_name, summary_data.years_ruled]
	text += "At its peak, the realm consisted of [b]%d[/b] provinces.\n" % summary_data.peak_provinces
	text += "The final ruler was [b]%s[/b].\n\n" % summary_data.final_ruler_name
	text += "[u]Cause of Downfall:[/u]\n[i]%s[/i]" % summary_data.cause_of_downfall
	
	summary_text_label.bbcode_enabled = true
	summary_text_label.text = text
	
	show()

func _on_new_game_button_pressed():
	# The simplest way to start over is to just reload the title screen.
	get_tree().change_scene_to_file("res://scenes/intro.tscn")
