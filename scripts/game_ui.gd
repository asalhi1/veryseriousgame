extends Control

enum CharaExpression { NEUTRAL, EYES_CLOSED, NERVOUS, STRESSED, LAUGH, SURPRISED }

@export var category_colors: Array[Color] = [
  Color(0.35, 0.75, 1.0, 1.0),
  Color(1.0, 0.55, 0.35, 1.0),
  Color(1.0, 0.35, 0.6, 1.0),
  Color(0.45, 1.0, 0.5, 1.0),
  Color(0.95, 0.85, 0.35, 1.0),
  Color(0.75, 0.7, 1.0, 1.0)
]
@export var crowd_bob_amount_range: Vector2 = Vector2(10.0, 20.0)
@export var crowd_bob_duration_range: Vector2 = Vector2(0.08, 0.16)
@export var spinner_word_count: int = 16
@export var spinner_radius_ratio: float = 0.36
@export var spinner_label_size: Vector2 = Vector2(340.0, 70.0)
@export var spinner_label_font_size: int = 128
@export var spinner_label_outline_size: int = 14
@export var single_spin_trust_penalty: float = 4.0
@export var meter_tween_duration: float = 0.35
@export var timer_tween_duration: float = 0.15
@export var timer_tween_update_interval: float = 0.08

var current_expression: CharaExpression = CharaExpression.NEUTRAL
var tone_to_expression := {
  "policy": CharaExpression.NEUTRAL,
  "absurd": CharaExpression.SURPRISED,
  "emotional": CharaExpression.EYES_CLOSED,
  "action": CharaExpression.STRESSED,
  "rhetorical": CharaExpression.LAUGH,
  "closer": CharaExpression.NERVOUS
}

@onready var preview_lbl: Label = $active_sentence_lbl
@onready var wheel_spinner: TextureButton = $MarginContainer/main_vertical_stack/top_half_view/spin_panel/VBoxContainer/wheel_spinner
@onready var wheel_bg: TextureRect = $MarginContainer/main_vertical_stack/top_half_view/spin_panel/VBoxContainer/wheel_spinner/wheel_bg
@onready var reporter_bubble: Control = $MarginContainer/main_vertical_stack/top_half_view/feed_panel/crowd_display/reporter_bubble
@onready var question_lbl: Label = $MarginContainer/main_vertical_stack/top_half_view/feed_panel/crowd_display/reporter_bubble/margin/question_lbl
@onready var time_bar: TextureProgressBar = $MarginContainer/main_vertical_stack/top_half_view/feed_panel/crowd_display/game_clock
@onready var timer_lbl: Label = $MarginContainer/main_vertical_stack/top_half_view/feed_panel/crowd_display/game_clock/timer_lbl
@onready var trust_bar: Range = $MarginContainer/main_vertical_stack/top_half_view/feed_panel/metrics_bar/metrics_layout/trust_area/trust_bar
@onready var vibe_bar: Range = $MarginContainer/main_vertical_stack/top_half_view/feed_panel/metrics_bar/metrics_layout/vibe_area/vibe_bar
@onready var emergency_flush_btn: TextureButton = $MarginContainer/main_vertical_stack/hand_mat/bottom_half_desk/left_utility_dock/emergency_flush_btn
#@onready var round_counter_panel: PanelContainer = $MarginContainer/main_vertical_stack/hand_mat/bottom_half_desk/left_utility_dock/round_counter_panel
@onready var clear_speech_btn: TextureButton = $MarginContainer/main_vertical_stack/hand_mat/bottom_half_desk/right_actions_dock/clear_speech_btn
@onready var deliver_speech_btn: TextureButton = $MarginContainer/main_vertical_stack/hand_mat/bottom_half_desk/right_actions_dock/deliver_speech_btn
@onready var blackout_overlay: ColorRect = $MarginContainer/main_vertical_stack/top_half_view/spin_panel/black_rect

@onready var crowd: TextureRect = $MarginContainer/main_vertical_stack/top_half_view/feed_panel/crowd_display/crowd

@onready var politician_node: Sprite2D = $Politician

@onready var ending_screen: PanelContainer = $ending_screen
@onready var ending_title_lbl: Label = $ending_screen/HBoxContainer/VBoxContainer/ending_title_lbl
@onready var ending_desc_lbl: Label = $ending_screen/HBoxContainer/VBoxContainer/ending_desc_lbl
@onready var restart_btn: TextureButton = $ending_screen/HBoxContainer/VBoxContainer/menu_button

@onready var transcript_container: VBoxContainer = $ending_screen/HBoxContainer/ScrollContainer/transcript_container
var history: Array[Dictionary] = []

