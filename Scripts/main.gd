extends Node2D
## The TetherRig (Scenes/Prefabs/tether_rig.tscn): both characters, the cord, camera, HUD,
## overlay and pause menu in one drop-in. Drag it into any level scene - where you place it
## is where the pair spawns. Owns input, swapping, phases, and the simulation order:
##   1. intents: you -> controlled body; PartnerAI -> the other (or your input, during control bleed)
##   2. both bodies compute their own velocity
##   3. tether adds its pull (and reads hook/reel/slack/sever)
##   4. both bodies move; tether enforces limits and animates

## The relationship's phases, in order (entry 0 = phase I). Each is a .tres in Data/Phases/ -
## double-click one to tune it. PHASE zones refer to these by number (1 = first entry).
@export var phase_profiles: Array[PhaseProfile] = []

@export_group("Camera")
@export var camera_lerp := 6.0
@export var partner_camera_weight := 0.35
@export var look_ahead := 0.18

@export_group("Rules")
@export var checkpoint_partner_radius := 220.0
## Safety net for levels without a KILL zone: falling this far below the lowest checkpoint
## (or the spawn point) respawns you.
@export var fall_respawn_depth := 1500.0
## After severing, both bodies move/jump this much better ("a good platformer again").
@export var sever_speed_mult := 1.2
@export var sever_jump_mult := 1.2

@export_group("Messages")
## Shown when the player cuts the cord.
@export var sever_message := "It's over."
## When anyone falls to their death, one of these is picked at random (never the same twice
## in a row). Empty list = no message.
@export var fall_messages: Array[String] = [
	"It'll be different this time.",
	"We'll try again.",
	"Give us another chance.",
	"Don't give up on us.",
	"Don't let us go.",
]

@export_group("Sever")
## Plays the instant the cord is cut (e.g. a sharp "TACK"). Fixed pitch, never varied.
@export var sever_sound: AudioStream
@export_range(-40.0, 12.0, 0.5) var sever_volume_db := 0.0
## Run in order the moment the cord is cut - same step types as a DialogueTrigger.
## E.g. a DialogueMusic (ambience, empty stream, fade 0) to cut the ambience dead,
## a DialogueWait, then a DialogueMusic to bring something new in. Or a DialogueCall
## to any node/method. (The rig also emits the `severed` signal at the same moment.)
@export var on_sever: Array[DialogueStep] = []
## Camera shake (px) while Sever is held, building up to this just before the snap.
## It stops the moment the cord snaps. 0 = no shake.
@export_range(0.0, 20.0, 0.5) var sever_hold_shake := 4.0
## Seconds the player must hold Sever (Q) before the cord snaps. The stretch sound, the
## camera shake and the ring around the body all build up over this time.
@export_range(0.2, 10.0, 0.1, "or_greater") var time_to_sever := 2.5
## Cut the level music dead the moment the cord snaps (leaves silence after the TACK).
@export var stop_music_on_sever := false

@export_group("Audio")
## Music / ambience for this level. They wait until the level is actually visible: a level
## that starts on a black screen (intro dialogue) stays silent until the black has faded
## away, then the music fades in over level_audio_fade. They fade out when the level is
## left through go_to_scene (a LevelExit). Leave empty for none.
@export var level_music: AudioStream
@export var level_ambience: AudioStream
@export_range(0.0, 10.0, 0.1) var level_audio_fade := 2.0
@export_range(-40.0, 12.0, 0.5) var level_music_volume_db := 0.0
@export_range(-40.0, 12.0, 0.5) var level_ambience_volume_db := 0.0
## Tab: switching bodies.
@export var swap_sound: AudioStream
@export_range(-40.0, 12.0, 0.5) var swap_volume_db := -8.0
## Falling into a pit / off the level (plays as the screen fades).
@export var fall_sound: AudioStream
@export_range(-40.0, 12.0, 0.5) var fall_volume_db := -6.0
## Back at the checkpoint after a death or a restart.
@export var respawn_sound: AudioStream
@export_range(-40.0, 12.0, 0.5) var respawn_volume_db := -8.0
## A checkpoint is reached.
@export var checkpoint_sound: AudioStream
@export_range(-40.0, 12.0, 0.5) var checkpoint_volume_db := -8.0
## A new phase starts (plays with its title card).
@export var phase_sound: AudioStream
@export_range(-40.0, 12.0, 0.5) var phase_volume_db := -6.0

