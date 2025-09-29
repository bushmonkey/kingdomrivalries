extends Node

# This script runs once, sets up a test battle, and then switches scenes.

func _ready():
	print("--- BATTLE TEST LAUNCHER: Setting up test scenario... ---")
	
	# --- 1. Create Fake Kingdoms and Rulers ---
	# We need to create mock objects for the player and an AI opponent.
	
	# Player's Kingdom
	var player_kingdom = Kingdom.new()
	player_kingdom.id = 0
	player_kingdom.kingdom_name = "The Player's Realm"
	player_kingdom.manpower = 2000
	player_kingdom.color = Color.PALE_VIOLET_RED
	
	var player_ruler = Character.new()
	player_ruler.first_name = "Test"
	player_ruler.dynasty_name = "Player"
	player_ruler.martial = 8
	player_ruler.personality = Character.CharacterPersonality.STRONG
	player_kingdom.ruler = player_ruler
	
	# We need to set the GameManager's player_kingdom so the BattleView knows who is who.
	GameManager.player_kingdom = player_kingdom
	
	# AI's Kingdom
	var ai_kingdom = Kingdom.new()
	ai_kingdom.id = 1
	ai_kingdom.kingdom_name = "The Iron Hegemony"
	ai_kingdom.manpower = 1800
	ai_kingdom.color = Color.SLATE_GRAY
	
	var ai_ruler = Character.new()
	ai_ruler.first_name = "Test"
	ai_ruler.dynasty_name = "AI"
	ai_ruler.martial = 7
	ai_ruler.personality = Character.CharacterPersonality.WARLORD
	ai_kingdom.ruler = ai_ruler
	
	# --- 2. Call the BattleManager to start the battle ---
	# We tell the BattleManager to start a battle between our two fake kingdoms.
	# The BattleManager will create the armies, determine who goes first,
	# and then it will be the one to change the scene to the battle view.
	BattleManager.start_battle(player_kingdom, ai_kingdom)
	
	print("--- BATTLE TEST LAUNCHER: Setup complete. Handing off to BattleManager... ---")