@onready var hand_cards = [
  $MarginContainer/main_vertical_stack/hand_mat/bottom_half_desk/hand_mat_center/hand_cards_center/card0,
  $MarginContainer/main_vertical_stack/hand_mat/bottom_half_desk/hand_mat_center/hand_cards_center/card1,
  $MarginContainer/main_vertical_stack/hand_mat/bottom_half_desk/hand_mat_center/hand_cards_center/card2,
  $MarginContainer/main_vertical_stack/hand_mat/bottom_half_desk/hand_mat_center/hand_cards_center/card3,
  $MarginContainer/main_vertical_stack/hand_mat/bottom_half_desk/hand_mat_center/hand_cards_center/card4
]

var expression_textures: Array[Texture2D] = [
  preload("res://assets/art/politician.png"),
  preload("res://assets/art/politician eyes closed.png"),
  preload("res://assets/art/politician okok.png"),
  preload("res://assets/art/politician ouff.png"),
  preload("res://assets/art/politician hehe.png"),
  preload("res://assets/art/politician surpr.png")
]
var crowd_base_y: float = 0.0
var crowd_bob_tween: Tween
var blackout_tween: Tween
var trust_bar_tween: Tween
var vibe_bar_tween: Tween
var time_bar_tween: Tween
var timer_tween_accumulator: float = 0.0
var is_spinner_animating: bool = false
var spinner_word_labels: Array[Label] = []
var spinner_words: Array[WordData] = []

func _ready() -> void:
  for i in range(hand_cards.size()):
    var card = hand_cards[i]
    if card.has_signal("clicked") and not card.clicked.is_connected(_on_card_selected):
      card.clicked.connect(_on_card_selected)
    if card.has_signal("gui_input"):
      var right_click_callable := Callable(self, "_on_card_gui_input").bind(i)
      if not card.gui_input.is_connected(right_click_callable):
        card.gui_input.connect(right_click_callable)

  clear_speech_btn.pressed.connect(_on_clear_pressed)
  deliver_speech_btn.pressed.connect(_on_deliver_or_continue_pressed)
  
  if emergency_flush_btn:
    emergency_flush_btn.pressed.connect(_on_emergency_flush_pressed)

  restart_btn.pressed.connect(_on_restart_pressed)

  if crowd:
    crowd_base_y = crowd.position.y

  #if wheel_bg:
    #wheel_bg.pivot_offset = wheel_bg.size * 0.5

  time_bar.max_value = GameManager.time_left
  time_bar.value = time_bar.max_value
  trust_bar.value = GameManager.trust_vs_confusion
  vibe_bar.value = GameManager.hype_vs_meme

  ending_screen.visible = false

  GameManager._start_new_round()
  _update_ui_display()

func _process(_delta: float) -> void:
  timer_lbl.text = str(int(ceil(max(GameManager.time_left, 0.0)))) + "s"
  timer_tween_accumulator += _delta
  if timer_tween_accumulator >= timer_tween_update_interval:
    timer_tween_accumulator = 0.0
    _tween_time_bar(GameManager.time_left)
  _check_for_game_end()

func _check_for_game_end() -> void:
  if ending_screen.visible:
    return
  
  if GameManager.trust_vs_confusion <= 0.0:
    _trigger_ending(
      "THE IMPEACHMENT ENDING",
      "You've been impeached! The public has lost all trust in you, and your political career is over."
    )
    return
  
  if GameManager.hype_vs_meme <= 0.0:
    _trigger_ending(
      "THE CANCEL CULTURE ENDING",
      "You've been canceled! The public has turned against you, and your political career is over."
    )
    return
  
  if GameManager.time_left <= 0.0:
    # high hype high trust
    if GameManager.trust_vs_confusion >= 75.0 and GameManager.hype_vs_meme >= 75.0:
      _trigger_ending(
        "THE AWESOME ENDING",
        "Congratulations! You've managed to maintain high trust and hype throughout your campaign, securing a successful political career."
      )
    # high hype low trust
    elif GameManager.trust_vs_confusion < 30.0 and GameManager.hype_vs_meme >= 75.0:
      _trigger_ending(
        "THE CHAOS ENDING",
        "You've managed to create a lot of hype, but your trustworthiness has plummeted. Your campaign is in chaos, and your political future is uncertain."
      )
    # avg
    else:
      _trigger_ending(
        "THE AVERAGE ENDING",
        "Your campaign has been mediocre, with neither significant hype nor trust. Your political future remains uncertain."
      )

