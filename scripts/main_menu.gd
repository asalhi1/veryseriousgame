extends Control

@onready var menu_elements: VBoxContainer = $elements
@onready var options_panel: PanelContainer = $options_panel
@onready var credits_panel: PanelContainer = $credits_panel
@onready var volume_slider: HSlider = $options_panel/VBoxContainer/Volume

const MAIN_GAME_SCENE = "res://scenes/game_ui.tscn" 

func _ready() -> void:
  options_panel.hide()
  credits_panel.hide()
  menu_elements.show()
  
  var master_bus_idx = AudioServer.get_bus_index("Master")
  var volume_db = AudioServer.get_bus_volume_db(master_bus_idx)
  volume_slider.value = db_to_linear(volume_db)

func _on_start_pressed() -> void:
  get_tree().change_scene_to_file(MAIN_GAME_SCENE)

func _on_options_pressed() -> void:
  menu_elements.hide()
  options_panel.show()

func _on_credits_pressed() -> void:
  menu_elements.hide()
  credits_panel.show()

func _on_volume_value_changed(value: float) -> void:
  var master_bus_idx = AudioServer.get_bus_index("Master")
  AudioServer.set_bus_volume_db(master_bus_idx, linear_to_db(value))

func _on_close_options_pressed() -> void:
  options_panel.hide()
  menu_elements.show()

func _on_close_credits_pressed() -> void:
  credits_panel.hide()
  menu_elements.show()
