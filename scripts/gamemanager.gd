extends Node

@export var master_word_bank: Array[WordData] = []
@export var master_question_bank: Array[QuestionData] = []

@export var category_colors: Array[Color] = [
  Color(0.35, 0.75, 1.0, 1.0),
  Color(1.0, 0.55, 0.35, 1.0),
  Color(1.0, 0.35, 0.6, 1.0),
  Color(0.45, 1.0, 0.5, 1.0),
  Color(0.95, 0.85, 0.35, 1.0),
  Color(0.75, 0.7, 1.0, 1.0)
]

var current_hand: Array[WordData] = []
var selected_speech_line: Array[WordData] = []
var current_question: QuestionData = null

var trust_vs_confusion: float = 50.0
var hype_vs_meme: float = 50.0
var total_score: float = 0.0
var answered_questions: int = 0
var awaiting_round_continue: bool = false

var last_round_score: float = 0.0
var last_round_combo_names: Array[String] = []
var last_round_tone_matches: int = 0
var last_round_speech_text: String = ""

var game_over : bool = false
@export var match_length: float = 120.0 #seconds
var time_left : float = match_length

func reset_match_state() -> void:
  current_hand.clear()
  selected_speech_line.clear()
  current_question = null

  trust_vs_confusion = 50.0
  hype_vs_meme = 50.0
  total_score = 0.0
  answered_questions = 0
  awaiting_round_continue = false

  last_round_score = 0.0
  last_round_combo_names.clear()
  last_round_tone_matches = 0
  last_round_speech_text = ""

  game_over = false
  time_left = match_length

func _ready() -> void:
  randomize()
  load_words_from_json("res://data/words.json")
  load_questions_from_json("res://data/questions.json")
  _ensure_test_input_actions()
  print("console test controls: enter=start round, 1-5=pick word, e=submit answer (1-5 words), r=spin random card, c=clear picks")

func _process(_delta: float) -> void:
  if game_over:
    return

  if not awaiting_round_continue:
    time_left -= _delta

  if Input.is_action_just_pressed("ui_accept"):
    if awaiting_round_continue:
      continue_to_next_question()
      return

    if current_question == null:
      _start_new_round()
    else:
      print("round already active, answer the current question first")

  if Input.is_action_just_pressed("test_pick_1"):
    _pick_word_from_hand(0)
  if Input.is_action_just_pressed("test_pick_2"):
    _pick_word_from_hand(1)
  if Input.is_action_just_pressed("test_pick_3"):
    _pick_word_from_hand(2)
  if Input.is_action_just_pressed("test_pick_4"):
    _pick_word_from_hand(3)
  if Input.is_action_just_pressed("test_pick_5"):
    _pick_word_from_hand(4)

  if Input.is_action_just_pressed("test_evaluate"):
    _evaluate_selected_line()

  if Input.is_action_just_pressed("test_spin"):
    if current_hand.is_empty():
      print("no hand active, press enter to deal")
    else:
      var random_index := randi() % current_hand.size()
      print("manual card spin triggered at slot ", random_index + 1)
      spin_card_at_index(random_index)
      _print_current_hand()

  if Input.is_action_just_pressed("test_clear"):
    selected_speech_line.clear()
    print("cleared selected words")

func _ensure_test_input_actions() -> void:
  _add_key_action("test_pick_1", KEY_1)
  _add_key_action("test_pick_2", KEY_2)
  _add_key_action("test_pick_3", KEY_3)
  _add_key_action("test_pick_4", KEY_4)
  _add_key_action("test_pick_5", KEY_5)
  _add_key_action("test_evaluate", KEY_E)
  _add_key_action("test_spin", KEY_R)
  _add_key_action("test_clear", KEY_C)

func _add_key_action(action_name: String, keycode: Key) -> void:
  if InputMap.has_action(action_name):
    return

  InputMap.add_action(action_name)
  var input_event := InputEventKey.new()
  input_event.keycode = keycode
  InputMap.action_add_event(action_name, input_event)

func _deal_and_preview_hand() -> void:
  if awaiting_round_continue:
    print("cannot deal while feedback is open")
    return

  if master_word_bank.size() < 5:
    push_error("not enough words to deal a hand")
    return

  deal_hand()

  var reroll_count := 0
  while not can_form_sentence(current_hand) and reroll_count < 10:
    reroll_count += 1
    print("hand was invalid, rerolling")
    spin_again()

  if not can_form_sentence(current_hand):
    push_error("unable to build a valid hand after rerolls")
    return

  selected_speech_line.clear()
  print("hand is valid, ready for picks")
  _print_current_hand()