@export_group("Intro")
## Start this level on a black screen (speech bubbles still show). Reveal it with a
## DialogueFade step (FROM_BLACK) in an intro DialogueTrigger. Player input is ignored
## while the screen is black.
@export var start_black := false
## Settings for reveal_tether(): call it from a DialogueCall (target = TetherRig, method =
## reveal_tether, no args) after the last intro line. The cord appears alone on the black and
## holds. Follow it with a DialogueFade FROM_BLACK, then a DialogueCall tether_behind_characters.
@export var tether_reveal_sound: AudioStream            ## plays as the cord appears (empty = silent)
@export_range(-40.0, 12.0, 0.5) var tether_reveal_volume_db := -6.0
@export_range(0.0, 10.0, 0.05, "or_greater") var tether_reveal_time := 1.5    ## cord fade-in, seconds
@export_range(0.0, 10.0, 0.05, "or_greater") var tether_reveal_hold := 1.2    ## cord alone on black, seconds

@export_group("Fonts")
## Default font for every speech bubble (DialogueLine). Drag any .ttf/.otf (or a
## FontVariation .tres) from the FileSystem dock onto this slot. A DialogueLine's own
## `font` overrides it for that one line. [b] and [i] use a bolded / slanted version.
@export var dialogue_font: Font = preload("res://Fonts/Neucha/Neucha-Regular.ttf")
@export_range(6, 64, 1, "or_greater") var dialogue_font_size := 14
## Centered messages (show_message, fades, the ending text).
@export var message_font: Font = preload("res://Fonts/DM_Serif_Display/DMSerifDisplay-Regular.ttf")
@export_range(6, 96, 1, "or_greater") var message_font_size := 26
## Main title line of title cards (phase titles and show_title).
@export var title_font: Font = preload("res://Fonts/DM_Serif_Display/DMSerifDisplay-Regular.ttf")
@export_range(6, 128, 1, "or_greater") var title_font_size := 30
## Subtitle line under the title. DM Serif's hairlines get faint below ~18 px on a bright sky.
@export var subtitle_font: Font = preload("res://Fonts/DM_Serif_Display/DMSerifDisplay-Regular.ttf")
@export_range(6, 96, 1, "or_greater") var subtitle_font_size := 20

@export_group("Debug")
## Shift+F1 readout, F2 next phase, F3 next checkpoint, F4 slow-motion, F5 reset cord memory.
## Turn off for builds you hand to other people.
@export var debug_tools := true
@export_range(0.05, 1.0, 0.05) var slow_motion_scale := 0.25
## On-screen debug readout at the top (tension, grips, cord length...). Shift+F1 toggles it in game.
@export var show_debug_text := false
## Controls reminder along the bottom. Shift+F1 toggles it with the debug readout.
@export var show_controls := false
## "FPS: 60" counter at the top left. F1 toggles it in game.
@export var show_fps := true

## Emitted the moment the player cuts the cord (connect it in the Node dock if you like).
signal severed

@onready var wisp: Character = $Wisp
@onready var ember: Character = $Ember
@onready var tether: Tether = $Tether
@onready var camera: Camera2D = $Camera
@onready var hud: Hud = $HUD
@onready var blackout: Blackout = $Blackout
@onready var overlay_mat: ShaderMaterial = ($Anxiety/Filter as ColorRect).material as ShaderMaterial

var controlled: Character
var partner: Character
var ai := PartnerAI.new()
var phase := 0
var profile: PhaseProfile
var separation := 0.0

var _checkpoint := Vector2.ZERO
var _busy := false
var _leaving := false
var _ended := false
var _zones: Array[Zone] = []
var _swap_lock := 0.0
var _control_bleed := 0.0
var _shake := 0.0
var _anxiety := 0.0
var _pulse_time := 0.0
var _input_lock := 0.0
var _fall_limit_y := 0.0
var _last_fall_msg := -1
var _phase_loop: AudioStreamPlayer
var _music_pending := false  # level music waits for the level to be visible


