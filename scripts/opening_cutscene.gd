extends Control

const GAMEPLAY_SCENE_PATH := "res://scenes/game_ui.tscn"

@export var slide_fade_out_duration: float = 0.18
@export var slide_fade_in_duration: float = 0.24
@export var ending_fade_duration: float = 0.45
@export var typewriter_characters_per_second: float = 58.0

var current_index: int = 0
var is_transitioning: bool = false
var is_text_typing: bool = false
var text_tween: Tween
var cutscene_images: Array[Texture2D] = [
  preload("res://assets/art/intro1.png"),
  preload("res://assets/art/intro2.png"),
  preload("res://assets/art/intro3.png"),
  preload("res://assets/art/intro4.png")
]
var cutscene_lines: Array[String] = [
  "i've failed at literally every normal job because i have zero marketable skills. but honestly, what does it take to run a country nowadays? screw it. i'm becoming a politician.",
  "leadership is really just about presentation. the public doesn't actually care about complex policy, and governing definitely isn't about splitting hairs.",
  "armed with pure, unearned confidence and my trusty ai wheel™, i can easily fake my way through any crisis. they won't suspect a thing.",
  "macroeconomics might not be my strong suit, but this giant jacket screams authority. time to step up to the podium."
]

@onready var intro_image: TextureRect = $MarginContainer/content/intro_image
@onready var story_label: Label = $MarginContainer/content/story_label
@onready var hint_label: Label = $MarginContainer/content/hint_label
@onready var content_root: VBoxContainer = $MarginContainer/content

func _ready() -> void:
  content_root.modulate.a = 0.0
  _apply_current_slide()
  _fade_content_to(1.0, slide_fade_in_duration)

func _input(event: InputEvent) -> void:
  if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
    _advance_cutscene()
    get_viewport().set_input_as_handled()
  elif event is InputEventKey and event.pressed and not event.echo:
    _advance_cutscene()
    get_viewport().set_input_as_handled()

func _advance_cutscene() -> void:
  if is_transitioning:
    return

  if is_text_typing:
    _complete_typewriter_text()
    return

  current_index += 1

  if current_index >= cutscene_images.size():
    _finish_cutscene()
    return

  _transition_to_current_slide()

func _transition_to_current_slide() -> void:
  is_transitioning = true
  await _fade_content_to(0.0, slide_fade_out_duration).finished
  _apply_current_slide()
  await _fade_content_to(1.0, slide_fade_in_duration).finished
  is_transitioning = false

func _finish_cutscene() -> void:
  is_transitioning = true
  await _fade_content_to(0.0, ending_fade_duration).finished
  get_tree().change_scene_to_file(GAMEPLAY_SCENE_PATH)

func _apply_current_slide() -> void:
  if cutscene_images.is_empty() or cutscene_lines.is_empty():
    get_tree().change_scene_to_file(GAMEPLAY_SCENE_PATH)
    return

  var safe_index: int = min(current_index, min(cutscene_images.size(), cutscene_lines.size()) - 1)
  intro_image.texture = cutscene_images[safe_index]
  _start_typewriter_text(cutscene_lines[safe_index])
  hint_label.text = "Click to continue (%d/%d)" % [safe_index + 1, cutscene_images.size()]

func _fade_content_to(alpha: float, duration: float) -> Tween:
  var tween: Tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
  tween.tween_property(content_root, "modulate:a", alpha, duration)
  return tween

func _start_typewriter_text(line_text: String) -> void:
  if is_instance_valid(text_tween):
    text_tween.kill()

  story_label.text = line_text
  var char_count: int = story_label.get_total_character_count()

  if char_count <= 0:
    story_label.visible_characters = -1
    is_text_typing = false
    return

  story_label.visible_characters = 0
  is_text_typing = true

  var duration: float = max(float(char_count) / max(typewriter_characters_per_second, 1.0), 0.01)
  text_tween = create_tween().set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
  text_tween.tween_property(story_label, "visible_characters", char_count, duration)
  text_tween.finished.connect(_on_typewriter_finished, CONNECT_ONE_SHOT)

func _complete_typewriter_text() -> void:
  if not is_text_typing:
    return

  if is_instance_valid(text_tween):
    text_tween.kill()

  story_label.visible_characters = -1
  is_text_typing = false

func _on_typewriter_finished() -> void:
  story_label.visible_characters = -1
  is_text_typing = false
