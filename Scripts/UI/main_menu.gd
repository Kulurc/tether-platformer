extends Node2D
## Main menu. A click, key press or controller button starts the game.
## Everything you see is a node in this scene, so lay it out in the editor:
##   UI/Root/Title, UI/Root/Subtitle, UI/Root/ClickToStart  - the text (drag them, or set anchors/offsets)
##   LevelArt (sky, hills, light), Hill, Tree                 - the backdrop
## This script only handles starting the game and the fades.

## The scene the game starts in.
@export_file("*.tscn") var first_scene := "res://Scenes/Level1_Visual.tscn"
## Seconds to fade to black before the first level loads.
@export_range(0.1, 5.0, 0.1) var fade_out_time := 1.2
## Seconds the menu takes to fade in from black when it opens.
@export_range(0.0, 5.0, 0.1) var fade_in_time := 1.5
## "click to start" gently breathes in and out. Speed 0 = steady.
@export_range(0.0, 3.0, 0.05) var prompt_pulse_speed := 0.6
@export_range(0.0, 1.0, 0.05) var prompt_pulse_depth := 0.5
## The camera slowly drifts this far (px) and back, so the hills shift gently against each other.
## (0, 0) = still.
@export var camera_drift := Vector2(26, 6)
## Seconds for one full drift there and back.
@export_range(4.0, 120.0, 1.0) var camera_drift_period := 30.0

## Optional music for the menu (fades out when the game starts).
@export var menu_music: AudioStream
@export_range(-40.0, 12.0, 0.5) var menu_music_volume_db := -6.0
## Optional sound when the player starts.
@export var start_sound: AudioStream
@export_range(-40.0, 12.0, 0.5) var start_volume_db := -6.0

@onready var _prompt: CanvasItem = get_node_or_null("UI/Root/ClickToStart")
@onready var _fade: ColorRect = get_node_or_null("UI/Fade")
@onready var _cam: Camera2D = get_node_or_null("Camera")
@onready var _cam_home: Vector2 = _cam.position if _cam else Vector2.ZERO

var _starting := false
var _t := 0.0


func _ready() -> void:
	var cover := get_node_or_null("/root/ScreenFade")
	if cover and cover.is_holding():
		cover.release_after(2)
	if _fade:
		_fade.color.a = 1.0 if fade_in_time > 0.0 else 0.0
		create_tween().tween_property(_fade, "color:a", 0.0, maxf(fade_in_time, 0.01))
	var sm := get_node_or_null("/root/SoundManager")
	if sm and menu_music:
		sm.prepare(menu_music)  # web: decode now, under the fade-in from black
		sm.play_music_fade(menu_music, 1.5, menu_music_volume_db)


func _process(dt: float) -> void:
	_t += dt
	if _cam and camera_drift != Vector2.ZERO:
		var ph := _t * TAU / camera_drift_period
		_cam.position = _cam_home + Vector2(sin(ph) * camera_drift.x, sin(ph * 2.0 + 1.0) * camera_drift.y)
	if _prompt and prompt_pulse_speed > 0.0 and not _starting:
		_prompt.modulate.a = 1.0 - prompt_pulse_depth * (0.5 - 0.5 * cos(_t * prompt_pulse_speed * TAU))


func _unhandled_input(e: InputEvent) -> void:
	if _starting:
		return
	var go: bool = (e is InputEventMouseButton and e.pressed) \
		or (e is InputEventKey and e.pressed and not e.echo) \
		or (e is InputEventJoypadButton and e.pressed) \
		or (e is InputEventScreenTouch and e.pressed)
	if go:
		get_viewport().set_input_as_handled()
		start_game()


## Fade out and load first_scene (also callable from other scripts).
func start_game() -> void:
	if _starting:
		return
	_starting = true
	var sm := get_node_or_null("/root/SoundManager")
	if sm:
		if start_sound:
			sm.play_sound(start_sound, start_volume_db)
		if menu_music:
			sm.stop_music(fade_out_time)
	if _fade:
		var tw := create_tween()
		tw.tween_property(_fade, "color:a", 1.0, fade_out_time)
		await tw.finished
	Blackout.carry_in = 1.0  # the level fades in from black (levels with an intro handle their own)
	var cover := get_node_or_null("/root/ScreenFade")
	if cover:
		cover.hold()  # stays black through the empty frame between the two scenes
	get_tree().change_scene_to_file(first_scene)
