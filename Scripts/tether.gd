class_name Tether
extends Node2D
## The cord between the two bodies (a = Wisp, b = Ember). This is the core mechanic.
##
## Physics
## - The cord runs along a path: a -> [anchor ring] -> b, and is a one-sided spring
##   (pulls when stretched past `length`, never pushes).
## - A ring is a frictionless pulley: the same tension acts on both ends.
## - PLANTED bodies (feet down, not trying to move - Character.is_planted) ignore the
##   pull until the *smoothed* tension exceeds their grip. If both are planted, the one
##   with less grip gives way. That's the whole "who holds" rule, and it's deterministic.
##
## Codependency layer (set per phase via apply_phase)
## - leash_cap: the cord's ceiling. Tightens toward the phase max, and in phase II
##   ratchets DOWN while you're apart ("tension memory"). It never loosens again.
## - tug: in phase III, pulling away past the leash staggers you and panics the partner.
##
## Forces are in W = weight_unit (one light-body weight), so thresholds read as
## "how many Wisps is the cord pulling".

signal snapped(reason: StringName)  ## &"sever" (chosen) or &"strain" (failure)
signal tugged(body: Character)

@export_group("Length")
@export var rest_length := 200.0
@export var min_length := 8.0
@export var reel_speed := 170.0
@export var slack_speed := 220.0
@export var relax_speed := 120.0
@export var reel_max_force := 3.2      ## W. Reeling stalls above this. Must beat the heavier grip (3.0).
@export var reel_brace := 1.5          ## W of extra grip for whoever is reeling (absorbs the jolt when they drop)

@export_group("Elasticity")
@export var stiffness := 220.0
@export var damping := 14.0
@export var hard_stretch := 40.0

@export_group("Strain")
## Off = the cord never breaks on its own, only when the player holds Sever (Q).
## On = it also snaps when pulled past `break_force` for `break_time`, or when it gets
## stretched/wedged far past its length.
@export var can_break := false
@export var weight_unit := 1600.0
@export var break_force := 4.2
@export var break_time := 0.35
@export var tension_smoothing := 12.0

@export_group("Verbs")
@export var anchor_range := 180.0
@export var sever_hold_time := 1.0

@export_group("Leash memory")
@export var tighten_speed := 90.0      ## px/s the cap closes toward a new phase's max
## (Shrink speed and all tug values are per phase: edit them in Data/Phases/*.tres)

@export_group("Look")
@export var rope_color := Color(1.0, 0.72, 0.3)
@export var strain_color := Color(1.0, 0.25, 0.2)
@export var segments := 28

@export_group("Reel / slack feedback")
@export var reel_rope_color := Color(1.0, 0.93, 0.72)    ## cord tint while reeling in (brighter, hotter)
@export var slack_rope_color := Color(0.74, 0.62, 0.48)  ## cord tint while paying out (duller, looser)
@export_range(0.0, 1.0, 0.05) var feedback_tint := 0.7   ## how strongly those tints apply
@export_range(0.0, 4.0, 0.1) var change_rope_shake := 0.6 ## px of cord shimmer while the length is changing
@export var flow_dots := true                             ## little marks that travel along the cord in the direction it moves
@export var flow_dot_spacing := 22.0
@export var reel_sound: AudioStream = preload("res://Audio/reel_loop.wav")
@export var slack_sound: AudioStream = preload("res://Audio/slack_loop.wav")
@export_range(-60.0, 6.0, 0.5) var reel_volume_db := -13.0
@export_range(-60.0, 6.0, 0.5) var slack_volume_db := -15.0
## Loops while the player holds Sever (Q): rises in pitch and volume until the cord snaps.
@export var sever_strain_sound: AudioStream = preload("res://Audio/Sfx/sever_strain_loop.wav")
@export_range(-60.0, 6.0, 0.5) var sever_strain_volume_db := -10.0
@export var sound_fade_time := 0.2                         ## fade in/out so loops never click on/off

var a: Character
var b: Character
var controller: Character
var length := 0.0
var anchor: TetherAnchor = null
var hover_anchor: TetherAnchor = null
var tension := 0.0
var tension_smooth := 0.0
var strain := 0.0
var severed := false
var broken := false
var taut := false
var reeling := false
var slacking := false
var sever_hold := 0.0
var path_len := 0.0

# Phase-driven
var phase_max := 440.0
var leash_cap := 440.0
var leash_floor := 440.0
var shrink_after := 0.0
var comfort := 170.0
var tug_enabled := false
var shrink_speed := 40.0
var tug_force := 1.3
var tug_impulse := 300.0
var tug_stagger := 0.22
var tug_cooldown := 0.9
var apart_time := 0.0