func _trigger_ending(title: String, description: String) -> void:
  set_process(false)

  ending_title_lbl.text = title
  ending_desc_lbl.text = description

  for child in transcript_container.get_children():
    if is_instance_valid(child) and not child.is_in_group("keep"):
      child.queue_free()
  
  if history.is_empty():
    var empty_lbl = Label.new()
    empty_lbl.text = "You didn't even answer a single question. Impressive."
    empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
    empty_lbl.custom_minimum_size = Vector2(1000, 0)
    transcript_container.add_child(empty_lbl)
  else:
    for round_entry in history:
      var round_lbl = Label.new()
      round_lbl.text = "Q: " + round_entry["question"] + "\nA: " + round_entry["answer"]
      round_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
      round_lbl.custom_minimum_size = Vector2(1000, 0)
      transcript_container.add_child(round_lbl)

  ending_screen.visible = true

func _on_restart_pressed() -> void:
  GameManager.reset_match_state()
  get_tree().reload_current_scene()

func _update_ui_display() -> void:
  var words = []
  for word_resource in GameManager.selected_speech_line:
    words.append(word_resource.text)
  preview_lbl.text = "YOUR SPEECH: \"" + " ".join(words) + "\""

  if GameManager.awaiting_round_continue:
    var feedback_text = "ROUND SCORE: " + str(int(round(GameManager.last_round_score))) + "\n"
    feedback_text += "TONE MATCHES: " + str(GameManager.last_round_tone_matches) + "\n"
    
    if GameManager.last_round_combo_names.is_empty():
      feedback_text += "COMBOS: None"
    else:
      feedback_text += "COMBOS: " + ", ".join(GameManager.last_round_combo_names)
      
    question_lbl.text = feedback_text
    question_lbl.add_theme_color_override("font_color", Color.WHITE)
    _set_expression(CharaExpression.NEUTRAL)
  else:
    if GameManager.current_question:
      question_lbl.text = "REPORTER: \"" + GameManager.current_question.text + "\"\n"
      question_lbl.text += "[Target Vibe: " + GameManager.current_question.tone.to_upper() + "]"
      question_lbl.add_theme_color_override("font_color", _get_tone_color(GameManager.current_question.tone))
      _update_politician_expression_for_tone(GameManager.current_question.tone)
    else:
      question_lbl.text = "Waiting for the next question..."
      question_lbl.add_theme_color_override("font_color", Color.WHITE)
      _set_expression(CharaExpression.NEUTRAL)

  var lock_inputs = GameManager.awaiting_round_continue
  reporter_bubble.visible = not lock_inputs
  for i in range(hand_cards.size()):
    if i < GameManager.current_hand.size():
      var card_data = GameManager.current_hand[i]
      var card = hand_cards[i]

      if card.has_method("setup_card_data"):
        card.setup_card_data(card_data, i)

      var is_selected = GameManager.selected_speech_line.has(card_data)
      card.visible = true
      var category_color := _get_category_color(card_data.category)
      var alpha := 0.35 if is_selected else 1.0
      card.modulate = Color(category_color.r, category_color.g, category_color.b, alpha)
      card.mouse_filter = Control.MOUSE_FILTER_IGNORE if (lock_inputs or is_selected) else Control.MOUSE_FILTER_STOP
    else:
      hand_cards[i].visible = false

  clear_speech_btn.disabled = lock_inputs
  wheel_spinner.disabled = lock_inputs
  emergency_flush_btn.disabled = lock_inputs

  _tween_trust_bar(GameManager.trust_vs_confusion)
  _tween_vibe_bar(GameManager.hype_vs_meme)

func _tween_trust_bar(target_value: float) -> void:
  var clamped_target = clamp(target_value, trust_bar.min_value, trust_bar.max_value)
  if abs(trust_bar.value - clamped_target) < 0.01:
    trust_bar.value = clamped_target
    return

  if is_instance_valid(trust_bar_tween):
    trust_bar_tween.kill()

  trust_bar_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
  trust_bar_tween.tween_property(trust_bar, "value", clamped_target, meter_tween_duration)

func _tween_vibe_bar(target_value: float) -> void:
  var clamped_target = clamp(target_value, vibe_bar.min_value, vibe_bar.max_value)
  if abs(vibe_bar.value - clamped_target) < 0.01:
    vibe_bar.value = clamped_target
    return

  if is_instance_valid(vibe_bar_tween):
    vibe_bar_tween.kill()

  vibe_bar_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
  vibe_bar_tween.tween_property(vibe_bar, "value", clamped_target, meter_tween_duration)