func _ready() -> void:
	add_to_group(&"tether_rig")
	_ensure_input()
	wisp.partner = ember
	ember.partner = wisp
	controlled = wisp
	partner = ember
	wisp.controlled = true
	tether.setup(wisp, ember, controlled)
	tether.snapped.connect(_on_tether_snapped)
	tether.tugged.connect(_on_tugged)
	_checkpoint = controlled.global_position
	for n in get_tree().get_nodes_in_group("zones"):
		var z := n as Zone
		_zones.append(z)
		if z.kind == Zone.Kind.KILL:
			z.body_entered.connect(_on_kill_zone)
	_fall_limit_y = _checkpoint.y
	for z in _zones:
		if z.kind == Zone.Kind.CHECKPOINT:
			_fall_limit_y = maxf(_fall_limit_y, z.spawn_point().y)
	_fall_limit_y += fall_respawn_depth
	hud.set_overlays(show_debug_text, show_controls)
	hud.set_fps_visible(show_fps)
	hud.set_fonts(message_font, message_font_size, title_font, title_font_size,
		subtitle_font, subtitle_font_size)
	SpeechBubble.default_font = dialogue_font
	SpeechBubble.default_font_size = dialogue_font_size
	if start_black:
		blackout.set_black(true)
	elif Blackout.carry_in > 0.0:
		# Arrived through a LevelExit: start black and fade in (an intro with start_black
		# handles its own reveal instead).
		blackout.set_black(true)
		blackout.fade_to(0.0, Blackout.carry_in)
	Blackout.carry_in = 0.0
	var cover := get_node_or_null("/root/ScreenFade")
	if cover and cover.is_holding():
		cover.release_after(2)  # our own Blackout is black by now; hand over seamlessly
	set_phase(1)
	_update_camera(1.0, true)
	camera.make_current()
	tether.sever_hold_time = time_to_sever
	var psm := _sm()
	if psm:  # web: decode this level's music now, while the screen is still black
		psm.prepare(level_music)
		psm.prepare(level_ambience)
		for pr in phase_profiles:
			if pr:
				psm.prepare(pr.loop_sound)
	_music_pending = level_music != null or level_ambience != null
	_try_start_music()


func _physics_process(dt: float) -> void:
	if Input.is_action_just_pressed("restart"):
		if _ended:
			get_tree().reload_current_scene()
		elif not _busy:
			_die("")
		return
	if _ended:
		return
	if _music_pending:
		_try_start_music()
	if debug_tools:
		_debug_keys()
	var locked := _input_lock > 0.0 or blackout.is_covering()
	tether.input_enabled = not locked
	if Input.is_action_just_pressed("swap") and not _busy and not locked:
		swap()

	# --- intents
	var mv := Input.get_axis("move_left", "move_right")
	var jp := Input.is_action_just_pressed("jump")
	var jh := Input.is_action_pressed("jump")
	if locked:
		_input_lock = maxf(0.0, _input_lock - dt)
		controlled.set_intent(0.0, false, false)  # cutscene / black screen / scripted lock
	elif _swap_lock > 0.0:
		_swap_lock -= dt
		controlled.set_intent(0.0, false, false)  # the new body hesitates
	else:
		controlled.set_intent(mv, jp, jh)
	if _control_bleed > 0.0 and not tether.severed:
		_control_bleed -= dt
		partner.set_intent(mv, jp, jh)            # ...while the old one still answers you
	else:
		ai.think(partner, controlled, tether, dt)

	# --- modifiers
	_update_separation(dt)
	var free := tether.severed
	for c: Character in [wisp, ember]:
		c.speed_mult = sever_speed_mult if free else 1.0
		c.jump_mult = sever_jump_mult if free else 1.0
		c.floaty = separation * float(profile.floaty) if c == controlled and not free else 0.0
		c.left_behind = free and c != controlled
		var marker_target := 1.0 if c == controlled else 0.0
		if _swap_lock > 0.0:
			marker_target = 0.0  # hidden while the new body hesitates after a swap
		c.marker_alpha = move_toward(c.marker_alpha, marker_target, dt * 6.0)

	# --- simulate
	wisp.pre_step(dt)
	ember.pre_step(dt)
	tether.step(dt)
	wisp.move_and_slide()
	ember.move_and_slide()
	tether.post_step(dt)
	wisp.post_step(dt)
	ember.post_step(dt)
	if tether.is_active() and tether.sever_hold > 0.0 and sever_hold_shake > 0.0:
		var k := clampf(tether.sever_hold / tether.sever_hold_time, 0.0, 1.0)
		_shake = maxf(_shake, sever_hold_shake * pow(k, 1.3) + 0.5)

	_check_zones(dt)
	if controlled.global_position.y > _fall_limit_y:
		_fall()
	elif partner.global_position.y > _fall_limit_y and not tether.severed:
		_fall()
	_update_camera(dt)
	hud.update_debug(tether, controlled, phase, separation, debug_tools)