func _start_new_round() -> void:
  if awaiting_round_continue:
    print("finish feedback before starting a new round")
    return

  if master_question_bank.is_empty():
    push_error("no questions loaded")
    return

  current_question = master_question_bank[randi() % master_question_bank.size()]
  selected_speech_line.clear()

  print("new question: " + current_question.text)
  print("target tone: " + current_question.tone)

  _deal_and_preview_hand()

func _pick_word_from_hand(index: int) -> void:
  if awaiting_round_continue:
    print("round is waiting for continue")
    return

  if current_hand.is_empty():
    print("no hand active, press enter to deal")
    return

  if index < 0 or index >= current_hand.size():
    print("that slot is not available")
    return

  var chosen_word := current_hand[index]
  if selected_speech_line.size() >= 5:
    print("answer is already at max length (5)")
    return

  selected_speech_line.append(chosen_word)
  print("picked slot ", index + 1, ": ", chosen_word.text, " (", _category_to_text(chosen_word.category), ")")
  _print_selected_line_preview()

func _evaluate_selected_line() -> void:
  if awaiting_round_continue:
    print("feedback is open, press continue to move on")
    return

  if selected_speech_line.is_empty():
    print("pick at least one word before evaluation")
    return

  if current_question == null:
    print("no active question, press enter to start a round")
    return

  var result = evaluate_speech(selected_speech_line)
  var round_score = result["score"]

  total_score += round_score
  answered_questions += 1

  last_round_score = round_score
  last_round_combo_names = result["combo_names"]
  last_round_tone_matches = result["tone_matches"]
  last_round_speech_text = result["speech_text"]
  awaiting_round_continue = true

  print("round score: ", round_score)
  print("total score after ", answered_questions, " questions: ", total_score)
  print("press enter or continue to see the next question")

  selected_speech_line.clear()

func continue_to_next_question() -> void:
  if not awaiting_round_continue:
    return

  awaiting_round_continue = false
  current_question = null
  _start_new_round()

func _print_current_hand() -> void:
  print("current hand:")
  for i in range(current_hand.size()):
    var word := current_hand[i]
    print(str(i + 1), ": ", word.text, " (", _category_to_text(word.category), ")")

func _print_selected_line_preview() -> void:
  print("current answer (", selected_speech_line.size(), "/5): ", build_sentence(selected_speech_line))

func _category_to_text(category_value: int) -> String:
  var keys := WordData.Category.keys()
  if category_value < 0 or category_value >= keys.size():
    return "unknown"
  return String(keys[category_value]).to_lower()

func load_words_from_json(path: String) -> void:
  if not FileAccess.file_exists(path):
    push_error("json file not found at: ", path)
    return
    
  var file = FileAccess.open(path, FileAccess.READ)
  var json_text = file.get_as_text()
  file.close()
  
  var json = JSON.new()
  var error = json.parse(json_text)
  if error != OK:
    push_error("json parse error: ", json.get_error_message())
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
    
  print("successfully loaded ", master_word_bank.size(), " words from json")

func load_questions_from_json(path: String) -> void:
  if not FileAccess.file_exists(path):
    push_error("questions json file not found at: ", path)
    return

  var file = FileAccess.open(path, FileAccess.READ)
  var json_text = file.get_as_text()
  file.close()

  var json = JSON.new()
  var error = json.parse(json_text)
  if error != OK:
    push_error("questions json parse error: ", json.get_error_message())
    return

  master_question_bank.clear()
  var data_array = json.data

  for item in data_array:
    if not item.has("id") or not item.has("text") or not item.has("tone"):
      continue

    var question = QuestionData.new()
    question.id = String(item["id"]).to_lower()
    question.text = String(item["text"]).to_lower()
    question.tone = String(item["tone"]).to_lower()

    var raw_keywords = item.get("keywords", [])
    var normalized_keywords: Array[String] = []
    for keyword in raw_keywords:
      normalized_keywords.append(String(keyword).to_lower())
    question.keywords = normalized_keywords

    if _category_name_to_value(question.tone) == -1:
      continue

    master_question_bank.append(question)

  print("successfully loaded ", master_question_bank.size(), " questions from json")

func deal_hand() -> void:
  current_hand.clear()
  
  var shuffled_pool = master_word_bank.duplicate()
  shuffled_pool.shuffle()
  
  for i in range(5):
    current_hand.append(shuffled_pool[i])

