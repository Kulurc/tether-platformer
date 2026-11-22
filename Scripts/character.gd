class_name Character
extends CharacterBody2D
## One of the two tethered bodies. Either one can be driven by you or by PartnerAI;
## both go through the same set_intent() -> pre_step() path, so they always obey the
## same physics. Stats (size, jump, mass, grip) are what make them individuals.

enum Shape { RECT, CIRCLE }

@export var display_name := "Wisp"
@export var shape := Shape.RECT
@export var size := Vector2(20, 30)   ## RECT: width/height. CIRCLE: diameter = size.x
@export var color := Color(0.86, 0.92, 1.0)
@export var speaker := DialogueLine.Speaker.GIRL     ## which DialogueLine speaker this body voices
@export var bubble_tint := Color(0.84, 0.9, 1.0)     ## speech bubble colour

## Silhouette look (set by a LevelArt node, e.g. the meadow): a dark body, a rim of light in
## this character's own `color` on the sun side, and glowing eyes. Off = the normal look.
var silhouette := true:
	set(v):
		silhouette = v
		queue_redraw()
var silhouette_color := Color("15191c")
var eye_glow := Color(1.0, 0.97, 0.9)

@export_group("Run")
@export var run_speed := 240.0
@export var ground_accel := 2200.0
@export var ground_decel := 2800.0
@export var air_accel := 1400.0
@export var air_decel := 500.0
@export var air_momentum_decay := 260.0

@export_group("Jump")
@export var jump_height := 112.0
@export var time_to_apex := 0.36
@export var fall_gravity_mult := 1.6
@export var jump_cut_mult := 0.45
@export var max_fall_speed := 900.0
@export var coyote_time := 0.10
@export var jump_buffer := 0.12

@export_group("Tether")
@export var mass := 1.0
@export var grip := 2.4                ## W. Cord must pull this hard (sustained) to drag you while planted.
@export var swing_pump := 520.0
@export var swing_release_pop := 0.55

@export_group("Sprite (optional)")
## Leave empty to keep the placeholder shape. Otherwise create a SpriteFrames here and add
## animations with these names (any missing one falls back to "idle", then to the first):
## idle, run, jump, fall, swing, reel, dragged, stagger, left_behind
@export var sprite_frames: SpriteFrames
@export var sprite_offset := Vector2.ZERO        ## nudge the art relative to the collision shape
@export var sprite_scale := Vector2.ONE
@export var sprite_faces_right := true           ## which way the art faces when not flipped
## Below this horizontal speed counts as standing still (picks "idle" over "run").
@export var run_anim_threshold := 20.0
## Height of the art from its feet to the top of the head/hair (game px). The "you" marker,
## the "..." and speech bubbles sit above this instead of above the collision box. 0 = box.
@export var art_height := 0.0
## Where the sprite sits while swinging from a ring. The swing frames are drawn around the
## hands, so this puts the hands on the cord's end (0 = same as sprite_offset).
@export var swing_sprite_offset := Vector2.ZERO
## Optional extra animations, used when the SpriteFrames has them: "rise" (going up after
## the jump take-off), "land", "slack" (paying out cord), "hook" (throwing the hook).

@export_group("Reel feedback")
## px of trembling while this body is planted and reeling (scaled up with cord tension).
@export_range(0.0, 6.0, 0.1) var reel_shake_strength := 1.0
## How fast the tremble oscillates (Hz).
@export_range(1.0, 60.0, 0.5) var reel_shake_rate := 22.0
## Shape change while hauling: x widens / y squats. (1.08, 0.92) = braced, dug in.
@export var reel_squash := Vector2(1.08, 0.92)