# ---------------------------------------------------------------- swap & phases

func swap() -> void:
	if tether.severed:
		return  # after the cut you're stuck with whoever you chose
	var old := controlled
	controlled = partner
	partner = old
	controlled.controlled = true
	partner.controlled = false
	tether.controller = controlled  # the hook stays: a swap mid-swing keeps the swing going
	ai.reset()
	_swap_lock = profile.swap_delay
	_control_bleed = profile.control_bleed
	_sfx(swap_sound, swap_volume_db)


func set_phase(p: int) -> void:
	if p <= phase:
		return  # phases only escalate
	if phase_profiles.is_empty():
		push_warning("No phase_profiles assigned on the root node; using defaults.")
		phase_profiles.append(PhaseProfile.new())
	p = mini(p, phase_profiles.size())
	if p <= phase:
		return
	phase = p
	profile = phase_profiles[p - 1]
	ai.configure(profile)
	tether.apply_phase(profile)
	var tw := create_tween()
	tw.tween_property(self, "_anxiety", profile.anxiety, 2.5)
	if profile.show_title:
		hud.show_title(profile.title, profile.subtitle, profile.title_font, profile.subtitle_font)
	if p > 1:
		_sfx(phase_sound, phase_volume_db)
	_start_phase_loop(profile)


## The phase's own looping sound (phase III's heartbeat). Fades in; the previous phase's
## loop fades out. Cut dead when the cord is severed.
func _start_phase_loop(pr: PhaseProfile) -> void:
	_stop_phase_loop(2.0)
	var sm := _sm()
	if sm == null or pr.loop_sound == null or tether.severed:
		return
	_phase_loop = sm.make_loop(pr.loop_sound, self, -60.0)
	_phase_loop.play()
	create_tween().tween_property(_phase_loop, "volume_db", pr.loop_volume_db, maxf(pr.loop_fade_in, 0.01))


func _stop_phase_loop(fade: float) -> void:
	if _phase_loop == null:
		return
	var p := _phase_loop
	_phase_loop = null
	if fade <= 0.0:
		p.queue_free()
		return
	var tw := create_tween()
	tw.tween_property(p, "volume_db", -60.0, fade)
	tw.tween_callback(p.queue_free)


# ---------------------------------------------------------------- helpers for DialogueCall
# Drag the TetherRig node onto a DialogueCall's Target and type one of these as the Method.
# Args go in order, e.g. show_message → ["Something's wrong.", 3.0]. Args with defaults can be left out.

## Centered text message: fades in, holds for `duration` seconds, fades out.
## When called from a DialogueCall, the next step waits until it has faded out.
## `font` (optional): a Font resource for this message only; leave it out for message_font.
func show_message(msg: String, duration: float = 2.5, font: Font = null) -> void:
	hud.show_message(msg, duration, font)
	await get_tree().create_timer(0.4 + duration + 0.8, false).timeout


## Big title card with an optional subtitle (same as the phase titles).
## When called from a DialogueCall, the next step waits until it has faded out.
## `title_font` / `subtitle_font` (optional): fonts for this card only; leave out for the defaults.
func show_title(title: String, subtitle: String = "", title_font: Font = null, subtitle_font: Font = null) -> void:
	hud.show_title(title, subtitle, title_font, subtitle_font)
	await get_tree().create_timer(0.8 + 2.5 + 1.2, false).timeout


## Darken the screen and show a final line of text. It stays up (use for custom endings).
## `font` (optional): a Font for this text only; leave it out for message_font.
func show_ending(msg: String, font: Font = null) -> void:
	hud.show_ending(msg, font)