func can_form_sentence(hand: Array[WordData]) -> bool:
  var rhe: Array[WordData] = []
  var act: Array[WordData] = []
  var pol: Array[WordData] = []
  var absu: Array[WordData] = []
  var emo: Array[WordData] = []
  var clo: Array[WordData] = []

  for word in hand:
    match word.category:
      WordData.Category.RHETORICAL:
        rhe.append(word)
      WordData.Category.ACTION:
        act.append(word)
      WordData.Category.POLICY:
        pol.append(word)
      WordData.Category.ABSURD:
        absu.append(word)
      WordData.Category.EMOTIONAL:
        emo.append(word)
      WordData.Category.CLOSER:
        clo.append(word)
  
  # need at least action + one other category to form a valid sentence
  return not (act.is_empty() or (rhe.is_empty() and pol.is_empty() and absu.is_empty() and emo.is_empty() and clo.is_empty()))

func build_sentence(line: Array[WordData]) -> String:
  if line.is_empty():
    return ""

  var rhetorical := ""
  var action := ""
  var target := ""
  var delivery := ""
  var closer := ""

  for word in line:
    match word.category:
      WordData.Category.RHETORICAL:
        rhetorical = word.text
      WordData.Category.ACTION:
        action = word.text
      WordData.Category.POLICY, WordData.Category.ABSURD:
        target = word.text
      WordData.Category.EMOTIONAL:
        delivery = word.text
      WordData.Category.CLOSER:
        closer = word.text

  var sentence := ""
  if rhetorical != "":
    sentence += rhetorical + " "
  if action != "":
    sentence += action + " "
  if target != "":
    sentence += target + " "
  sentence = sentence.strip_edges()
  if delivery != "":
    sentence += " " + delivery

  sentence = sentence.strip_edges()
  if closer != "":
    if closer.begins_with(",") or closer.begins_with("."):
      sentence += closer
    else:
      sentence += ", " + closer

  return sentence

func _get_random_replacement_for_category(category_value: int) -> WordData:
  var candidates: Array[WordData] = []
  for word in master_word_bank:
    if word.category == category_value and not current_hand.has(word):
      candidates.append(word)

  if candidates.is_empty():
    return null

  return candidates[randi() % candidates.size()]

func spin_card_at_index(index: int) -> void:
  if awaiting_round_continue:
    print("cannot spin while feedback is open")
    return

  if index < 0 or index >= current_hand.size():
    print("invalid card index for spin")
    return

  var original_word = current_hand[index]
  var replacement_word = _get_random_replacement_for_category(original_word.category)
  if replacement_word == null:
    print("no replacement found for category, cannot spin this card")
    return
  
  trust_vs_confusion -= 10

  current_hand[index] = replacement_word
  selected_speech_line.erase(original_word)
  print("spun card ", index + 1, " from ", original_word.text, " to ", replacement_word.text)

func spin_again() -> void:
  if awaiting_round_continue:
    print("cannot spin while feedback is open")
    return

  current_hand.clear()
  selected_speech_line.clear()

  trust_vs_confusion -= 10
  deal_hand()