@export_group("Sound")
## One is picked at random for each step (drop several variations in for a natural sound).
@export var footstep_sounds: Array[AudioStream] = []
@export_range(-40.0, 12.0, 0.5) var footstep_volume_db := -16.0
## Pixels walked per footstep (smaller = faster steps).
@export_range(10.0, 200.0, 1.0) var step_distance := 48.0
@export var jump_sound: AudioStream
@export_range(-40.0, 12.0, 0.5) var jump_volume_db := -10.0
@export var land_sound: AudioStream
@export_range(-40.0, 12.0, 0.5) var land_volume_db := -10.0
## Landings slower than this (px/s, falling) are silent - stops tiny hops from thudding.
@export_range(0.0, 900.0, 10.0) var land_min_speed := 260.0
## Extra volume (dB) when this body is the partner, not the one you control. Negative = quieter.
@export_range(-40.0, 0.0, 0.5) var partner_volume_offset_db := -5.0

var gravity := 0.0
var jump_velocity := 0.0
var _step_dist := 0.0
var tether: Tether
var partner: Character

# State the tether writes
var tether_taut := false
var rope_dir := Vector2.ZERO
var slipping := false

# Modifiers main.gd writes each frame
var controlled := false
var speed_mult := 1.0
var jump_mult := 1.0
var floaty := 0.0          ## 0..1 separation anxiety: lighter gravity, mushier acceleration
var marker_alpha := 0.0    ## "this is you" marker
var left_behind := false
var calling := false       ## shows "..." (waiting / calling to you)

# Intent (from Input or PartnerAI)
var in_move := 0.0
var in_jump_pressed := false
var in_jump_held := false
var just_jumped := false
var facing := 1.0

var _coyote := 0.0
var _buffer := 0.0
var _jumping := false
var _was_on_floor := false
var _pre_move_vy := 0.0
var _squash := Vector2.ONE
var _floor_grace := 0.0
var _stagger := 0.0
var _time := 0.0
var reel_effort := 0.0     ## 0..1, set by the tether while this body is reeling on the ground
var _effort := 0.0         ## smoothed reel_effort
var _sprite: AnimatedSprite2D
var _air_time := 0.0        # seconds since leaving the ground (jump -> rise)
var _land_time := 0.0       # "land" plays this long after touching down
var _hook_time := 0.0       # "hook" plays this long after hooking a ring
var _last_anchor: Object = null


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 6.0
	var cs := CollisionShape2D.new()
	if shape == Shape.CIRCLE:
		var c := CircleShape2D.new()
		c.radius = size.x * 0.5
		cs.shape = c
	else:
		var r := RectangleShape2D.new()
		r.size = size
		cs.shape = r
	add_child(cs)
	add_to_group("tether_bodies")
	if sprite_frames:
		_sprite = AnimatedSprite2D.new()
		_sprite.name = "Sprite"
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS  # art is drawn at 2x: smooth when shrunk
		_sprite.sprite_frames = sprite_frames
		add_child(_sprite)
	gravity = 2.0 * jump_height / (time_to_apex * time_to_apex)
	jump_velocity = -2.0 * jump_height / time_to_apex


func _sfx(s: AudioStream, db: float) -> void:
	if s == null:
		return
	var sm := get_node_or_null("/root/SoundManager")
	if sm:
		sm.play_sound(s, db + (0.0 if controlled else partner_volume_offset_db))


func half_w() -> float:
	return size.x * 0.5


func half_h() -> float:
	return size.x * 0.5 if shape == Shape.CIRCLE else size.y * 0.5


func feet_y() -> float:
	return global_position.y + half_h()


## Horizontal distance a running jump covers landing at the same height.
func jump_reach() -> float:
	var t_down := sqrt(2.0 * jump_height / (gravity * fall_gravity_mult))
	return run_speed * (time_to_apex + t_down)


func set_intent(move: float, jump_pressed: bool, jump_held: bool) -> void:
	in_move = move
	in_jump_pressed = jump_pressed
	in_jump_held = jump_held


func stagger(t: float) -> void:
	_stagger = maxf(_stagger, t)
	_squash = Vector2(1.25, 0.8)


