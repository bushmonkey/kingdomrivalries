class_name Character

enum Gender { MALE, FEMALE }

enum CharacterPersonality {
	STUBBORN,
	SHY,
	FRIENDLY,
	RUTHLESS,
	CHARMING,
	CUNNING,
	WARLORD,
	STRONG,
	WEAK
}
# Basic Info
var id: String
var character_name: String
var first_name: String
var dynasty_name: String
@export var full_name: String:
	get:
		# If there's a dynasty name, combine them. Otherwise, just use the first name.
		if not dynasty_name.is_empty():
			return "%s %s" % [first_name, dynasty_name]
		else:
			return first_name
var dynasty_id: int
var gender: Gender
var birth_year: int
var death_year: int = -1
var is_alive: bool = true
var cause_of_death: String = ""

# Core Stats & Traits
var martial: int
var stewardship: int
var diplomacy: int
var intrigue: int
var vigor: int
var charisma: int
var traits: Array[String] = []
var personality: CharacterPersonality
# Family Links
var father: Character
var mother: Character
var spouse: Character
var girlfriend: Character
var ex_girlfriend: Character
var spouse_at_inception: Character
var children: Array[Character] = []

# Relationship & Status
var current_court: Kingdom
var player_character: bool = false
var affection: int = 0  # For player romance
var opinion_of: Dictionary = {} #for rulers to other rulers

# --- New properties for life cycle ---
var is_pregnant: bool = false
var pregnancy_term: int = 0  # in seasons

var is_courting: bool = false

var expansion_desire: int = 50

func get_age():
	return GameManager.current_year-birth_year
	
# --- Methods ---
func die(cause: String):
	if not is_alive: return
	
	death_year = GameManager.current_year
	is_alive = false
	cause_of_death = cause
	var age=death_year-birth_year
	
	if is_instance_valid(GameManager.player_kingdom) and GameManager.player_kingdom.ruler == self:
		# Instead of setting the ruler to null, we set the flag.
		print("PLAYER RULER DIED. Setting succession_pending flag.")
		GameManager.player_succession_pending = true
	elif is_instance_valid(current_court) and current_court.ruler == self:
		# For an AI RULER, we handle their succession IMMEDIATELY.
		print("AI RULER %s has died. Handling succession now." % full_name)
		GameManager.handle_ruler_death(current_court)

	var log_msg="DEATH: %s of the court of %s has %s at age %d." % [full_name, current_court.kingdom_name, cause, age]
	GameManager.monthly_event_log.append(log_msg)
	GameManager.monthly_chronicle.kingdom_logs[current_court].append(log_msg)
func process_monthly_tick():
	if not is_alive: return
	if player_character: return
	# 1. Handle Pregnancy and Birth
	if is_pregnant:
		pregnancy_term -= 1
		if pregnancy_term <= 0:
			_give_birth()

	# 2. Handle Conception (for female characters)
	elif gender == Gender.FEMALE and spouse and spouse.is_alive and not is_pregnant:
		# Check if character is of child-bearing age
		var age = GameManager.current_year - birth_year
		if age >= 16 and age <= 45:
			# Simple fertility model
			# Base chance is higher for younger characters and those with high Vigor
			var fertility_chance = (60 - age) + (vigor * 2) + (spouse.vigor * 2) # Chance out of 100
			if self.current_court.has_modifier("FestivalSpirit"):
				fertility_chance += 100 
			if self.current_court.has_modifier("GoldenAge"):
				fertility_chance += 150 
				
	
			if randi() % 333 < fertility_chance:
				start_pregnancy()

	# 2. Handle marriage proposal for men
	if gender == Gender.MALE and !spouse:
		var marriage_chance = randi_range(1, 6)
		if marriage_chance==1:
			pass
			#is this needed now?
	# 3. Handle Random Death (from old age or illness)
	#for now player char can't die

	var age = GameManager.current_year - birth_year
	if age > 40:
		# Chance of death increases exponentially with age, reduced by Vigor
		var death_chance = pow(age - 39, 2) / (vigor * 2.0) # Chance out of 1000
		var dice=randi() % 1000
		if dice < death_chance:
			die("died of old age")
			#print("%s died of old age. chance %i of %i" % full_name,dice,death_chance)
		else:
			var deathill_chance = randi() % 1000
			if deathill_chance<(2+GameManager.murder_factor):
				die("been killed")
	else:
		var death_chance = randi() % 500
		if death_chance<(2+GameManager.illness_factor):
			die("died of illness")
			#print("%s died of illness . ", full_name)
			#print("chance: ", death_chance)
		elif age > 16:
			var deathkill_chance = randi() % 800
			if deathkill_chance<(2+GameManager.murder_factor):
				die("been killed")
			
