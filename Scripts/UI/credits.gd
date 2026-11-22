extends Control
## Credits: black screen, the first line fades in and out, a pause on black, then the second
## line fades in and stays. A click / key / button / tap then returns to the main menu while the
## music keeps playing (the menu uses the same track, so it carries on without restarting).
## The texts are the nodes FirstLine and SecondLine: move, restyle or retype them in the editor.

@export_file("*.tscn") var menu_scene := "res://Scenes/MainMenu.tscn"
@export var music: AudioStream = preload("res://Audio/Music/vampires_piano.ogg")
@export_range(-40.0, 12.0, 0.5) var music_volume_db := 0.0
## Seconds the music takes to fade in when the credits begin.
@export_range(0.0, 10.0, 0.1) var music_fade_in := 2.0

@export_group("Timing (seconds)")
## A short beat of black before the first line appears.
@export_range(0.0, 10.0, 0.1) var start_delay := 1.0
@export_range(0.0, 10.0, 0.1) var first_fade_in := 2.0
## How long the first line stays fully visible (fade in + hold = 5 s on screen by default).
@export_range(0.0, 20.0, 0.1) var first_hold := 3.0
@export_range(0.0, 10.0, 0.1) var first_fade_out := 2.0
## Black screen between the two lines.
@export_range(0.0, 20.0, 0.1) var black_gap := 3.0
@export_range(0.0, 10.0, 0.1) var second_fade_in := 2.0
## Fade of the text when leaving for the menu.
@export_range(0.0, 5.0, 0.1) var leave_fade := 1.0

@onready var _first: CanvasItem = $FirstLine
@onready var _second: CanvasItem = $SecondLine

var _can_continue := false
var _leaving := false


func _ready() -> void:
	var cover := get_node_or_null("/root/ScreenFade")
	if cover and cover.is_holding():
		cover.release_after(2)
	var sm := get_node_or_null("/root/SoundManager")
	if sm and music:
		sm.prepare(music)  # web: decode now, on the black screen
		sm.play_music_fade(music, music_fade_in, music_volume_db)
	_first.modulate.a = 0.0
	_second.modulate.a = 0.0
	_run()


func _run() -> void:
	await get_tree().create_timer(start_delay).timeout
	var tw := create_tween()
	tw.tween_property(_first, "modulate:a", 1.0, maxf(first_fade_in, 0.01))
	tw.tween_interval(first_hold)
	tw.tween_property(_first, "modulate:a", 0.0, maxf(first_fade_out, 0.01))
	tw.tween_interval(black_gap)
	tw.tween_property(_second, "modulate:a", 1.0, maxf(second_fade_in, 0.01))
	await tw.finished
	_can_continue = true


func _unhandled_input(e: InputEvent) -> void:
	if not _can_continue or _leaving:
		return
	var go: bool = (e is InputEventMouseButton and e.pressed) \
		or (e is InputEventKey and e.pressed and not e.echo) \
		or (e is InputEventJoypadButton and e.pressed) \
		or (e is InputEventScreenTouch and e.pressed)
	if go:
		get_viewport().set_input_as_handled()
		back_to_menu()


## Fade the text out and load the menu. The music is left playing on purpose.
func back_to_menu() -> void:
	if _leaving:
		return
	_leaving = true
	var tw := create_tween()
	tw.tween_property(_second, "modulate:a", 0.0, maxf(leave_fade, 0.01))
	await tw.finished
	var cover := get_node_or_null("/root/ScreenFade")
	if cover:
		cover.hold()
	get_tree().change_scene_to_file(menu_scene)