var _hook_slack := 0.0      # extra length allowed right after hooking beyond the phase limit; shrinks to 0
var _strain_timer := 0.0
var _wedged_timer := 0.0
var _fail_flash := 0.0
var _tug_cd := 0.0
var _a_braced := false
var _b_braced := false
var _rope := PackedVector2Array()
var _rope_prev := PackedVector2Array()
var _rope_alpha := 1.0
## Extra fade on the drawn cord, used by TetherRig.reveal_tether() in intros (1 = normal).
var reveal_alpha := 1.0:
	set(v):
		reveal_alpha = clampf(v, 0.0, 1.0)
		queue_redraw()
var _rope_free := false
var _free_seg := 8.0
var input_enabled := true   ## off during cutscenes / black screens (set by the TetherRig)
var sever_allowed := false  ## holding Sever only works in phases with `can_sever` on (set by apply_phase)
var _reel_moving := false   ## reeling AND the cord actually got shorter this frame
var _slack_moving := false
var _change := 0.0          ## smoothed: +1 reeling, -1 slacking, 0 idle
var _flow_phase := 0.0
var _fx_time := 0.0
var _reel_player: AudioStreamPlayer
var _slack_player: AudioStreamPlayer
var _strain_player: AudioStreamPlayer


func _ready() -> void:
	top_level = true  # the rope is drawn in world space, wherever the rig is placed


func setup(body_a: Character, body_b: Character, ctrl: Character) -> void:
	a = body_a
	b = body_b
	controller = ctrl
	a.tether = self
	b.tether = self
	_reel_player = _make_loop_player(reel_sound)
	_slack_player = _make_loop_player(slack_sound)
	_strain_player = _make_loop_player(sever_strain_sound)
	reset(false)


## Looping player made by the SoundManager (Sfx bus; WAVs without a loop point get looped).
func _make_loop_player(s: AudioStream) -> AudioStreamPlayer:
	var sm := get_node_or_null("/root/SoundManager")
	if sm == null or s == null:
		return null
	return sm.make_loop(s, self, -60.0)


## Reeler effort (character tremble), cord tint/flow, and the reel/slack loops.
func _update_feedback(dt: float) -> void:
	_fx_time += dt
	var active := is_active()
	var target := 0.0
	if active and _reel_moving:
		target = 1.0
	elif active and _slack_moving:
		target = -1.0
	_change = move_toward(_change, target, dt * 6.0)

	a.reel_effort = 0.0
	b.reel_effort = 0.0
	if active and reeling and controller.is_grounded() and length > min_length + 0.5:  # nothing left to haul = no strain
		var pull := clampf(tension_smooth / (reel_max_force * weight_unit), 0.0, 1.0)
		controller.reel_effort = 0.4 + 0.6 * pull  # harder pull, harder tremble

	var fade := 60.0 / maxf(sound_fade_time, 0.01) * dt  # dB per frame: -60 to full in sound_fade_time
	_drive_loop(_reel_player, active and _reel_moving, reel_volume_db, fade)
	_drive_loop(_slack_player, active and _slack_moving, slack_volume_db, fade)
	if _reel_player:
		_reel_player.pitch_scale = 0.95 + 0.15 * clampf(tension_smooth / (reel_max_force * weight_unit), 0.0, 1.0)


func _drive_loop(p: AudioStreamPlayer, on: bool, vol: float, fade: float) -> void:
	if p == null or p.stream == null:
		return
	p.volume_db = move_toward(p.volume_db, vol if on else -60.0, fade)
	if on and not p.playing:
		p.play()
	elif not on and p.playing and p.volume_db <= -59.0:
		p.stop()


func apply_phase(p: PhaseProfile) -> void:
	phase_max = p.max_length
	rest_length = p.rest_length
	leash_floor = minf(p.leash_floor, p.max_length)
	shrink_after = p.shrink_after
	shrink_speed = p.shrink_speed
	comfort = p.comfort
	tug_enabled = p.tug_enabled
	tug_force = p.tug_force
	tug_impulse = p.tug_impulse
	tug_stagger = p.tug_stagger
	tug_cooldown = p.tug_cooldown
	sever_allowed = p.can_sever
	apart_time = 0.0


func is_active() -> bool:
	return not severed and not broken


