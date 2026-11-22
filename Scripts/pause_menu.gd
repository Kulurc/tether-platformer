class_name PauseMenu
extends CanvasLayer
## Esc (or Start) toggles. Pausing the SceneTree freezes everything that is pausable:
## bodies keep their exact position AND velocity because nothing integrates them, and
## tweens, timers, speech bubbles and crumbling blocks stop where they are.
## This node runs with PROCESS_MODE_ALWAYS so it can still react while paused.
##
## The layout is the scene Scenes/Prefabs/pause_menu.tscn: every element is a node there
## (Root is hidden in the editor - tick its eye to see and edit it). Volume rows are the
## HBoxContainers named after an audio bus (Master, Music, Sfx); each needs a HSlider and a
## Label named Percent. Volumes are saved to user://settings.cfg.

const SETTINGS_PATH := "user://settings.cfg"

## Where the Main Menu button goes (a scene name in Scenes/, or a res:// path).
@export var menu_scene := "MainMenu"
## Seconds to fade to black before the menu loads (the level's music fades out with it).
@export_range(0.1, 5.0, 0.1) var menu_fade := 1.0

@onready var _root: Control = $Root
@onready var _box: Container = $Root/Center/Panel/Box
@onready var _resume: Button = $Root/Center/Panel/Box/Resume
@onready var _menu: Button = $Root/Center/Panel/Box/MainMenu

var _sliders := {}  # bus name -> HSlider
var _leaving := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for row in _box.get_children():
		var slider := row.get_node_or_null("Slider") as HSlider
		if slider and AudioServer.get_bus_index(row.name) >= 0:
			_hook_slider(String(row.name), slider, row.get_node_or_null("Percent") as Label)
	_resume.pressed.connect(func(): set_paused(false))
	_menu.pressed.connect(go_to_menu)
	_load_settings()
	_root.visible = false


func _process(_dt: float) -> void:
	if not _leaving and Input.is_action_just_pressed("pause"):
		set_paused(not get_tree().paused)


func set_paused(p: bool) -> void:
	get_tree().paused = p
	_root.visible = p
	if p:
		_resume.grab_focus()
	else:
		_save_settings()


## Unpause and go back to the main menu (fade to black, the level's music fades out). The menu
## stays the first-visit one (leafy tree, its first music) unless the game was finished before.
func go_to_menu() -> void:
	if _leaving:
		return
	_leaving = true
	set_paused(false)
	var rig := get_tree().get_first_node_in_group(&"tether_rig")
	if rig and rig.has_method("go_to_scene"):
		rig.go_to_scene(menu_scene, menu_fade)
	else:
		get_tree().change_scene_to_file(LevelExit.resolve(menu_scene))


func _hook_slider(bus: String, slider: HSlider, pct: Label) -> void:
	slider.value_changed.connect(func(v: float):
		_apply(bus, v)
		if pct:
			pct.text = "%d%%" % roundi(v * 100.0))
	var idx := AudioServer.get_bus_index(bus)
	slider.value = db_to_linear(AudioServer.get_bus_volume_db(idx))
	if pct:
		pct.text = "%d%%" % roundi(slider.value * 100.0)
	_sliders[bus] = slider


func _apply(bus: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx < 0:
		push_warning("PauseMenu: audio bus '%s' not found." % bus)
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(idx, linear <= 0.001)


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	for bus in _sliders:
		(_sliders[bus] as HSlider).value = float(cfg.get_value("audio", bus, 1.0))


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	for bus in _sliders:
		cfg.set_value("audio", bus, (_sliders[bus] as HSlider).value)
	cfg.save(SETTINGS_PATH)
