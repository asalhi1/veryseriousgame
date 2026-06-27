extends Control

@onready var menu_elements: VBoxContainer = $elements
@onready var credits_panel: PanelContainer = $credits_panel

const OPENING_CUTSCENE_SCENE = "res://scenes/opening_cutscene.tscn"

func _ready() -> void:
  credits_panel.hide()
  menu_elements.show()
  AudioManager.start_soundtrack()

func _on_start_pressed() -> void:
  get_tree().change_scene_to_file(OPENING_CUTSCENE_SCENE)

func _on_credits_pressed() -> void:
  menu_elements.hide()
  credits_panel.show()

func _on_close_credits_pressed() -> void:
  credits_panel.hide()
  menu_elements.show()