## Keeps leash_cap: the cord's memory survives respawns.
func reset(keep_severed: bool) -> void:
	broken = false
	if not keep_severed:
		severed = false
	anchor = null
	length = minf(rest_length, leash_cap)
	_hook_slack = 0.0
	tension = 0.0
	tension_smooth = 0.0
	strain = 0.0
	_strain_timer = 0.0
	_wedged_timer = 0.0
	sever_hold = 0.0
	apart_time = 0.0
	taut = false
	_rope_free = not is_active()
	_rope_alpha = 1.0 if is_active() else 0.0
	_init_rope()
	_update_anchor_states()


func other(c: Character) -> Character:
	return b if c == a else a


## Whoever is reeling digs their heels in: the reeler holds, the other one comes.
func grip_of(c: Character) -> float:
	return c.grip + (reel_brace if reeling and c == controller else 0.0)


# ---------------------------------------------------------------- simulation

func step(dt: float) -> void:
	_fail_flash = maxf(0.0, _fail_flash - dt)
	_tug_cd = maxf(0.0, _tug_cd - dt)
	hover_anchor = null
	if not is_active():
		taut = false
		tension = 0.0
		a.tether_taut = false
		b.tether_taut = false
		_reel_moving = false
		_slack_moving = false
		_update_feedback(dt)
		_update_anchor_states()
		return

	_update_leash(dt)
	_handle_verbs(dt)
	if not is_active():
		return

	var pts := get_path_points()
	var s := _path_length(pts)
	path_len = s
	var u_a := (pts[1] - pts[0]).normalized()
	var u_b := (pts[pts.size() - 2] - pts[pts.size() - 1]).normalized()
	var stretch := s - length
	taut = stretch > 0.0

	var force := 0.0
	if taut:
		var rate := -a.velocity.dot(u_a) - b.velocity.dot(u_b)
		force = maxf(0.0, stiffness * stretch + damping * rate)
	tension = force
	tension_smooth = lerpf(tension_smooth, tension, 1.0 - exp(-tension_smoothing * dt))

	var W := weight_unit
	a.slipping = _slip(a.slipping, a.is_grounded() and absf(a.in_move) < 0.1, tension_smooth, grip_of(a) * W)
	b.slipping = _slip(b.slipping, b.is_grounded() and absf(b.in_move) < 0.1, tension_smooth, grip_of(b) * W)
	# Both planted: nothing moves until the pull beats someone's grip; the lower grip goes first.
	_a_braced = a.is_planted()
	_b_braced = b.is_planted()

	u_a = _lip_redirect(a, u_a)
	u_b = _lip_redirect(b, u_b)
	if force > 0.0:
		if not _a_braced:
			a.velocity += u_a * (force / a.mass) * dt
		if not _b_braced:
			b.velocity += u_b * (force / b.mass) * dt

	a.tether_taut = taut and force > 0.0
	b.tether_taut = taut and force > 0.0
	a.rope_dir = u_a
	b.rope_dir = u_b
	_check_tug(u_a, u_b, stretch)
	_update_strain(dt)
	_update_feedback(dt)
	_update_anchor_states()


func post_step(dt: float) -> void:
	if is_active():
		var pts := get_path_points()
		var s := _path_length(pts)
		var over := s - length - hard_stretch
		if over > 0.0:
			var u_a := (pts[1] - pts[0]).normalized()
			var u_b := (pts[pts.size() - 2] - pts[pts.size() - 1]).normalized()
			var wa := 0.0 if _a_braced else 1.0 / a.mass
			var wb := 0.0 if _b_braced else 1.0 / b.mass
			if wa + wb == 0.0:
				wa = 1.0 / a.mass
				wb = 1.0 / b.mass
			var total := wa + wb
			a.move_and_collide(u_a * over * wa / total)
			b.move_and_collide(u_b * over * wb / total)
			var va := a.velocity.dot(u_a)
			if va < 0.0:
				a.velocity -= u_a * va
			var vb := b.velocity.dot(u_b)
			if vb < 0.0:
				b.velocity -= u_b * vb
			s = _path_length(get_path_points())
		if s - length > hard_stretch * 2.5:
			_wedged_timer += dt
			if can_break and _wedged_timer > 0.4:
				_snap(&"strain")
		else:
			_wedged_timer = 0.0
	_update_rope(dt)
	queue_redraw()