func _tween_time_bar(target_value: float) -> void:
  var clamped_target = clamp(target_value, time_bar.min_value, time_bar.max_value)
  if abs(time_bar.value - clamped_target) < 0.01:
    time_bar.value = clamped_target
    return

  if is_instance_valid(time_bar_tween):
    time_bar_tween.kill()

  time_bar_tween = create_tween().set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_OUT)
  time_bar_tween.tween_property(time_bar, "value", clamped_target, timer_tween_duration)

func _on_card_selected(index: int) -> void:
  GameManager._pick_word_from_hand(index)
  _update_ui_display()

func _on_spin_pressed() -> void:
  if is_spinner_animating:
    return

  if GameManager.current_hand.is_empty():
    return

  if GameManager.master_word_bank.is_empty():
    return

  var available_indices := _get_available_spin_indices()

  if available_indices.is_empty():
    return

  var random_index: int = available_indices[randi() % available_indices.size()]
  await _spin_into_card_index(random_index)

func _on_card_gui_input(event: InputEvent, index: int) -> void:
  if is_spinner_animating:
    return

  if not (event is InputEventMouseButton):
    return

  var mouse_event := event as InputEventMouseButton
  if mouse_event.button_index != MOUSE_BUTTON_RIGHT or not mouse_event.pressed:
    return

  await _spin_into_card_index(index)

func _get_available_spin_indices() -> Array[int]:
  var available_indices: Array[int] = []
  for i in range(GameManager.current_hand.size()):
    if not GameManager.selected_speech_line.has(GameManager.current_hand[i]):
      available_indices.append(i)
  return available_indices

func _spin_into_card_index(target_index: int) -> void:
  if is_spinner_animating:
    return

  if target_index < 0 or target_index >= GameManager.current_hand.size():
    return

  var target_word: WordData = GameManager.current_hand[target_index]
  if GameManager.selected_speech_line.has(target_word):
    return

  is_spinner_animating = true
  var selected_word := await _play_spinner_animation()
  if selected_word:
    _apply_spinner_word_to_card(target_index, selected_word)

  is_spinner_animating = false
  _update_ui_display()

func log_current_round(question_text: String, answer_text: String) -> void:
  var round_entry: Dictionary = {
    "question": question_text,
    "answer": answer_text
  }
  history.append(round_entry)  

func _on_clear_pressed() -> void:
  GameManager.selected_speech_line.clear()
  _update_ui_display()

func _on_deliver_or_continue_pressed() -> void:
  if GameManager.awaiting_round_continue:
    GameManager.continue_to_next_question()
  else:
    var submitted_speech := GameManager.build_sentence(GameManager.selected_speech_line)
    GameManager._evaluate_selected_line()
    if GameManager.awaiting_round_continue:
      var completed_speech := GameManager.last_round_speech_text
      if completed_speech.strip_edges() == "":
        completed_speech = submitted_speech
      log_current_round(GameManager.current_question.text, completed_speech.strip_edges())
      _play_crowd_bob()
  _update_ui_display()

func _on_emergency_flush_pressed() -> void:
  if is_spinner_animating:
    return

  if GameManager.current_hand.is_empty():
    return

  if GameManager.master_word_bank.is_empty():
    return

  is_spinner_animating = true
  await _play_spinner_animation()
  GameManager.spin_again()
  is_spinner_animating = false
  _update_ui_display()

func _play_spinner_animation() -> WordData:
  _set_blackout_overlay(true)
  _populate_spinner_words(spinner_word_count)
  await get_tree().create_timer(0.2).timeout
  _set_blackout_overlay(false)

  wheel_bg.rotation_degrees = 0.0
  var extra_turns := randi_range(5, 8)
  var final_degrees := float(extra_turns * 360 + randi_range(0, 359))
  var spin_duration := randf_range(1.8, 2.6)
  var spin_tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
  spin_tween.tween_property(wheel_bg, "rotation_degrees", final_degrees, spin_duration)
  await spin_tween.finished

  var selected_word := _get_top_spinner_word()
  _clear_spinner_words()
  wheel_bg.rotation_degrees = 0.0
  return selected_word

func _get_category_color(category_value: int) -> Color:
  if category_value >= 0 and category_value < category_colors.size():
    return category_colors[category_value]
  return Color.WHITE

func _get_tone_color(tone: String) -> Color:
  match tone.to_lower():
    "policy":
      return _get_category_color(0)
    "absurd":
      return _get_category_color(1)
    "emotional":
      return _get_category_color(2)
    "action":
      return _get_category_color(3)
    "rhetorical":
      return _get_category_color(4)
    "closer":
      return _get_category_color(5)
    _:
      return Color.WHITE