func evaluate_speech(line: Array[WordData]) -> Dictionary:
  if line.is_empty():
    return {
      "score": 0.0,
      "combo_names": [],
      "tone_matches": 0,
      "speech_text": ""
    }

  var speech_text = build_sentence(line)
  print("player says: \"" + speech_text + "\"")

  var trust_delta = 0.0
  var hype_delta = 0.0

  var categories: Array[int] = []
  for word in line:
    categories.append(word.category)

  var target_tone_category = _category_name_to_value(current_question.tone)

  for i in range(categories.size()):
    var base_effect = _get_base_word_effect(categories[i])
    var position_weight = _get_position_weight(i)
    trust_delta += base_effect["trust"] * position_weight
    hype_delta += base_effect["hype"] * position_weight

  for i in range(categories.size() - 1):
    var transition_effect = _get_transition_effect(categories[i], categories[i + 1])
    trust_delta += transition_effect["trust"]
    hype_delta += transition_effect["hype"]
    if transition_effect["message"] != "":
      print(transition_effect["message"])

  if categories[categories.size() - 1] == WordData.Category.ACTION:
    trust_delta -= 18.0
    hype_delta += 6.0
    print("ending penalty: line closes on unfinished action")

  var unique_categories := {}
  for category_value in categories:
    unique_categories[category_value] = true

  if unique_categories.size() >= 3:
    trust_delta += 7.0
    hype_delta += 7.0
    print("style bonus: category variety")
  elif unique_categories.size() == 1:
    trust_delta -= 15.0
    hype_delta -= 5.0
    print("style penalty: repetitive structure")

  var repeated_text_count = 0
  for i in range(line.size()):
    for j in range(i + 1, line.size()):
      if line[i].text == line[j].text:
        repeated_text_count += 1

  if repeated_text_count > 0:
    trust_delta -= 5.0 * repeated_text_count
    hype_delta -= 4.0 * repeated_text_count
    print("style note: repeated words flatten crowd energy")

  var combo_result = _resolve_combos(categories)
  trust_delta += combo_result["trust"]
  hype_delta += combo_result["hype"]

  for combo_name in combo_result["names"]:
    print("combo unlocked: " + combo_name + "!")

  var tone_match_count = 0
  for category_value in categories:
    if category_value == target_tone_category:
      tone_match_count += 1

  var tone_bonus = 0.0
  if tone_match_count == 1:
    tone_bonus = 10.0
    print("tone bonus: mild alignment")
  elif tone_match_count == 2:
    tone_bonus = 25.0
    print("tone bonus: strong alignment")
  elif tone_match_count == 3:
    tone_bonus = 40.0
    print("tone bonus: perfect alignment")
  elif tone_match_count >= 4:
    tone_bonus = 48.0
    print("tone bonus: dominant alignment")

  var length_modifier = _get_length_modifier(line.size())
  if length_modifier > 0.0:
    print("length bonus: concise response")
  elif length_modifier < 0.0:
    print("length penalty: ramble risk")

  var hype_fatigue = (hype_vs_meme - 50.0) * 0.35
  if hype_fatigue > 0.0:
    print("crowd fatigue: hype momentum is cooling off")
  elif hype_fatigue < 0.0:
    print("crowd recovery: low energy makes spikes easier")
  hype_delta -= hype_fatigue

  var raw_score = 50.0 + trust_delta + hype_delta + tone_bonus + length_modifier
  var length_factor = _get_length_factor(line.size())
  var round_score = max(0.0, raw_score / length_factor)

  print("round delta -> trust: ", trust_delta, " hype: ", hype_delta)
  print("tone matches: ", tone_match_count, " tone bonus: ", tone_bonus)
  print("length factor: ", length_factor)

  trust_vs_confusion = _apply_meter_delta(trust_vs_confusion, trust_delta / length_factor)
  hype_vs_meme = _apply_meter_delta(hype_vs_meme, hype_delta / length_factor)

  _print_curr_audience_reaction()
  return {
    "score": round_score,
    "combo_names": combo_result["names"],
    "tone_matches": tone_match_count,
    "speech_text": speech_text
  }

func _get_base_word_effect(category_value: int) -> Dictionary:
  match category_value:
    WordData.Category.POLICY:
      return {"trust": 12.0, "hype": -6.0}
    WordData.Category.ABSURD:
      return {"trust": -14.0, "hype": -10.0}
    WordData.Category.EMOTIONAL:
      return {"trust": 4.0, "hype": 10.0}
    WordData.Category.ACTION:
      return {"trust": -2.0, "hype": 8.0}
    WordData.Category.RHETORICAL:
      return {"trust": 8.0, "hype": 2.0}
    WordData.Category.CLOSER:
      return {"trust": 6.0, "hype": 4.0}
    _:
      return {"trust": 0.0, "hype": 0.0}

func _get_position_weight(index: int) -> float:
  match index:
    0:
      return 0.9
    1:
      return 1.0
    2:
      return 1.15
    3:
      return 1.05
    4:
      return 0.95
    _:
      return 1.0

func _get_transition_effect(from_category: int, to_category: int) -> Dictionary:
  if from_category == WordData.Category.RHETORICAL and to_category == WordData.Category.ABSURD:
    return {"trust": 10.0, "hype": -6.0, "message": "flow bonus: smooth setup hides nonsense"}
  if from_category == WordData.Category.RHETORICAL and to_category == WordData.Category.POLICY:
    return {"trust": 9.0, "hype": 2.0, "message": "flow bonus: strong rhetorical setup"}
  if from_category == WordData.Category.ACTION and to_category == WordData.Category.CLOSER:
    return {"trust": 8.0, "hype": 8.0, "message": "flow bonus: decisive finish"}
  if from_category == WordData.Category.ABSURD and to_category == WordData.Category.CLOSER:
    return {"trust": -10.0, "hype": -4.0, "message": "flow shift: absurd bridge into confident close"}
  if from_category == WordData.Category.POLICY and to_category == WordData.Category.EMOTIONAL:
    return {"trust": 6.0, "hype": 6.0, "message": "flow bonus: facts into empathy"}
  if from_category == WordData.Category.EMOTIONAL and to_category == WordData.Category.POLICY:
    return {"trust": 7.0, "hype": -3.0, "message": "flow bonus: emotional setup grounded by policy"}
  if from_category == WordData.Category.POLICY and to_category == WordData.Category.POLICY:
    return {"trust": 4.0, "hype": -6.0, "message": "flow note: policy stack feels dry"}
  return {"trust": 0.0, "hype": 0.0, "message": ""}