func _update_leash(dt: float) -> void:
	var d := _path_length(get_path_points())
	if d > comfort:
		apart_time += dt
	else:
		apart_time = maxf(0.0, apart_time - dt * 2.0)
	if shrink_after > 0.0 and apart_time > shrink_after:
		leash_cap = maxf(leash_floor, leash_cap - shrink_speed * dt)
	if leash_cap > phase_max:
		leash_cap = move_toward(leash_cap, phase_max, tighten_speed * dt)
	if anchor == null:
		_hook_slack = 0.0
	_hook_slack = move_toward(_hook_slack, 0.0, tighten_speed * dt)
	length = minf(length, leash_cap + _hook_slack)


func _check_tug(u_a: Vector2, u_b: Vector2, stretch: float) -> void:
	if not tug_enabled or not taut or _tug_cd > 0.0 or tension_smooth < tug_force * weight_unit:
		return
	var c := controller
	var u := u_a if c == a else u_b
	if absf(c.in_move) < 0.1 or signf(c.in_move) == signf(u.x):
		return  # not pulling away
	c.velocity += u * tug_impulse + Vector2(0.0, -80.0)
	c.stagger(tug_stagger)
	_tug_cd = tug_cooldown
	tugged.emit(c)


## Cheap stand-in for rope wrapping: a body hanging against a wall, with the cord leading
## up and over the lip, is pulled straight up the wall instead of into it.
func _lip_redirect(body: Character, u: Vector2) -> Vector2:
	if body.is_on_floor() or u.y > -0.05 or absf(u.x) < 0.01:
		return u
	var dir := signf(u.x)
	var q := PhysicsRayQueryParameters2D.create(
		body.global_position, body.global_position + Vector2(dir * (body.half_w() + 4.0), 0.0), 1, [body.get_rid()])
	if get_world_2d().direct_space_state.intersect_ray(q).is_empty():
		return u
	return Vector2(dir * 0.25, -1.0).normalized()


func _slip(slipping: bool, can_hold: bool, force: float, grip: float) -> bool:
	if not can_hold:
		return false
	if slipping:
		return force > grip * 0.6
	return force > grip


func _update_strain(dt: float) -> void:
	var W := weight_unit
	strain = clampf((tension_smooth / W - 1.0) / (break_force - 1.0), 0.0, 1.0)
	if tension_smooth > break_force * W:
		_strain_timer += dt
	else:
		_strain_timer = maxf(0.0, _strain_timer - dt * 2.0)
	if can_break and _strain_timer >= break_time:
		_snap(&"strain")


# ---------------------------------------------------------------- verbs

func _handle_verbs(dt: float) -> void:
	if anchor == null:
		hover_anchor = _find_anchor()

	if input_enabled and Input.is_action_just_pressed("hook"):
		if anchor:
			release_anchor()
		else:
			try_hook()

	reeling = input_enabled and Input.is_action_pressed("reel") and not Input.is_action_pressed("slack")
	slacking = input_enabled and Input.is_action_pressed("slack") and not reeling
	var len_before := length
	if reeling:
		var can_reel := length > min_length and tension_smooth < reel_max_force * weight_unit
		if anchor:
			can_reel = can_reel \
				and a.global_position.distance_to(anchor.global_position) > 28.0 \
				and b.global_position.distance_to(anchor.global_position) > 28.0
		if can_reel:
			var spd := reel_speed if taut else reel_speed * 2.0
			length = maxf(min_length, length - spd * dt)
	elif slacking:
		length = minf(maxf(length, leash_cap), length + slack_speed * dt)  # never shortens a fresh hook's extra length
	_reel_moving = reeling and length < len_before - 0.01
	_slack_moving = slacking and length > len_before + 0.01
	_flow_phase += length - len_before
	if reeling or slacking:
		pass  # the player is setting the length; no automatic take-up / relax this frame
	elif anchor and (not a.is_on_floor() or not b.is_on_floor()):
		# Hooked + someone airborne (whoever you control): take up slack so swings are smooth
		# arcs, not a drop-then-jolt. Swapping mid-swing keeps the swing.
		length = minf(length, _path_length(get_path_points()))
	elif anchor == null and length < minf(rest_length, leash_cap) and a.is_on_floor() and b.is_on_floor():
		# Both on solid ground: a reeled-in cord eases back to a comfortable length.
		length = minf(minf(rest_length, leash_cap), length + relax_speed * dt)

	if input_enabled and sever_allowed and Input.is_action_pressed("sever"):
		sever_hold += dt
		if sever_hold >= sever_hold_time:
			_snap(&"sever")
	else:
		sever_hold = maxf(0.0, sever_hold - dt * 3.0)
	_drive_strain(dt)


