extends Node

const SAVE_FILE_PATH = "user://meta_progress.save"

# This dictionary will hold all the permanent unlocks the player has earned.
# We will load it from a file when the game starts.
var unlocks: Dictionary = {
	# We define the default state of all possible unlocks here.
	"INCREASED_INFLUENCE": false,
	"ROYAL_TREASURY_GRANT": false,
	"VETERAN_TRAINING": false
}

func _ready():
	load_progress()

# --- Save/Load Functions ---

func save_progress():
	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if not file:
		printerr("Failed to open meta save file for writing.")
		return
		
	# Store the 'unlocks' dictionary as a JSON string.
	var json_string = JSON.stringify(unlocks)
	file.store_string(json_string)
	print("Meta progression saved.")

func load_progress():
	if not FileAccess.file_exists(SAVE_FILE_PATH):
		print("No meta save file found. Using default unlocks.")
		return # No file exists, so we just use the default values.
		
	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
	if not file:
		printerr("Failed to open meta save file for reading.")
		return
		
	var content = file.get_as_text()
	var loaded_data = JSON.parse_string(content)
	
	if loaded_data is Dictionary:
		# We iterate through the loaded data and update our existing dictionary.
		# This is safer than just overwriting, in case we add new unlock
		# types in a future game update.
		for key in loaded_data:
			if unlocks.has(key):
				unlocks[key] = loaded_data[key]
		print("Meta progression loaded.")
	else:
		printerr("Meta save file is corrupted.")
