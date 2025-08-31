class_name War

# --- Properties ---

# The Kingdom object that initiated the conflict.
var attacker: Kingdom

# The Kingdom object that is being attacked.
var defender: Kingdom

# The specific Province object that is the primary objective of the war.
# This is what the attacker gains if they win.
var original_war_goal: Province 
var war_goal: Province

# The central mechanic of the war. It's a float that tracks who is winning.
# Ranges from -100.0 (Defender is winning decisively) to 100.0 (Attacker is winning decisively).
# A score of 0.0 means the war is in a stalemate.
# --- NEW: War Progress ---
# War Score ranges from -100 (Defender Winning) to 100 (Attacker Winning)
var war_score: float = 0.0

# Tracks how tired each side is of the war
var attacker_war_exhaustion: float = 0.0
var defender_war_exhaustion: float = 0.0

# A simple counter for how many months the war has been ongoing.
# Can be used for "war weariness" mechanics or to trigger special events.
var months_at_war: int = 0

# --- Initialization ---

# The constructor, called when a new war is declared.
# Example: var new_war = War.new(kingdom_a, kingdom_b, target_province)
func _init(p_attacker: Kingdom, p_defender: Kingdom, p_war_goal: Province):
	self.attacker = p_attacker
	self.defender = p_defender
	self.original_war_goal = p_war_goal

# --- Methods ---

# A utility function to neatly describe the conflict.
# Useful for UI elements or log messages.
func get_description() -> String:
	return "The %s's War for %s" % [attacker.kingdom_name, war_goal.province_name]

# A simple string representation for debugging.
func _to_string() -> String:
	return "War: %s vs %s over %s (Score: %.1f)" % [attacker.kingdom_name, defender.kingdom_name, war_goal.province_name, war_score]