## The stretching sound while Sever is held: louder and higher the closer it is to snapping.
func _drive_strain(dt: float) -> void:
	if _strain_player == null or _strain_player.stream == null:
		return
	var k := clampf(sever_hold / sever_hold_time, 0.0, 1.0)
	var on := is_active() and sever_hold > 0.0
	_strain_player.pitch_scale = lerpf(0.85, 1.35, k)
	var target := lerpf(sever_strain_volume_db - 14.0, sever_strain_volume_db, k) if on else -60.0
	_strain_player.volume_db = move_toward(_strain_player.volume_db, target, dt * 240.0)
	if on and not _strain_player.playing:
		_strain_player.play()
	elif not on and _strain_player.playing and _strain_player.volume_db <= -59.0:
		_strain_player.stop()


func try_hook() -> bool:
	var ring := _find_anchor()
	if ring == null:
		_fail_flash = 0.3
		return false
	var s := a.global_position.distance_to(ring.global_position) \
		+ ring.global_position.distance_to(b.global_position)
	# Always catch, in every phase. If the cord over the ring is longer than the phase allows,
	# it's let out for now and tightens back to the limit gradually (no yank, no refusal).
	_hook_slack = maxf(0.0, s - leash_cap)
	anchor = ring
	length = s
	return true


func release_anchor() -> void:
	anchor = null
	_hook_slack = 0.0


func _find_anchor() -> TetherAnchor:
	var best: TetherAnchor = null
	var best_d := anchor_range
	for n in get_tree().get_nodes_in_group("anchors"):
		var ring := n as TetherAnchor
		var d := controller.global_position.distance_to(ring.global_position)
		if d < best_d:
			best_d = d
			best = ring
	return best


func _snap(reason: StringName) -> void:
	if reason == &"sever":
		severed = true
	else:
		broken = true
	anchor = null
	taut = false
	tension = 0.0
	tension_smooth = 0.0
	strain = 0.0
	sever_hold = 0.0
	a.tether_taut = false
	b.tether_taut = false
	a.slipping = false
	b.slipping = false
	_rope_free = true
	_free_seg = maxf(length, _path_length(get_path_points())) / float(segments - 1)
	_update_anchor_states()
	if _strain_player:  # the stretch cuts dead the instant it snaps
		_strain_player.stop()
		_strain_player.volume_db = -60.0
	snapped.emit(reason)


func _update_anchor_states() -> void:
	for n in get_tree().get_nodes_in_group("anchors"):
		var ring := n as TetherAnchor
		ring.state = 2 if ring == anchor else (1 if ring == hover_anchor else 0)


# ---------------------------------------------------------------- geometry

func get_path_points() -> PackedVector2Array:
	var pts := PackedVector2Array([a.global_position])
	if anchor:
		pts.append(anchor.global_position)
	pts.append(b.global_position)
	return pts


func _path_length(pts: PackedVector2Array) -> float:
	var s := 0.0
	for i in pts.size() - 1:
		s += pts[i].distance_to(pts[i + 1])
	return s


func _point_along(pts: PackedVector2Array, d: float) -> Vector2:
	for i in pts.size() - 1:
		var seg := pts[i].distance_to(pts[i + 1])
		if d <= seg or i == pts.size() - 2:
			return pts[i].lerp(pts[i + 1], clampf(d / maxf(seg, 0.001), 0.0, 1.0))
		d -= seg
	return pts[pts.size() - 1]


# ---------------------------------------------------------------- rope visual (verlet)

func _init_rope() -> void:
	if a == null:
		return
	_rope.resize(segments)
	_rope_prev.resize(segments)
	for i in segments:
		var p := a.global_position.lerp(b.global_position, float(i) / float(segments - 1))
		_rope[i] = p
		_rope_prev[i] = p