func start_pregnancy():
	
	if not is_instance_valid(spouse):
		# If they are unmarried, we print a warning and stop the function immediately.
		# This prevents the pregnancy from starting and avoids the crash later.
		print("WARNING: Attempted to start pregnancy for unmarried character: ", full_name)
		return
		
	is_pregnant = true
	pregnancy_term = 3 # A pregnancy lasts 3 seasons (9 months)
	spouse_at_inception=spouse
	# Optional: Fire an event to notify the player if this is their spouse
	# EventManager.fire_event("Your wife, %s, is with child!" % character_name)
	print("%s is now pregnant." % full_name)
	var log_msg="PREGNANCY: %s of the court of %s is now pregnant." % [full_name, current_court.kingdom_name]
	GameManager.monthly_event_log.append(log_msg)
	if current_court!= null:
		GameManager.monthly_chronicle.kingdom_logs[current_court].append(log_msg)
	else:
		print("ERROR: no court for ",full_name)



func _give_birth():
	is_pregnant = false
	
	var child = Character.new()
	child.id=GameManager.get_id()
	child.gender = Gender.MALE if randi() % 2 == 0 else Gender.FEMALE
	# child.name = NameGenerator.get_name(dynasty_id, child.gender)
	child.first_name = NameGenerator.get_random_first_name(child.gender)
	
	# 2. Inherit the dynasty name directly from the father.
	# The father is the mother's (self) spouse.
	
	child.dynasty_name = self.spouse_at_inception.dynasty_name
	child.birth_year = GameManager.current_year
	child.dynasty_id = self.spouse_at_inception.dynasty_id # Patrilineal inheritance
	
	# Stat Inheritance: Average of parents +/- some randomness
	child.martial = int((self.martial + spouse_at_inception.martial) / 2.0 + randi_range(-1, 1))
	child.stewardship = int((self.stewardship + spouse_at_inception.stewardship) / 2.0 + randi_range(-1, 1))
	child.diplomacy = int((self.diplomacy + spouse_at_inception.diplomacy) / 2.0 + randi_range(-1, 1))
	child.intrigue = int((self.intrigue + spouse_at_inception.intrigue) / 2.0 + randi_range(-1, 1))
	child.vigor = int((self.vigor + spouse_at_inception.vigor) / 2.0 + randi_range(-1, 1))

	# Family Links
	child.mother = self
	child.father = spouse_at_inception
	self.children.append(child)
	spouse_at_inception.children.append(child)
	
	# Add the child to the game world!
	GameManager.add_character_to_world(child, self.current_court)
	
	# Optional: Fire a major event for the player
	# EventManager.fire_event("A %s is born!" % ["son", "daughter"][child.gender])
	#print("A child is born to %s!" % character_name)
	var log_msg="BIRTH: %s has been born to %s and %s %s of the court of %s." % [child.first_name, child.father.first_name, child.mother.first_name,child.father.dynasty_name, current_court.kingdom_name]
	GameManager.monthly_event_log.append(log_msg)
	GameManager.monthly_chronicle.kingdom_logs[current_court].append(log_msg)
	return child
	
func set_initial_age(age: int):
	# We calculate the birth year based on the game's starting year.
	self.birth_year = GameManager.current_year - age
