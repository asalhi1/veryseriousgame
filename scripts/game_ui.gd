extends Control

@onready var meters_container: HBoxContainer = $meters_container
@onready var layout_container: VBoxContainer = $layout_container
@onready var question_lbl: Label = $layout_container/question_panel/question_vbox/question_text_label
@onready var tone_lbl: Label = $layout_container/question_panel/question_vbox/question_tone_label
@onready var preview_lbl: Label = $layout_container/speech_preview_label
@onready var submit_btn: Button = $layout_container/actions_container/submit_button
@onready var clear_btn: Button = $layout_container/actions_container/clear_button
@onready var continue_btn: Button = $feedback_panel/feedback_vbox/continue_button
@onready var trust_meter: ProgressBar = $meters_container/trust_container/trust_meter
@onready var vibe_meter: ProgressBar = $meters_container/vibe_container/vibe_meter
@onready var feedback_panel: PanelContainer = $feedback_panel
@onready var round_score_lbl: Label = $feedback_panel/feedback_vbox/round_score_label
@onready var speech_result_lbl: Label = $feedback_panel/feedback_vbox/speech_result_label
@onready var combo_lbl: Label = $feedback_panel/feedback_vbox/combo_label
@onready var tone_match_lbl: Label = $feedback_panel/feedback_vbox/tone_match_label
@onready var total_score_lbl: Label = $layout_container/hud_row/score_label
@onready var answered_lbl: Label = $layout_container/hud_row/answered_label

@onready var hand_buttons = [
  $layout_container/hand_container/card_0,
  $layout_container/hand_container/card_1,
  $layout_container/hand_container/card_2,
  $layout_container/hand_container/card_3,
  $layout_container/hand_container/card_4
]

func _ready():
  for i in range(hand_buttons.size()):
    hand_buttons[i].pressed.connect(_on_card_selected.bind(i))
    hand_buttons[i].gui_input.connect(_on_card_gui_input.bind(i))

  clear_btn.pressed.connect(_on_clear_pressed)
  submit_btn.pressed.connect(_on_submit_pressed)
  continue_btn.pressed.connect(_on_continue_pressed)

  GameManager._start_new_round()
  _update_ui_display()

func _update_ui_display():
  if GameManager.current_question:
    question_lbl.text = "reporter: \"" + GameManager.current_question.text + "\""
    tone_lbl.text = "target vibe required: " + GameManager.current_question.tone
  else:
    question_lbl.text = "click clear or enter to refresh prompts"
    tone_lbl.text = ""

  var words = []
  for word_resource in GameManager.selected_speech_line:
    words.append(word_resource.text)
  preview_lbl.text = "your speech: \"" + " ".join(words) + "\""

  total_score_lbl.text = "total score: " + str(int(round(GameManager.total_score)))
  answered_lbl.text = "questions answered: " + str(GameManager.answered_questions)

  feedback_panel.visible = GameManager.awaiting_round_continue
  meters_container.visible = not GameManager.awaiting_round_continue
  layout_container.visible = not GameManager.awaiting_round_continue
  
  if GameManager.awaiting_round_continue:
    round_score_lbl.text = "round score: " + str(int(round(GameManager.last_round_score)))
    speech_result_lbl.text = "your line: \"" + GameManager.last_round_speech_text + "\""
    tone_match_lbl.text = "tone matches: " + str(GameManager.last_round_tone_matches)
    
    if GameManager.last_round_combo_names.is_empty():
      combo_lbl.text = "combos: none"
    else:
      combo_lbl.text = "combos: " + ", ".join(GameManager.last_round_combo_names)
  else:
    round_score_lbl.text = "round score: 0"
    speech_result_lbl.text = "your line: \"\""
    tone_match_lbl.text = "tone matches: 0"
    combo_lbl.text = "combos: none"

  for i in range(hand_buttons.size()):
    if i < GameManager.current_hand.size():
      var card_data = GameManager.current_hand[i]
      hand_buttons[i].text = card_data.text

      var is_selected = GameManager.selected_speech_line.has(card_data)
      hand_buttons[i].visible = not is_selected
      hand_buttons[i].disabled = GameManager.awaiting_round_continue
    else:
      hand_buttons[i].visible = false

  var lock_inputs = GameManager.awaiting_round_continue
  submit_btn.disabled = lock_inputs
  clear_btn.disabled = lock_inputs

  trust_meter.value = GameManager.trust_vs_confusion
  vibe_meter.value = GameManager.hype_vs_meme

func _on_card_selected(index):
  GameManager._pick_word_from_hand(index)
  _update_ui_display()

func _on_card_gui_input(event: InputEvent, index: int):
  if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
    GameManager.spin_card_at_index(index)
    _update_ui_display()

func _on_clear_pressed():
  GameManager.selected_speech_line.clear()
  print("cleared current speech line selection")
  _update_ui_display()

func _on_submit_pressed():
  GameManager._evaluate_selected_line()
  _update_ui_display()

func _on_continue_pressed():
  GameManager.continue_to_next_question()
  _update_ui_display()