## Intro beat: on the black screen, the cord fades in by itself (with tether_reveal_sound)
## and holds. It stays drawn in front of the black (and the characters) until you call
## tether_behind_characters(), so a typical intro ends:
##   DialogueCall reveal_tether  ->  DialogueFade FROM_BLACK  ->  DialogueCall tether_behind_characters
## Settings are in the Intro group; args override them for one call (-1 = use the Intro setting).
func reveal_tether(rope_time: float = -1.0, hold: float = -1.0) -> void:
	if rope_time < 0.0: rope_time = tether_reveal_time
	if hold < 0.0: hold = tether_reveal_hold
	tether_in_front()
	_sfx(tether_reveal_sound, tether_reveal_volume_db)
	if rope_time > 0.0:
		tether.reveal_alpha = 0.0
		var tw := create_tween()
		tw.tween_property(tether, "reveal_alpha", 1.0, rope_time).set_trans(Tween.TRANS_SINE)
		await tw.finished
	tether.reveal_alpha = 1.0
	if hold > 0.0:
		await get_tree().create_timer(hold, false).timeout


## Draw the cord in front of everything: the black screen and the characters
## (still under speech bubbles). reveal_tether() does this for you.
func tether_in_front() -> void:
	tether.z_as_relative = false
	tether.z_index = blackout.z_index + 1


## Put the cord back to its normal render order, behind the characters.
func tether_behind_characters() -> void:
	tether.z_as_relative = true
	tether.z_index = 0


## Fade to black, then load another scene. `scene` is a name like "prototype" (looked up in
## LevelExit.SCENES_FOLDER) or a full res:// path. The new scene fades in from black.
## Used by LevelExit; also callable from a DialogueCall (args: ["Level2"] or ["Level2", 2.0]).
func go_to_scene(scene: String, fade: float = 1.0) -> void:
	var path := LevelExit.resolve(scene)
	if path == "" or not ResourceLoader.exists(path):
		push_error("go_to_scene: can't find scene '%s' (looked for %s)." % [scene, path])
		return
	if _leaving:
		return
	_leaving = true
	_busy = true            # no deaths, restarts or swaps on the way out
	lock_input(1.0e6)
	_music_pending = false
	var sm := _sm()
	if sm:
		sm.stop_music(fade)
		sm.stop_ambience(fade)
	_stop_phase_loop(fade)
	Blackout.carry_in = maxf(fade, 0.05)
	await blackout.fade_to(1.0, fade)
	var cover := get_node_or_null("/root/ScreenFade")
	if cover:
		cover.hold()  # stays black through the empty frame between the two scenes
	get_tree().change_scene_to_file(path)


## Fade the screen in from black (awaitable from a DialogueCall).
func fade_from_black(duration: float = 1.5) -> void:
	await blackout.fade_to(0.0, duration)


## Fade the screen out to black (awaitable from a DialogueCall).
func fade_to_black(duration: float = 1.5) -> void:
	await blackout.fade_to(1.0, duration)


## Ignore player input for `seconds` (cutscenes). The partner AI keeps running.
func lock_input(seconds: float) -> void:
	_input_lock = maxf(_input_lock, seconds)


func shake_camera(amount: float = 6.0) -> void:
	_shake = maxf(_shake, amount)


## Cut the cord from a script (same as holding Q).
func sever_tether() -> void:
	if tether.is_active():
		tether._snap(&"sever")


## Jump straight to a phase (phases still never go backwards).
func go_to_phase(p: int) -> void:
	set_phase(p)


# ---------------------------------------------------------------- debug tools

func _debug_keys() -> void:
	if Input.is_action_just_pressed("debug_next_phase"):
		set_phase(phase + 1)
		hud.show_message("[debug] phase %d" % phase, 0.6)
	if Input.is_action_just_pressed("debug_next_checkpoint"):
		_debug_next_checkpoint()
	if Input.is_action_just_pressed("debug_slow_motion"):
		Engine.time_scale = 1.0 if Engine.time_scale < 1.0 else slow_motion_scale
		hud.show_message("[debug] time x%.2f" % Engine.time_scale, 0.6)
	if Input.is_action_just_pressed("debug_reset_memory"):
		tether.leash_cap = tether.phase_max
		hud.show_message("[debug] cord memory reset", 0.6)


