extends PanelContainer
class_name ActionSelectorPanel

signal summary_acknowledged

#@onready var summary_text_label = $VBoxContainer/SummaryText
@onready var economy_button = $VBoxContainer/EconomyBtn
@onready var agriculture_button = $VBoxContainer/AgricultureBtn
@onready var culture_button = $VBoxContainer/CultureBtn
@onready var manufacturing_button = $VBoxContainer/ManufacturingBtn
@onready var science_button = $VBoxContainer/ScienceBtn
@onready var expedition_button = $VBoxContainer/ExpeditionBtn

func _ready():
	economy_button.pressed.connect(func(): emit_signal("economy_chosen"))
	agriculture_button.pressed.connect(func(): emit_signal("agriculture_chosen"))
	culture_button.pressed.connect(func(): emit_signal("culture_chosen"))
	manufacturing_button.pressed.connect(func(): emit_signal("manufacturing_chosen"))
	science_button.pressed.connect(func(): emit_signal("science_chosen"))
	expedition_button.pressed.connect(func(): emit_signal("expedition_chosen"))