func is_grounded() -> bool:
	return _floor_grace > 0.0


## Planted = feet on the ground and not trying to move. Planted bodies ignore the cord
## until its (smoothed) pull exceeds their grip. Same rule for you and for the AI.
func is_planted() -> bool:
	return is_grounded() and absf(in_move) < 0.1 and not slipping and _stagger <= 0.0


func pre_step(dt: float) -> void:
	_time += dt
	just_jumped = false
	var on_floor := is_on_floor()
	_floor_grace = 0.06 if on_floor else _floor_grace - dt
	var mv := in_move
	var jp := in_jump_pressed
	var jh := in_jump_held
	if _stagger > 0.0:
		_stagger -= dt
		mv = 0.0
		jp = false
	if mv != 0.0:
		facing = signf(mv)
	_coyote = coyote_time if on_floor else _coyote - dt
	_buffer = jump_buffer if jp else _buffer - dt

	var speed := run_speed * speed_mult
	var k := 1.0 - 0.45 * floaty
	var swinging := tether_taut and not on_floor

	if swinging:
		var t := Vector2(-rope_dir.y, rope_dir.x)
		if t.x < 0.0:
			t = -t
		velocity += t * mv * swing_pump * dt
	elif on_floor:
		var a := ground_accel if absf(mv) > 0.01 else ground_decel
		velocity.x = move_toward(velocity.x, mv * speed, a * k * dt)
	else:
		if absf(velocity.x) > speed and (mv == 0.0 or signf(mv) == signf(velocity.x)):
			velocity.x = move_toward(velocity.x, signf(velocity.x) * speed, air_momentum_decay * dt)
		else:
			var a := air_accel if absf(mv) > 0.01 else air_decel
			velocity.x = move_toward(velocity.x, mv * speed, a * k * dt)

	if _buffer > 0.0 and _coyote > 0.0:
		velocity.y = jump_velocity * jump_mult
		_buffer = 0.0
		_coyote = 0.0
		_jumping = true
		just_jumped = true
		_squash = Vector2(0.75, 1.3)
		_sfx(jump_sound, jump_volume_db)
	elif _buffer > 0.0 and swinging and tether and tether.anchor and tether.controller == self:
		tether.release_anchor()
		velocity.y = minf(velocity.y, jump_velocity * swing_release_pop)
		velocity.x *= 1.1
		_buffer = 0.0
		_squash = Vector2(0.8, 1.2)
	if _jumping and velocity.y < 0.0 and not jh:
		velocity.y *= jump_cut_mult
		_jumping = false
	if velocity.y >= 0.0:
		_jumping = false

	var g := gravity * (1.0 - 0.3 * floaty)
	if velocity.y > 0.0 and not tether_taut:
		g *= fall_gravity_mult
	velocity.y = minf(velocity.y + g * dt, max_fall_speed)
	_was_on_floor = on_floor
	_pre_move_vy = velocity.y