func _debug_next_checkpoint() -> void:
	var cps: Array[Zone] = []
	for z in _zones:
		if z.kind == Zone.Kind.CHECKPOINT:
			cps.append(z)
	if cps.is_empty():
		return
	cps.sort_custom(func(x: Zone, y: Zone): return x.global_position.x < y.global_position.x)
	var target: Zone = cps[0]
	for z in cps:
		if z.spawn_point().x > controlled.global_position.x + 40.0:
			target = z
			break
	for z in cps:
		z.activated = z == target
	_checkpoint = target.spawn_point()
	_respawn()


func _exit_tree() -> void:
	Engine.time_scale = 1.0  # never leave slow-motion on after the scene ends


func _update_separation(dt: float) -> void:
	var target := 0.0
	var warm := 0.0
	if tether.severed:
		target = 1.0
	else:
		var d := controlled.global_position.distance_to(partner.global_position)
		target = clampf(inverse_lerp(tether.comfort, tether.leash_cap + 20.0, d), 0.0, 1.0)
		warm = (1.0 - target) * (1.0 if tether.taut else 0.6)
	separation = lerpf(separation, target, 1.0 - exp(-4.0 * dt))
	var strength := 1.0 if tether.severed else _anxiety
	overlay_mat.set_shader_parameter("separation", separation * strength)
	overlay_mat.set_shader_parameter("warmth", warm * strength * 0.8)
	_pulse_time += dt  # game time, not wall time: the warm pulse freezes with the pause
	overlay_mat.set_shader_parameter("pulse_time", _pulse_time)


# ---------------------------------------------------------------- zones & flow

func _check_zones(dt: float) -> void:
	for z in _zones:
		match z.kind:
			Zone.Kind.PHASE:
				if z.overlaps_body(controlled):
					set_phase(z.phase)
			Zone.Kind.CHECKPOINT:
				if not z.activated and z.overlaps_body(controlled) and (tether.severed \
						or partner.global_position.distance_to(z.spawn_point()) < checkpoint_partner_radius):
					for other in _zones:
						if other.kind == Zone.Kind.CHECKPOINT:
							other.activated = false
					z.activated = true
					_checkpoint = z.spawn_point()
					_sfx(checkpoint_sound, checkpoint_volume_db)
			Zone.Kind.STAY:
				if tether.is_active() and z.overlaps_body(wisp) and z.overlaps_body(ember):
					z.progress = minf(1.0, z.progress + dt / z.stay_time)
					if z.progress >= 1.0:
						_end("You stayed.\nThere was nowhere else to be.")
				else:
					z.progress = maxf(0.0, z.progress - dt)
			Zone.Kind.EXIT:
				if z.overlaps_body(controlled):
					if tether.severed:
						_end("You are free.\nIt is unbearable.")
					elif z.overlaps_body(partner):
						_end("You left together.")


func _on_kill_zone(body: Node2D) -> void:
	if body == controlled:
		_fall()
	elif body == partner and not tether.severed:
		_fall()


## Someone fell to their death: a random line from fall_messages, then respawn.
func _fall() -> void:
	if _busy or _ended:
		return
	var msg := ""
	if not fall_messages.is_empty():
		var i := randi() % fall_messages.size()
		if fall_messages.size() > 1 and i == _last_fall_msg:
			i = (i + 1 + randi() % (fall_messages.size() - 1)) % fall_messages.size()
		_last_fall_msg = i
		msg = fall_messages[i]
	_sfx(fall_sound, fall_volume_db)
	_die(msg)


func _on_tether_snapped(reason: StringName) -> void:
	if reason == &"strain":
		_die("The tether gave way.")
		return
	_stop_phase_loop(0.0)  # the phase loop stops dead with the snap
	if stop_music_on_sever:
		_music_pending = false
		var smm := _sm()
		if smm:
			smm.stop_music(0.0)
			smm.stop_ambience(0.0)
	_shake = 0.0           # the build-up shake ends with it
	var sm := _sm()
	if sm and sever_sound:
		sm.play_sound_exact(sever_sound, sever_volume_db)
	hud.show_message(sever_message, 1.5)
	severed.emit()
	_run_on_sever()


func _run_on_sever() -> void:
	for st in on_sever:
		if st:
			await st.run(self)


func _sm() -> Node:
	return get_node_or_null("/root/SoundManager")