func _resolve_combos(categories: Array[int]) -> Dictionary:
  var combo_definitions = [
    {"name": "the scapegoat", "pattern": [3, 1, 2], "trust": -10.0, "hype": 12.0},
    {"name": "the empty promise", "pattern": [4, 0, 5], "trust": 25.0, "hype": -10.0},
    {"name": "the debate dodge", "pattern": [4, 1, 5], "trust": -20.0, "hype": 8.0},
    {"name": "the spreadsheet sermon", "pattern": [0, 0, 5], "trust": 22.0, "hype": -14.0},
    {"name": "the rally cry", "pattern": [3, 2, 5], "trust": 8.0, "hype": 14.0},
    {"name": "the fever dream", "pattern": [1, 1, 2], "trust": -24.0, "hype": -18.0},
    {"name": "the pivot sprint", "pattern": [4, 3, 0], "trust": 14.0, "hype": 10.0},
    {"name": "the heartland memo", "pattern": [2, 0, 5], "trust": 18.0, "hype": 8.0},
    {"name": "the whiplash agenda", "pattern": [3, 0, 3], "trust": -12.0, "hype": 10.0},
    {"name": "the teleprompter loop", "pattern": [5, 4, 5], "trust": 10.0, "hype": -8.0},
    {"name": "the slogan loop", "pattern": [4, 4], "trust": 4.0, "hype": 5.0},
    {"name": "the red button", "pattern": [3, 3], "trust": -8.0, "hype": 8.0}
  ]

  var total_trust = 0.0
  var total_hype = 0.0
  var unlocked_names: Array[String] = []

  for combo in combo_definitions:
    var pattern: Array = combo["pattern"]
    if _line_contains_pattern(categories, pattern):
      total_trust += combo["trust"]
      total_hype += combo["hype"]
      unlocked_names.append(combo["name"])

  return {"trust": total_trust, "hype": total_hype, "names": unlocked_names}

func _line_contains_pattern(categories: Array[int], pattern: Array) -> bool:
  if pattern.size() > categories.size():
    return false

  for i in range(categories.size() - pattern.size() + 1):
    var matches = true
    for j in range(pattern.size()):
      if categories[i + j] != pattern[j]:
        matches = false
        break
    if matches:
      return true

  return false

func _get_length_modifier(length: int) -> float:
  match length:
    1:
      return 8.0
    2:
      return 4.0
    3:
      return 0.0
    4:
      return -5.0
    5:
      return -10.0
    _:
      return -15.0

func _apply_meter_delta(current_value: float, delta: float) -> float:
  var scaled_delta = delta
  if scaled_delta > 0.0:
    scaled_delta *= (100.0 - current_value) / 100.0
  elif scaled_delta < 0.0:
    scaled_delta *= current_value / 100.0

  return clamp(current_value + scaled_delta, 0.0, 100.0)

func _get_length_factor(length: int) -> float:
  match length:
    1:
      return 0.9
    2:
      return 1.0
    3:
      return 1.0
    4:
      return 1.05
    5:
      return 1.12
    _:
      return 1.2

func _category_name_to_value(category_name: String) -> int:
  var category_map = {
    "policy": WordData.Category.POLICY,
    "absurd": WordData.Category.ABSURD,
    "emotional": WordData.Category.EMOTIONAL,
    "action": WordData.Category.ACTION,
    "rhetorical": WordData.Category.RHETORICAL,
    "closer": WordData.Category.CLOSER
  }

  if category_map.has(category_name):
    return category_map[category_name]

  return -1

func _print_curr_audience_reaction() -> void:
  print("--- audience status ---")
  print("trust scale (100=trust, 0=confusion): ", trust_vs_confusion)
  print("vibe scale (100=hype, 0=meme culture): ", hype_vs_meme)
  print("-----------------------")
