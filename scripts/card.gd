extends Control

signal clicked(card_index: int)

@onready var visuals: Control = $visuals
@onready var word_label: Label = $visuals/word_label
@onready var category_label: HBoxContainer = $visuals/MarginContainer/category_label

var hand_index: int = -1
var original_y: float = 0.0
var original_rotation: float = 0.0

func _ready() -> void:
  original_y = visuals.position.y

  mouse_entered.connect(_on_mouse_entered)
  mouse_exited.connect(_on_mouse_exited)

  category_label.alignment = BoxContainer.ALIGNMENT_CENTER

func category_to_string(category: int) -> String:
  match category:
    0:
      return "POLICY"
    1:
      return "ABSURD"
    2:
      return "EMOTIONAL"
    3:
      return "ACTION"
    4:
      return "RHETORICAL"
    5:
      return "CLOSER"
    _:
      return "UNKNOWN"

func display_category(word: String) -> void:
  for child in category_label.get_children():
    child.queue_free()

  for letter in word:
    if letter == " ": continue 

    var letter_label = Label.new()
    letter_label.text = letter.to_upper()
    letter_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

    category_label.add_child(letter_label)

func setup_card_data(word_data: Resource, index: int) -> void:
  hand_index = index
  word_label.text = word_data.text
  display_category(category_to_string(word_data.category))
  for label in category_label.get_children():
    var color = GameManager.category_colors[word_data.category]
    label.add_theme_color_override("font_color", color.darkened(0.3))

  original_rotation = (index - 2) * 6.0
  
  visuals.position.y = original_y + abs(index - 2) * (50.0) - index * 5.0
  visuals.scale = Vector2.ONE
  visuals.rotation_degrees = original_rotation
  z_index = 0

func _gui_input(event: InputEvent) -> void:
  if event is InputEventMouseButton and event.pressed:
    if event.button_index == MOUSE_BUTTON_LEFT:
      emit_signal("clicked", hand_index)

func _on_mouse_entered() -> void:
  var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
  tween.tween_property(visuals, "position:y", original_y - 60.0, 0.15)
  tween.tween_property(visuals, "scale", Vector2(1.08, 1.08), 0.15)
  tween.tween_property(visuals, "rotation_degrees", 0.0, 0.15) 
  
  z_index = 5

func _on_mouse_exited() -> void:
  var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
  tween.tween_property(visuals, "position:y", original_y + abs(hand_index - 2) * 50.0, 0.15)
  tween.tween_property(visuals, "scale", Vector2.ONE, 0.15)
  tween.tween_property(visuals, "rotation_degrees", original_rotation, 0.15)
  
  z_index = 0