## Start the level's music once nothing covers the screen any more (after an intro's black).
func _try_start_music() -> void:
	if blackout.alpha > 0.01 or _leaving:
		return
	_music_pending = false
	var sm := _sm()
	if sm == null:
		return
	if level_music:
		sm.play_music_fade(level_music, level_audio_fade, level_music_volume_db)
	if level_ambience:
		sm.play_ambience_fade(level_ambience, level_audio_fade, level_ambience_volume_db)


## One-shot sound effect through the SoundManager (nothing happens if `s` is empty).
func _sfx(s: AudioStream, db: float) -> void:
	var sm := _sm()
	if sm and s:
		sm.play_sound(s, db)


func _on_tugged(_body: Character) -> void:
	ai.panic(profile.panic_time)
	_shake = profile.tug_camera_shake


func _die(msg: String) -> void:
	if _busy or _ended:
		return
	_busy = true
	hud.fade(msg, func():
		_respawn()
		_sfx(respawn_sound, respawn_volume_db)
		_busy = false)


func _respawn() -> void:
	controlled.global_position = _checkpoint
	controlled.velocity = Vector2.ZERO
	if not tether.severed:
		partner.global_position = _checkpoint + Vector2(-50, -4)
		partner.velocity = Vector2.ZERO
	ai.reset()
	tether.reset(true)
	_update_camera(1.0, true)


func _end(msg: String) -> void:
	if _ended:
		return
	_ended = true
	hud.show_ending(msg + "\n\n\nBACKSPACE  -  begin again")


func _update_camera(dt: float, snap := false) -> void:
	var target := controlled.global_position
	if tether.is_active():
		target = target.lerp(partner.global_position, partner_camera_weight)
	target.x += clampf(controlled.velocity.x * look_ahead, -120.0, 120.0)
	target.y -= 40.0
	if snap:
		camera.global_position = target
	else:
		camera.global_position = camera.global_position.lerp(target, 1.0 - exp(-camera_lerp * dt))
	_shake = maxf(0.0, _shake - dt * 30.0)
	camera.offset = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake))


## Input is registered in code so the prototype runs out of the box. Actions you define in
## Project Settings > Input Map take precedence (existing actions are skipped).
func _ensure_input() -> void:
	_action("move_left", [KEY_A, KEY_LEFT], [], [JOY_BUTTON_DPAD_LEFT], [[JOY_AXIS_LEFT_X, -1.0]])
	_action("move_right", [KEY_D, KEY_RIGHT], [], [JOY_BUTTON_DPAD_RIGHT], [[JOY_AXIS_LEFT_X, 1.0]])
	_action("jump", [KEY_SPACE], [], [JOY_BUTTON_A])
	_action("swap", [KEY_TAB], [], [JOY_BUTTON_X])
	_action("hook", [KEY_E], [], [JOY_BUTTON_RIGHT_SHOULDER])
	_action("reel", [], [MOUSE_BUTTON_LEFT], [], [[JOY_AXIS_TRIGGER_RIGHT, 1.0]])
	_action("slack", [], [MOUSE_BUTTON_RIGHT], [], [[JOY_AXIS_TRIGGER_LEFT, 1.0]])
	_action("sever", [KEY_Q], [], [JOY_BUTTON_Y])
	_action("restart", [KEY_R], [], [JOY_BUTTON_BACK])
	_action("debug", [KEY_F1], [], [])
	_action("pause", [KEY_ESCAPE], [], [JOY_BUTTON_START])
	_action("debug_next_phase", [KEY_F2], [], [])
	_action("debug_next_checkpoint", [KEY_F3], [], [])
	_action("debug_slow_motion", [KEY_F4], [], [])
	_action("debug_reset_memory", [KEY_F5], [], [])


func _action(name: StringName, keys: Array, mouse: Array, buttons: Array, axes: Array = []) -> void:
	if InputMap.has_action(name):
		return
	InputMap.add_action(name, 0.25)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(name, e)
	for m in mouse:
		var e := InputEventMouseButton.new()
		e.button_index = m
		InputMap.action_add_event(name, e)
	for btn in buttons:
		var e := InputEventJoypadButton.new()
		e.button_index = btn
		InputMap.action_add_event(name, e)
	for ax in axes:
		var e := InputEventJoypadMotion.new()
		e.axis = ax[0]
		e.axis_value = ax[1]
		InputMap.action_add_event(name, e)