func post_step(dt: float) -> void:
	_air_time = 0.0 if is_on_floor() else _air_time + dt
	_land_time = maxf(0.0, _land_time - dt)
	_hook_time = maxf(0.0, _hook_time - dt)
	if tether:
		var a: Object = tether.anchor if tether.controller == self else null
		if a != null and a != _last_anchor:
			_hook_time = 0.5
		_last_anchor = a
	if is_on_floor() and not _was_on_floor and _pre_move_vy > 200.0:
		var k := clampf(_pre_move_vy / 900.0, 0.15, 0.4)
		_squash = Vector2(1.0 + k, 1.0 - k)
	if is_on_floor() and not _was_on_floor:
		if _pre_move_vy >= land_min_speed:
			_sfx(land_sound, land_volume_db)
		_step_dist = step_distance * 0.5  # first step comes a little after landing
		if _pre_move_vy > 200.0:
			_land_time = 0.25
	if is_on_floor() and absf(velocity.x) > 30.0 and not footstep_sounds.is_empty():
		_step_dist += absf(velocity.x) * dt
		if _step_dist >= step_distance:
			_step_dist = 0.0
			_sfx(footstep_sounds[randi() % footstep_sounds.size()], footstep_volume_db)
	_effort = move_toward(_effort, reel_effort, dt * 6.0)
	var rest := Vector2.ONE.lerp(reel_squash, _effort)  # dig in while hauling
	_squash = _squash.lerp(rest, 1.0 - exp(-14.0 * dt))
	if _sprite:
		_update_sprite()
	queue_redraw()


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	var col := color
	if left_behind:
		col = col.lerp(Color(0.42, 0.44, 0.5), 0.75)
	var rim := col
	if silhouette:
		col = silhouette_color.lerp(Color(0.3, 0.32, 0.36), 0.35 if left_behind else 0.0)
	var off := _shake_offset()
	if _sprite:
		_draw_overlays()  # the sprite is the body; only draw the "you" marker / "..." on top
		return

	var draw_shape := shape
	var draw_size := size
	_draw_body(draw_shape, draw_size, col, off)
	if silhouette:
		_draw_rim(draw_shape, draw_size, rim, off)

	# Eyes
	var dark := Color(0.12, 0.1, 0.12)
	var look := Vector2(facing, 0.0)
	if left_behind and partner:
		look = (partner.global_position - global_position).normalized()
	var eye_y := -half_h() * 0.35 * _squash.y
	if silhouette:
		var ex := [Vector2(-3.5, eye_y), Vector2(3.5, eye_y)] if draw_shape == Shape.CIRCLE 			else [Vector2(look.x * 3.0 - 2.5, eye_y), Vector2(look.x * 3.0 + 2.5, eye_y)]
		for e in ex:
			var ep: Vector2 = off + e + (look * 4.0 if draw_shape == Shape.CIRCLE else Vector2.ZERO)
			draw_circle(ep, 3.5, Color(eye_glow, 0.18))
			draw_circle(ep, 1.4, eye_glow)
		_draw_overlays()
		return
	if draw_shape == Shape.CIRCLE:
		draw_circle(off + Vector2(-4.5, eye_y) + look * 5.0, 2.5, dark)
		draw_circle(off + Vector2(4.5, eye_y) + look * 5.0, 2.5, dark)
	else:
		draw_rect(Rect2(off + Vector2(look.x * 4.0 - 2.0, eye_y - 2.0), Vector2(4, 4)), dark)

	_draw_overlays()


func _draw_overlays() -> void:
	if marker_alpha > 0.01:
		var top := Vector2(0, top_y() - 10.0)
		draw_colored_polygon(PackedVector2Array([top + Vector2(-5, -7), top + Vector2(5, -7), top]),
			Color(1, 1, 1, marker_alpha * 0.85))

	if calling or left_behind:
		for i in 3:
			var a := clampf(sin(_time * 4.0 - i * 0.8) * 0.5 + 0.5, 0.2, 1.0)
			draw_circle(Vector2(-8.0 + i * 8.0, top_y() - 24.0), 2.0, Color(1, 1, 1, a * 0.6))


func _shake_offset() -> Vector2:
	if slipping or _stagger > 0.0:
		return Vector2(randf_range(-1.5, 1.5), randf_range(-1.0, 1.0))
	if _effort > 0.01:
		# Hauling tremble: smooth (time-based) so it reads as strain, not glitching.
		var w := _time * reel_shake_rate * TAU
		return Vector2(sin(w), sin(w * 1.37 + 1.3) * 0.5) * reel_shake_strength * _effort
	return Vector2.ZERO


# ---------------------------------------------------------------- sprite mode