func _update_politician_expression_for_tone(tone: String) -> void:
  var normalized_tone := tone.to_lower()
  if tone_to_expression.has(normalized_tone):
    _set_expression(tone_to_expression[normalized_tone])
  else:
    _set_expression(CharaExpression.NEUTRAL)

func _set_expression(expression: CharaExpression) -> void:
  current_expression = expression
  var expression_index: int = int(expression)
  if expression_index >= 0 and expression_index < expression_textures.size() and politician_node:
    politician_node.texture = expression_textures[expression_index]

func _set_blackout_overlay(active: bool) -> void:
  if not blackout_overlay:
    return

  if is_instance_valid(blackout_tween):
    blackout_tween.kill()

  if active:
    blackout_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

  blackout_overlay.color = Color(0, 0, 0, blackout_overlay.color.a)
  var target_alpha: float = 1.0 if active else 0.0
  blackout_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
  blackout_tween.tween_property(blackout_overlay, "color:a", target_alpha, 0.2)

  if not active:
    blackout_tween.tween_callback(_set_blackout_mouse_ignore)

func _set_blackout_mouse_ignore() -> void:
  if blackout_overlay:
    blackout_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _populate_spinner_words(word_count: int) -> void:
  _clear_spinner_words()

  var source_pool: Array[WordData] = []
  for word in GameManager.master_word_bank:
    if not GameManager.current_hand.has(word):
      source_pool.append(word)

  if source_pool.size() < word_count:
    source_pool = GameManager.master_word_bank.duplicate()

  source_pool.shuffle()
  spinner_words.clear()
  var selection_count: int = min(word_count, source_pool.size())
  for i in range(selection_count):
    spinner_words.append(source_pool[i])

  if spinner_words.is_empty():
    return

  var center: Vector2 = wheel_bg.size * 0.5
  var radius: float = min(wheel_bg.size.x, wheel_bg.size.y) * spinner_radius_ratio
  for i in range(spinner_words.size()):
    var label := Label.new()
    label.text = spinner_words[i].text
    label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    label.size = spinner_label_size
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.add_theme_font_size_override("font_size", spinner_label_font_size)
    label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
    label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
    label.add_theme_constant_override("outline_size", spinner_label_outline_size)

    var angle: float = -PI / 2.0 + (TAU * float(i) / float(spinner_words.size())) + 30.0
    var point: Vector2 = center + Vector2(cos(angle), sin(angle)) * radius
    label.position = point - (label.size * 0.5)
    label.pivot_offset_ratio = Vector2(0.5, 0.5)
    label.rotation = angle

    wheel_bg.add_child(label)
    spinner_word_labels.append(label)

func _clear_spinner_words() -> void:
  for label in spinner_word_labels:
    if is_instance_valid(label):
      label.queue_free()
  spinner_word_labels.clear()
  spinner_words.clear()

func _get_top_spinner_word() -> WordData:
  if spinner_word_labels.is_empty() or spinner_words.is_empty():
    return null

  var top_index := -1
  var top_y := INF
  for i in range(spinner_word_labels.size()):
    var label := spinner_word_labels[i]
    if not is_instance_valid(label):
      continue
    var rect := label.get_global_rect()
    var center_y := rect.position.y + rect.size.y * 0.5
    if center_y < top_y:
      top_y = center_y
      top_index = i

  if top_index >= 0 and top_index < spinner_words.size():
    return spinner_words[top_index]
  return null

func _apply_spinner_word_to_card(card_index: int, replacement_word: WordData) -> void:
  if card_index < 0 or card_index >= GameManager.current_hand.size():
    return

  if replacement_word == null:
    return

  var original_word: WordData = GameManager.current_hand[card_index]
  GameManager.current_hand[card_index] = replacement_word
  GameManager.selected_speech_line.erase(original_word)
  GameManager.trust_vs_confusion -= single_spin_trust_penalty

func _play_crowd_bob() -> void:
  if not crowd:
    return

  if is_instance_valid(crowd_bob_tween):
    crowd_bob_tween.kill()

  var bob_amount := randf_range(crowd_bob_amount_range.x, crowd_bob_amount_range.y)
  var bob_duration := randf_range(crowd_bob_duration_range.x, crowd_bob_duration_range.y)

  crowd.position.y = crowd_base_y
  crowd_bob_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
  crowd_bob_tween.tween_property(crowd, "position:y", crowd_base_y - bob_amount, bob_duration)
  crowd_bob_tween.tween_property(crowd, "position:y", crowd_base_y, bob_duration)