func _update_rope(dt: float) -> void:
	if _rope_free:
		_rope_alpha = maxf(0.0, _rope_alpha - dt / 1.5)
		if _rope_alpha <= 0.0:
			return
	var n := segments
	var pts := get_path_points()
	var s := _path_length(pts)
	var seg_len := _free_seg if _rope_free else maxf(length, s) / float(n - 1)
	var g := Vector2(0.0, 900.0) * dt * dt
	for i in n:
		var cur := _rope[i]
		var vel := (cur - _rope_prev[i]) * 0.985
		_rope_prev[i] = cur
		_rope[i] = cur + vel + g

	var anchor_idx := -1
	if not _rope_free and anchor and s > 0.0:
		anchor_idx = clampi(roundi(float(n - 1) * pts[0].distance_to(pts[1]) / s), 1, n - 2)

	for _it in 12:
		if not _rope_free:
			_rope[0] = pts[0]
			_rope[n - 1] = pts[pts.size() - 1]
			if anchor_idx >= 0:
				_rope[anchor_idx] = pts[1]
		for i in n - 1:
			var d := _rope[i + 1] - _rope[i]
			var dist := d.length()
			if dist < 0.0001:
				continue
			var corr := d * ((dist - seg_len) / dist)
			var pin_a := not _rope_free and (i == 0 or i == anchor_idx)
			var pin_b := not _rope_free and (i + 1 == n - 1 or i + 1 == anchor_idx)
			if pin_a and pin_b:
				continue
			elif pin_a:
				_rope[i + 1] -= corr
			elif pin_b:
				_rope[i] += corr
			else:
				_rope[i] += corr * 0.5
				_rope[i + 1] -= corr * 0.5
	if not _rope_free:
		var k := clampf((s - length) / 6.0, 0.0, 1.0)
		if k > 0.0:
			for i in range(1, n - 1):
				_rope[i] = _rope[i].lerp(_point_along(pts, s * float(i) / float(n - 1)), k)
		_rope[0] = pts[0]
		_rope[n - 1] = pts[pts.size() - 1]
		if anchor_idx >= 0:
			_rope[anchor_idx] = pts[1]


## Small marks riding the cord: toward you while reeling in, away while paying out.
func _draw_flow_dots(line: PackedVector2Array, col: Color, width: float) -> void:
	var pts := line
	if controller == b:  # measure from whoever is holding the cord
		pts = line.duplicate()
		pts.reverse()
	var dot_col := Color(col.lightened(0.55), col.a * absf(_change) * 0.9)
	var d := fposmod(_flow_phase, flow_dot_spacing) + flow_dot_spacing * 0.5
	var walked := 0.0
	for i in pts.size() - 1:
		var seg := pts[i].distance_to(pts[i + 1])
		while d <= walked + seg:
			var t := (d - walked) / maxf(seg, 0.001)
			draw_circle(pts[i].lerp(pts[i + 1], t), width * 0.45 + 0.6, dot_col)
			d += flow_dot_spacing
		walked += seg


func _draw() -> void:
	if _rope_alpha * reveal_alpha > 0.0 and _rope.size() > 1:
		# Memory: the shorter the cord has become, the hotter and heavier it looks.
		var memory := clampf(1.0 - (leash_cap - 120.0) / (440.0 - 120.0), 0.0, 1.0)
		var col := rope_color.lerp(strain_color, memory * 0.45)
		# Reel / slack tint, then strain (red) on top so danger always reads first.
		col = col.lerp(reel_rope_color, maxf(_change, 0.0) * feedback_tint)
		col = col.lerp(slack_rope_color, maxf(-_change, 0.0) * feedback_tint)
		col = col.lerp(strain_color, strain)
		if not is_active():
			col = col.darkened(0.35)
		col.a = _rope_alpha * reveal_alpha
		var width := lerpf(3.0, 1.5, strain) + memory * 1.5
		var line := _rope
		var shimmer := change_rope_shake * absf(_change)
		if strain > 0.5 or shimmer > 0.01:
			line = _rope.duplicate()
			var amp := maxf(strain - 0.5, 0.0) * 4.0
			for i in range(1, line.size() - 1):
				var dir := (_rope[i + 1] - _rope[i - 1]).normalized()
				var nrm := Vector2(-dir.y, dir.x)
				line[i] += nrm * sin(_fx_time * 38.0 + i * 1.7) * shimmer
				if amp > 0.0:
					line[i] += Vector2(randf_range(-amp, amp), randf_range(-amp, amp))
		draw_polyline(line, Color(col, col.a * (0.18 + memory * 0.15)), width + 6.0, true)
		draw_polyline(line, col, width, true)
		if flow_dots and absf(_change) > 0.01:
			_draw_flow_dots(line, col, width)

	if is_active() and sever_hold > 0.0:
		var t := clampf(sever_hold / sever_hold_time, 0.0, 1.0)
		draw_arc(controller.global_position, 28.0, -PI / 2.0, -PI / 2.0 + TAU * t, 40,
			Color(0.85, 0.9, 1.0, 0.9), 2.0, true)

	if _fail_flash > 0.0:
		draw_arc(controller.global_position + Vector2(0, -34), 5.0, 0.0, TAU, 16,
			Color(1, 0.35, 0.3, _fail_flash / 0.3), 2.0, true)
