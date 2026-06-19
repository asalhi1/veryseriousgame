extends Node

@export var master_word_bank: Array[WordData] = []

var current_hand: Array[WordData] = []
var selected_speech_line: Array[WordData] = []

var trust_vs_confusion: float = 50.0
var hype_vs_meme: float = 50.0

func _ready() -> void:
	randomize()
	# 1. Load the words
	load_words_from_json("res://data/words.json")
	
	# 2. Test Deal Hand (Verifies the rig constraint works)
	deal_hand()

func _find_word_by_text(search_text: String) -> WordData:
	for word in master_word_bank:
		if word.text == search_text:
			return word
	return null

func load_words_from_json(path: String) -> void:
	if not FileAccess.file_exists(path):
		push_error("JSON file not found at: ", path)
		return
		
	var file = FileAccess.open(path, FileAccess.READ)
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		push_error("JSON Parse Error: ", json.get_error_message())
		return
		
	var data_array = json.data
	master_word_bank.clear()
	
	var category_map = {
		"policy": WordData.Category.POLICY,
		"absurd": WordData.Category.ABSURD,
		"emotional": WordData.Category.EMOTIONAL,
		"action": WordData.Category.ACTION,
		"rhetorical": WordData.Category.RHETORICAL,
		"closer": WordData.Category.CLOSER
	}
	
	for item in data_array:
		var new_word = WordData.new()
		new_word.text = item["text"]
		
		var cat_string = item["category"].to_lower()
		if category_map.has(cat_string):
			new_word.category = category_map[cat_string]
		else:
			new_word.category = WordData.Category.ABSURD
			
		master_word_bank.append(new_word)
		
	print("Successfully loaded ", master_word_bank.size(), " words from json")

func deal_hand() -> void:
	current_hand.clear()
	selected_speech_line.clear()

	var setups: Array[WordData] = []
	var bridges: Array[WordData] = []
	var punchlines: Array[WordData] = []

	for word in master_word_bank:
		match word.category:
			WordData.Category.RHETORICAL, WordData.Category.ACTION:
				setups.append(word)
			WordData.Category.POLICY, WordData.Category.ABSURD:
				bridges.append(word)
			WordData.Category.EMOTIONAL, WordData.Category.CLOSER:
				punchlines.append(word)

	if setups.is_empty() or bridges.is_empty() or punchlines.is_empty():
		push_error("master word bank is missing categories")
		return

	setups.shuffle()
	bridges.shuffle()
	punchlines.shuffle()

	current_hand.append(setups[0])
	current_hand.append(setups[1])
	current_hand.append(bridges[0])
	current_hand.append(bridges[1])
	current_hand.append(punchlines[0])

	current_hand.shuffle()

	print("new hand dealt")
	for i in range(current_hand.size()):
		print(str(i) + ": [" + current_hand[i].text + "] Type: " + str(current_hand[i].category))

func evaluate_speech(slot1: WordData, slot2: WordData, slot3: WordData) -> void:
	var speech_text = slot1.text + " " + slot2.text + " " + slot3.text
	print("Player says: \"" + speech_text + "\"")

	var trust_delta = 0.0
	var hype_delta = 0.0

	var line = [slot1, slot2, slot3]

	for word in line:
		match word.Category:
			WordData.Category.POLICY:
				trust_delta += 10.0
			WordData.Category.ABSURD:
				trust_delta -= 10.0
				hype_delta -= 5.0
			WordData.Category.EMOTIONAL:
				hype_delta += 15.0
			WordData.Category.ACTION:
				hype_delta += 10.0

	# If they put an action/rhetorical prompt right before absolute nonsense, it hides it well
	if slot1.category == WordData.Category.RHETORICAL and slot2.category == WordData.Category.ABSURD:
		trust_delta += 15.0 # The 'Smooth Talker' safety net
		
	# Ending a speech on an uncompleted verb creates extreme confusion
	if slot3.category == WordData.Category.ACTION:
		trust_delta -= 25.0
  
	var combo_signature = [slot1.Category, slot2.Category, slot3.Category]

	if combo_signature == [WordData.Category.ACTION, WordData.Category.ABSURD, WordData.Category.EMOTIONAL]:
		print("combo unlocked: the scapegoat!")
		hype_delta += 30.0
		trust_delta -= 10.0 # Absolute chaos but highly memeable
	elif combo_signature == [WordData.Category.RHETORICAL, WordData.Category.POLICY, WordData.Category.CLOSER]:
		print("combo unlocked: the empty promise!")
		trust_delta += 25.0
		hype_delta -= 10.0 # Safe, structured, utterly boring

	trust_vs_confusion = clamp(trust_vs_confusion + trust_delta, 0.0, 100.0)
	hype_vs_meme = clamp(hype_vs_meme + hype_delta, 0.0, 100.0)

	_print_curr_audience_reaction()

func _print_curr_audience_reaction() -> void:
	print("--- AUDIENCE STATUS ---")
	print("Trust Scale (100=Trust, 0=Confusion): ", trust_vs_confusion)
	print("Vibe Scale (100=Hype, 0=Meme Culture): ", hype_vs_meme)
	print("-----------------------")
