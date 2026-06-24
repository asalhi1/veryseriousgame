extends Control

@onready var preview_lbl: Label = $MarginContainer/speech_preview_strip/active_sentence_lbl
@onready var wheel_spinner: TextureButton = $MarginContainer/main_vertical_stack/top_half_view/spin_panel/wheel_bg/wheel_spinner
@onready var reporter_bubble: Control = $MarginContainer/main_vertical_stack/top_half_view/feed_panel/crowd_display/reporter_bubble
@onready var question_lbl: Label = $MarginContainer/main_vertical_stack/top_half_view/feed_panel/crowd_display/reporter_bubble/margin/question_lbl
@onready var time_bar: TextureProgressBar = $MarginContainer/main_vertical_stack/top_half_view/feed_panel/crowd_display/game_clock
@onready var timer_lbl: Label = $MarginContainer/main_vertical_stack/top_half_view/feed_panel/crowd_display/game_clock/timer_lbl
@onready var trust_bar: Range = $MarginContainer/main_vertical_stack/top_half_view/feed_panel/metrics_bar/metrics_layout/trust_area/trust_bar
@onready var vibe_bar: Range = $MarginContainer/main_vertical_stack/top_half_view/feed_panel/metrics_bar/metrics_layout/vibe_area/vibe_bar
@onready var emergency_flush_btn: TextureButton = $MarginContainer/main_vertical_stack/hand_mat/bottom_half_desk/left_utility_dock/emergency_flush_btn
@onready var round_counter_panel: PanelContainer = $MarginContainer/main_vertical_stack/hand_mat/bottom_half_desk/left_utility_dock/round_counter_panel
@onready var clear_speech_btn: TextureButton = $MarginContainer/main_vertical_stack/hand_mat/bottom_half_desk/right_actions_dock/clear_speech_btn
@onready var deliver_speech_btn: TextureButton = $MarginContainer/main_vertical_stack/hand_mat/bottom_half_desk/right_actions_dock/deliver_speech_btn

@onready var hand_cards = [
  $MarginContainer/main_vertical_stack/hand_mat/bottom_half_desk/hand_mat_center/hand_cards_center/card0,
  $MarginContainer/main_vertical_stack/hand_mat/bottom_half_desk/hand_mat_center/hand_cards_center/card1,
  $MarginContainer/main_vertical_stack/hand_mat/bottom_half_desk/hand_mat_center/hand_cards_center/card2,
  $MarginContainer/main_vertical_stack/hand_mat/bottom_half_desk/hand_mat_center/hand_cards_center/card3,
  $MarginContainer/main_vertical_stack/hand_mat/bottom_half_desk/hand_mat_center/hand_cards_center/card4
]

func _ready() -> void:
  for card in hand_cards:
    if card.has_signal("clicked") and not card.clicked.is_connected(_on_card_selected):
      card.clicked.connect(_on_card_selected)

  if wheel_spinner and not wheel_spinner.pressed.is_connected(_on_spin_pressed):
    wheel_spinner.pressed.connect(_on_spin_pressed)

  clear_speech_btn.pressed.connect(_on_clear_pressed)
  deliver_speech_btn.pressed.connect(_on_deliver_or_continue_pressed)
  
  if emergency_flush_btn:
    emergency_flush_btn.pressed.connect(_on_emergency_flush_pressed)

  time_bar.max_value = GameManager.time_left
  time_bar.value = time_bar.max_value

  GameManager._start_new_round()
  _update_ui_display()

func _process(_delta: float) -> void:
  timer_lbl.text = str(int(ceil(max(GameManager.time_left, 0.0)))) + "s"
  time_bar.value = GameManager.time_left

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
  else:
    if GameManager.current_question:
      question_lbl.text = "REPORTER: \"" + GameManager.current_question.text + "\"\n"
      question_lbl.text += "[Target Vibe: " + GameManager.current_question.tone.to_upper() + "]"
    else:
      question_lbl.text = "Waiting for the next question..."

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

  trust_bar.value = GameManager.trust_vs_confusion
  vibe_bar.value = GameManager.hype_vs_meme

func _on_card_selected(index: int) -> void:
  GameManager._pick_word_from_hand(index)
  _update_ui_display()

func _on_spin_pressed() -> void:
  if GameManager.current_hand.is_empty():
    return

  var available_indices: Array[int] = []
  for i in range(GameManager.current_hand.size()):
    if not GameManager.selected_speech_line.has(GameManager.current_hand[i]):
      available_indices.append(i)

  if available_indices.is_empty():
    return

  var random_index: int = available_indices[randi() % available_indices.size()]
  GameManager.spin_card_at_index(random_index)
  _update_ui_display()

func _on_clear_pressed() -> void:
  GameManager.selected_speech_line.clear()
  _update_ui_display()

func _on_deliver_or_continue_pressed() -> void:
  if GameManager.awaiting_round_continue:
    GameManager.continue_to_next_question()
  else:
    GameManager._evaluate_selected_line()
  _update_ui_display()

func _on_emergency_flush_pressed() -> void:
  GameManager.spin_again()
  _update_ui_display()

func _get_category_color(category_value: int) -> Color:
  if category_value >= 0 and category_value < GameManager.category_colors.size():
    return GameManager.category_colors[category_value]
  return Color.WHITE