func _anim_name() -> String:
	if left_behind:
		return "left_behind"
	if _stagger > 0.0:
		return "stagger"
	if slipping:
		return "dragged"
	var mine := tether != null and tether.controller == self and tether.is_active()
	if _hook_time > 0.0 and _has_anim("hook"):
		return "hook"
	if is_grounded():
		if _effort > 0.05:
			return "reel"
		if absf(velocity.x) > run_anim_threshold:
			return "run"
		if _land_time > 0.0 and _has_anim("land"):
			return "land"
		if mine and tether.slacking and _has_anim("slack"):
			return "slack"
		return "idle"
	if tether_taut:
		return "swing"
	if velocity.y < 0.0:
		return "jump" if _air_time < 0.25 or not _has_anim("rise") else "rise"
	return "fall"


func _has_anim(a: String) -> bool:
	return _sprite != null and sprite_frames != null and sprite_frames.has_animation(a)


## Local y of the top of what you see (art if set, else the collision box).
func top_y() -> float:
	return minf(-half_h(), half_h() - art_height) if art_height > 0.0 else -half_h()


func _update_sprite() -> void:
	var frames := sprite_frames
	if _sprite.sprite_frames != frames:
		_sprite.sprite_frames = frames
	var want := _anim_name()
	if not frames.has_animation(want):
		want = "idle" if frames.has_animation("idle") else String(frames.get_animation_names()[0])
	if _sprite.animation != want:
		_sprite.play(want)
	elif not _sprite.is_playing() and frames.get_animation_loop(want):
		_sprite.play(want)  # one-shot animations (jump, land, hook...) hold their last frame
	_sprite.flip_h = (facing < 0.0) == sprite_faces_right
	_sprite.scale = sprite_scale * _squash
	# squash around the feet, plus the same tremble the placeholder uses
	var base := sprite_offset
	if want == "swing" and swing_sprite_offset != Vector2.ZERO:
		base = swing_sprite_offset
	_sprite.position = base + Vector2(0.0, half_h() * (1.0 - _squash.y)) + _shake_offset()
	var tint := Color.WHITE
	if left_behind:
		tint = tint.lerp(Color(0.5, 0.52, 0.58), 0.7)
	_sprite.modulate = tint


func _draw_body(s: Shape, sz: Vector2, col: Color, off: Vector2) -> void:
	if s == Shape.CIRCLE:
		var r := sz.x * 0.5
		var pulse := 1.0 + sin(_time * 2.2) * 0.04 * (0.0 if left_behind else 1.0)
		draw_set_transform(off + Vector2(0, r * (1.0 - _squash.y)), 0.0, _squash * pulse)
		if not silhouette:
			for i in 3:
				draw_circle(Vector2.ZERO, r * (1.7 - i * 0.22), Color(col, 0.05))
		draw_circle(Vector2.ZERO, r, col)
		draw_set_transform(Vector2.ZERO)
	else:
		var d := sz * _squash
		var top := sz.y * 0.5 - d.y  # squash around the feet
		draw_rect(Rect2(off + Vector2(-d.x * 0.5, top), d), col)


## Silhouette look: a thin line of light on the sun side (top-right) in the character's colour.
func _draw_rim(s: Shape, sz: Vector2, col: Color, off: Vector2) -> void:
	if s == Shape.CIRCLE:
		var r := sz.x * 0.5
		draw_set_transform(off + Vector2(0, r * (1.0 - _squash.y)), 0.0, _squash)
		draw_arc(Vector2.ZERO, r - 0.7, -PI * 0.5, PI * 0.1, 18, col, 1.8, true)
		draw_set_transform(Vector2.ZERO)
	else:
		var d := sz * _squash
		var top := sz.y * 0.5 - d.y
		var tl := off + Vector2(-d.x * 0.5, top)
		draw_line(tl + Vector2(1, 0.75), tl + Vector2(d.x - 0.5, 0.75), col, 1.5)
		draw_line(tl + Vector2(d.x - 0.75, 1), tl + Vector2(d.x - 0.75, d.y - 1), col, 1.5)

