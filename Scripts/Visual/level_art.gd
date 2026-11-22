@tool
class_name LevelArt
extends Node2D
## Drop-in art direction for a level (Level1_Visual uses the midday-meadow settings).
## Purely visual: it never moves, resizes or adds collision to anything.
##
## What it adds:
##   - sky gradient with sun + soft rays, and see-through fog streaks for clouds
##   - three background layers (far hills, tree-lined hills, flower meadow) with gentle parallax
##   - dark earth below the level and shading down into the gaps between platforms
##   - slowly drifting dust, dark foreground grass passing in front, and a whole-screen finish
##   - silhouette characters (rim-lit in their own colour) and glowing hook rings
## Platforms only get the grassy look if their Block `look` is set to MEADOW.
## The sky/backdrop/dust only appear when the game runs; the ground shading shows in the editor too.

class Painter extends Node2D:
	var fn: Callable
	func _draw() -> void:
		fn.call(self)

@export_group("Sky")
@export var sky_top := Color("2a6fcc")
@export var sky_mid := Color("6fb0ec")
@export var sky_horizon := Color("dbeef7")
@export var sun_color := Color("fff2cc")
## Sun position on screen (0..1). It stays put as you move, like a real sun.
@export var sun_position := Vector2(0.8, 0.1)
@export_range(0.0, 2.0, 0.05) var sun_power := 0.85
@export_range(0.0, 1.0, 0.01) var sun_rays := 0.10
## 0 = clear sky. Higher = a grey cloud deck covering the sky (the forest uses ~0.85).
@export_range(0.0, 1.0, 0.01) var overcast := 0.0
@export var cloud_deck_light := Color("c3c8c9")
@export var cloud_deck_dark := Color("6c747a")
## How fast the cloud deck drifts on its own.
@export_range(0.0, 2.0, 0.01) var cloud_wind := 0.15

@export_group("Clouds (fog streaks)")
@export_range(0, 30) var cloud_count := 6
@export_range(0.0, 0.3, 0.005) var cloud_opacity := 0.05
@export_range(0.0, 0.3, 0.005) var cloud_parallax := 0.02
@export var cloud_color := Color(1, 1, 1)

enum Backdrop { MEADOW_HILLS, FOREST_EDGE, DEEP_FOREST }

@export_group("Background hills")
## MEADOW_HILLS: open hills with a few trees (Level1). FOREST_EDGE: tree lines in clumps with
## open plains between them (Level2).
@export var backdrop := Backdrop.MEADOW_HILLS
@export var haze := Color("d3e6f0")
@export var far_hills := Color("93b6cf")
@export var mid_hills := Color("6f9f8a")
@export var meadow := Color("4e8559")
## Where the horizon sits on screen (0 = top, 1 = bottom) at the level's reference height.
@export_range(0.0, 1.0, 0.01) var horizon_height := 0.56
## How much the horizon drops as you climb (0 = never moves).
@export_range(0.0, 0.5, 0.01) var vertical_parallax := 0.10
## World height the horizon is measured from (roughly the level's middle height).
@export var reference_y := -300.0
## How fast each layer moves with the camera (0 = fixed to the screen, 1 = moves with the level).
@export_range(0.0, 1.0, 0.01) var far_parallax := 0.06
@export_range(0.0, 1.0, 0.01) var mid_parallax := 0.18
@export_range(0.0, 1.0, 0.01) var meadow_parallax := 0.35
@export_range(0, 120) var background_trees := 40
## FOREST_EDGE only: how much of the background is woodland vs open plain (0..1).
@export_range(0.0, 1.0, 0.01) var woodland := 0.55

@export_group("Deep forest (backdrop = DEEP_FOREST)")
## Rows of tall trunks behind the level, from far (pale, lost in the fog) to near (dark).
@export_range(1, 6) var trunk_rows := 4
## How crowded each row is (trunks per 1000 px).
@export_range(0.5, 12.0, 0.1) var trunk_density := 4.0
@export var trunk_far := Color("a3a7a3")
@export var trunk_near := Color("262a28")
## How thick the fog is between the rows of trunks.
@export_range(0.0, 1.0, 0.01) var fog := 0.6
## Fog lying low on the forest floor (behind the level).
@export_range(0.0, 1.0, 0.01) var ground_fog := 0.5
## Fog drifting in FRONT of the level, along the bottom of the screen. 0 = off.
@export_range(0.0, 1.0, 0.01) var front_fog := 0.0
## The leaf canopy shading the top of the screen.
@export_range(0.0, 1.0, 0.01) var canopy := 0.75
@export var canopy_color := Color("121513")
## Dim shafts of light falling through gaps in the leaves.
@export_range(0, 12) var light_shafts := 5
@export var shaft_color := Color("e8e4d4")
@export_range(0.0, 0.5, 0.005) var shaft_opacity := 0.1

@export_group("Meadow flowers (background)")
@export_range(0, 2000) var flower_count := 260
@export_range(0.0, 1.0, 0.01) var flower_opacity := 0.10
@export var flower_colors: Array[Color] = [Color("ffe066"), Color("ffffff"), Color("ff9fb5"), Color("a8c8ff"), Color("ffb347")]

@export_group("Ground (Blocks with look = MEADOW)")
@export var ground_top := Color("3c6a3c"):
	set(v):
		ground_top = v
		_apply_ground()
@export var ground := Color("1d3a29"):
	set(v):
		ground = v
		_apply_ground()
@export var ground_deep := Color("0d1813"):
	set(v):
		ground_deep = v
		_apply_ground()
## Little flowers in the grass along platform tops.
@export var grass_flowers := true:
	set(v):
		grass_flowers = v
		_apply_ground()
## Darken the gaps between platforms toward the bottom, and fill dark earth below the level.
@export var shade_chasms := true:
	set(v):
		shade_chasms = v
		queue_redraw()

@export_group("Dust")
@export_range(0, 300) var dust_count := 34
## Fastest drift in px per second (it also wobbles gently). Real dust is slow.
@export_range(0.0, 40.0, 0.5) var dust_speed := 5.0
@export var dust_color := Color(1.0, 1.0, 0.9)

@export_group("Foreground grass")
@export var foreground_grass := true
## > 1 = passes in front faster than the level (sense of depth).
@export_range(1.0, 2.5, 0.05) var foreground_parallax := 1.3
## Dark tree trunks passing in front of the level (0 = none), per ~2 screen widths.
@export_range(0, 6) var foreground_trees := 0
@export_range(0.0, 1.0, 0.01) var foreground_tree_opacity := 0.92
## Foreground trees fade to this opacity while a character is behind them, so you never lose
## sight of the pair (1 = never fade).
@export_range(0.0, 1.0, 0.01) var foreground_tree_see_through := 0.3
## The foreground stays locked to the camera (jumps, drops to lower ground: no change). Only
## when you fall this many px below where you last stood (a real fall into a pit) does it start
## to fade away, so it doesn't fall all the way down with you. It fades back once you land.
@export_range(0.0, 1500.0, 10.0) var foreground_fade_after_fall := 260.0
## Over how many more px of falling it fades out completely.
@export_range(10.0, 1500.0, 10.0) var foreground_fade_distance := 300.0

@export_group("Ambient motion (0 = still)")
## Clouds drift sideways at this speed (px/s).
@export_range(0.0, 60.0, 0.5) var cloud_drift := 0.0
## Foreground grass sways by up to this many px at the tips.
@export_range(0.0, 30.0, 0.5) var grass_sway := 0.0
## The sun glow slowly brightens and dims by this fraction.
@export_range(0.0, 0.5, 0.01) var sun_breathe := 0.0
## The light rays slowly shift and shimmer at this speed.
@export_range(0.0, 1.0, 0.01) var ray_drift := 0.0

@export_group("Characters & rings")
## Dark bodies with a rim of light in each character's own colour, glowing eyes.
@export var silhouette_characters := true
@export var silhouette_color := Color("15191c")
@export var eye_glow := Color(1.0, 0.97, 0.9)
@export var ring_color := Color("ffd000")
@export var ring_glow := true

@export_group("Screen finish")
@export var screen_grade := true
@export_range(0.0, 1.0, 0.01) var vignette := 0.28
@export_range(0.0, 0.2, 0.005) var grain := 0.03
@export_range(0.0, 0.01, 0.0005) var color_fringe := 0.0015
@export var shadow_lift := Color(0.0, 0.01, 0.03)
## Drains colour from the whole screen (0 = full colour, 1 = black and white). Strong colours
## like the yellow rings and rocket bands keep a little of theirs.
@export_range(0.0, 1.0, 0.01) var desaturate := 0.0
## Colour the greyed-out picture leans toward (white = neutral grey).
@export var desaturate_tint := Color(1, 1, 1)

var _t := 0.0
var _cam := Vector2.ZERO
var _zoom := 1.0
var _vs := Vector2(1280, 720)
var _backdrop: Painter
var _dust: Painter
var _fg: Painter
var _sky_mat: ShaderMaterial
var _dt := 0.0
var _fg_ground_y := INF   # camera y the last time the controlled body stood on the ground
var _fg_alpha := 1.0
var _fg_fade := PackedFloat32Array()  # per foreground tree, 1 = solid, see-through when someone is behind


func _ready() -> void:
	z_as_relative = false
	z_index = -2  # earth + chasm shading sits behind the platforms
	_apply_ground()
	if Engine.is_editor_hint():
		return
	_build()
	_apply_bodies.call_deferred()  # characters/rings register themselves in their own _ready


func _process(dt: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()  # follow block edits in the editor
		return
	_t += dt
	_vs = get_viewport_rect().size
	var cam := get_viewport().get_camera_2d()
	if cam:
		_cam = cam.get_screen_center_position()
		_zoom = cam.zoom.x
	if _sky_mat and ray_drift > 0.0:
		_sky_mat.set_shader_parameter("ray_time", _t * ray_drift)
	if _sky_mat and sun_breathe > 0.0:
		_sky_mat.set_shader_parameter("sun_power", sun_power * (1.0 + sun_breathe * sin(_t * TAU / 7.0)))
	if _sky_mat and overcast > 0.0:
		_sky_mat.set_shader_parameter("cloud_offset", Vector2(_cam.x * 0.00012 + _t * cloud_wind * 0.01, 0.0))
	_backdrop.queue_redraw()
	if not _bands.is_empty():
		_update_bands()
	_dust.queue_redraw()
	_dt = dt
	if _fg:
		_fg.global_position = _cam
		_fg.modulate.a = _fg_fall_alpha(dt)
		_fg.queue_redraw()


## 1 while you're near the ground you last stood on; fades to 0 as you fall deeper than
## foreground_fade_after_fall (into a pit), and back to 1 once you're standing again.
func _fg_fall_alpha(dt: float) -> float:
	var grounded := false
	for b in get_tree().get_nodes_in_group(&"tether_bodies"):
		if b is Character and (b as Character).controlled and (b as Character).is_on_floor():
			grounded = true
	if grounded or _fg_ground_y == INF or _cam.y < _fg_ground_y:
		_fg_ground_y = _cam.y
	var fell := _cam.y - _fg_ground_y - foreground_fade_after_fall
	var target := 1.0 - clampf(fell / foreground_fade_distance, 0.0, 1.0)
	if target < _fg_alpha:
		_fg_alpha = target                              # follow the fall exactly
	else:
		_fg_alpha = move_toward(_fg_alpha, target, dt * 1.5)  # gentle fade back in after landing / respawn
	return _fg_alpha


# ---------------------------------------------------------------- setup

func _apply_ground() -> void:
	Block.meadow_top = ground_top
	Block.meadow_body = ground
	Block.meadow_deep = ground_deep
	var fl: Array[Color] = []
	if grass_flowers:
		fl = flower_colors.duplicate()
	Block.meadow_flowers = fl
	if is_inside_tree():
		Block.redraw_all(get_tree())
	queue_redraw()


func _apply_bodies() -> void:
	if silhouette_characters:
		for b in get_tree().get_nodes_in_group(&"tether_bodies"):
			if b is Character:
				var c := b as Character
				c.silhouette_color = silhouette_color
				c.eye_glow = eye_glow
				c.silhouette = true
	for a in get_tree().get_nodes_in_group(&"anchors"):
		if a is TetherAnchor:
			(a as TetherAnchor).color = ring_color
			(a as TetherAnchor).glow = ring_glow


func _painter(parent: Node, fn: Callable) -> Painter:
	var p := Painter.new()
	p.fn = fn
	FastDraw.use_on(p)  # circles are FastDraw discs: batched instead of one draw call each
	parent.add_child(p)
	return p


func _full_rect(parent: Node, shader: Shader) -> ShaderMaterial:
	var r := ColorRect.new()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	var m := ShaderMaterial.new()
	m.shader = shader
	r.material = m
	parent.add_child(r)
	return m


func _build() -> void:
	var sky_layer := CanvasLayer.new()
	sky_layer.layer = -10
	add_child(sky_layer)
	var sm := _full_rect(sky_layer, preload("res://Shaders/sky.gdshader"))
	sm.set_shader_parameter("top_col", sky_top)
	sm.set_shader_parameter("mid_col", sky_mid)
	sm.set_shader_parameter("horizon_col", sky_horizon)
	sm.set_shader_parameter("sun_col", sun_color)
	sm.set_shader_parameter("sun", sun_position)
	sm.set_shader_parameter("sun_power", sun_power)
	sm.set_shader_parameter("rays", sun_rays)
	sm.set_shader_parameter("overcast", overcast)
	sm.set_shader_parameter("cloud_light", cloud_deck_light)
	sm.set_shader_parameter("cloud_dark", cloud_deck_dark)
	_sky_mat = sm

	var bg_layer := CanvasLayer.new()
	bg_layer.layer = -9
	add_child(bg_layer)
	_backdrop = _painter(bg_layer, _paint_backdrop)  # clouds (+ the deep forest)
	if backdrop == Backdrop.DEEP_FOREST:
		_build_deep(bg_layer)
	else:
		_build_bands(bg_layer)

	_dust = _painter(self, _paint_dust)
	_dust.top_level = true
	_dust.z_as_relative = false
	_dust.z_index = 20      # in front of the level, under the black screen (40) and speech (50)

	if foreground_grass:
		_fg = _painter(self, _paint_foreground)
		_fg.top_level = true
		_fg.z_as_relative = false
		_fg.z_index = 30

	if screen_grade:
		var post_layer := CanvasLayer.new()
		post_layer.layer = 4  # under the anxiety filter (5) and the HUD (10)
		add_child(post_layer)
		var pm := _full_rect(post_layer, preload("res://Shaders/screen_grade.gdshader"))
		pm.set_shader_parameter("vignette", vignette)
		pm.set_shader_parameter("grain", grain)
		pm.set_shader_parameter("ca", color_fringe)
		pm.set_shader_parameter("lift", shadow_lift)
		pm.set_shader_parameter("desat", desaturate)
		pm.set_shader_parameter("tint", desaturate_tint)


# ---------------------------------------------------------------- world: earth + chasms

func _draw() -> void:
	if not shade_chasms or not is_inside_tree():
		return
	var rects: Array[Rect2] = []
	for b in get_tree().get_nodes_in_group(&"blocks"):
		if b is Block and (b as Block).look == Block.Look.MEADOW:
			rects.append(Rect2((b as Block).global_position - global_position, (b as Block).size))
	if rects.is_empty():
		return
	rects.sort_custom(func(a: Rect2, b: Rect2) -> bool: return a.position.x < b.position.x)
	var deep := -INF
	var left := INF
	var right := -INF
	for r in rects:
		deep = maxf(deep, r.end.y)
		left = minf(left, r.position.x)
		right = maxf(right, r.end.x)
	draw_rect(Rect2(left - 4000.0, deep - 2.0, right - left + 8000.0, 6000.0), ground_deep)
	var clear := Color(ground_deep, 0.0)
	var reach := rects[0].end.x
	for i in range(1, rects.size()):
		var r := rects[i]
		if r.position.x > reach + 1.0:
			var top := maxf(rects[i - 1].position.y, r.position.y)
			draw_polygon(PackedVector2Array([Vector2(reach, top), Vector2(r.position.x, top), Vector2(r.position.x, deep), Vector2(reach, deep)]),
				PackedColorArray([clear, clear, ground_deep, ground_deep]))
		reach = maxf(reach, r.end.x)


# ---------------------------------------------------------------- backdrop (screen space)

func _horizon() -> float:
	return _vs.y * horizon_height - (_cam.y - reference_y) * vertical_parallax * _zoom


func _haze_band(n: Node2D, y: float, h: float, a: float) -> void:
	var c0 := Color(haze, 0.0)
	var c1 := Color(haze, a)
	FastDraw.quad(n, PackedVector2Array([Vector2(0, y - h), Vector2(_vs.x, y - h), Vector2(_vs.x, y), Vector2(0, y)]), PackedColorArray([c0, c0, c1, c1]))
	FastDraw.quad(n, PackedVector2Array([Vector2(0, y), Vector2(_vs.x, y), Vector2(_vs.x, y + h * 0.5), Vector2(0, y + h * 0.5)]), PackedColorArray([c1, c1, c0, c0]))


func _paint_backdrop(n: Node2D) -> void:
	_paint_clouds(n)
	if backdrop == Backdrop.DEEP_FOREST:
		FastDraw.rect(n, Rect2(0, 0, _vs.x, _vs.y), Color(haze, fog * 0.35))
	# MEADOW_HILLS / FOREST_EDGE: hills, trees and flowers are cached parallax bands (see below)


func _paint_clouds(n: Node2D) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 17
	var zl := lerpf(1.0, _zoom, 0.5)
	for i in cloud_count:
		var cx := fposmod(r.randf_range(0.0, _vs.x + 800.0) - _cam.x * cloud_parallax * _zoom + _t * cloud_drift, _vs.x + 800.0) - 400.0
		var cy := r.randf_range(_vs.y * 0.08, _vs.y * 0.42)
		var s := r.randf_range(0.8, 1.6) * zl
		for j in 16:
			var off := Vector2(r.randf_range(-160, 160), r.randf_range(-14, 10)) * s
			var rad := r.randf_range(18, 40) * s
			var stretch := r.randf_range(2.8, 4.5)
			n.draw_set_transform(Vector2(cx, cy) + off, 0.0, Vector2(stretch, 0.55))
			FastDraw.circle(n, Vector2.ZERO, rad * 1.4, Color(cloud_color, cloud_opacity * 0.7))
			FastDraw.circle(n, Vector2.ZERO, rad, Color(cloud_color, cloud_opacity))
	n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ---------------------------------------------------------------- dust (world space)

func _paint_dust(n: Node2D) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 33
	var tile := Vector2(1600, 1000) / maxf(_zoom, 0.25)
	var origin := _cam - tile * 0.5
	_paint_front_fog(n)
	for i in dust_count:
		var base := Vector2(r.randf_range(0, tile.x), r.randf_range(0, tile.y))
		var vel := Vector2(r.randf_range(-dust_speed, dust_speed), r.randf_range(-dust_speed * 0.6, dust_speed * 0.3))
		var wob := r.randf_range(4.0, 10.0)
		var f := r.randf_range(0.15, 0.4)
		var ph := r.randf() * TAU
		var p := base + vel * _t + Vector2(sin(_t * f + ph), cos(_t * f * 0.8 + ph)) * wob
		p = Vector2(fposmod(p.x - origin.x, tile.x), fposmod(p.y - origin.y, tile.y)) + origin
		var s := r.randf_range(0.8, 1.8)
		var a := 0.32 + 0.12 * sin(_t * 0.7 + ph)
		FastDraw.circle(n, p, s * 3.0, Color(dust_color, 0.05))
		FastDraw.circle(n, p, s, Color(dust_color, a))


# ---------------------------------------------------------------- forest edge backdrop

## One background tree: a pine (kind 0) or a round broadleaf (kind 1). x, base = screen px.
func _bg_tree(n: Node2D, x: float, base: float, s: float, kind: int, col: Color, r: RandomNumberGenerator) -> void:
	if kind == 0:
		var h := 70.0 * s
		var w := 17.0 * s
		FastDraw.rect(n, Rect2(x - 1.5 * s, base - 10.0 * s, 3.0 * s, 12.0 * s), col)
		for k in 3:
			var top := base - h * (0.45 + 0.27 * k)
			var bot := base - h * 0.16 * (k + 1) - 6.0 * s
			var ww := w * (1.0 - 0.24 * k)
			FastDraw.tri(n, Vector2(x - ww, bot), Vector2(x + ww, bot), Vector2(x, top - h * 0.12), col)
	else:
		var h := 46.0 * s
		FastDraw.rect(n, Rect2(x - 2.0 * s, base - h * 0.6, 4.0 * s, h * 0.6 + 2.0), col)
		for j in 7:
			FastDraw.circle(n, Vector2(x + r.randf_range(-13, 13) * s, base - h * 0.62 - r.randf_range(0, 22) * s), r.randf_range(8, 14) * s, col)


# ---------------------------------------------------------------- foreground grass

func _paint_foreground(n: Node2D) -> void:
	# drawn in screen units around the camera centre
	n.draw_set_transform(-_vs * 0.5 / _zoom, 0.0, Vector2.ONE / _zoom)
	var c := ground_deep
	if foreground_trees > 0:
		_paint_fg_trees(n)
	var period := 1700.0
	var k := _vs.x / 1280.0
	for pass_ in 2:
		var rr := RandomNumberGenerator.new()
		rr.seed = 77
		for clump in 3:
			var cu := rr.randf_range(0.0, period)
			for i in 22:
				var u := cu + rr.randf_range(-130.0, 130.0)
				var hgt := rr.randf_range(40.0, 150.0)
				var lean := rr.randf_range(-25.0, 25.0)
				var w := rr.randf_range(4.0, 8.0) * (2.4 if pass_ == 0 else 1.0)
				var col := Color(c, 0.35) if pass_ == 0 else c
				var sx := fposmod(u - _cam.x * foreground_parallax, period) * k
				for rep in [-period * k, 0.0, period * k]:
					var x: float = sx + rep
					if x < -60.0 or x > _vs.x + 60.0:
						continue
					var sway := sin(_t * 0.9 + u * 0.013) * grass_sway * (hgt / 150.0) if grass_sway > 0.0 else 0.0
					FastDraw.tri(n, Vector2(x - w, _vs.y + 5.0), Vector2(x + w, _vs.y + 5.0), Vector2(x + lean + sway, _vs.y - hgt), col)
	n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Big dark trunks right in front of the camera (they pass by faster than the level).
func _paint_fg_trees(n: Node2D) -> void:
	var period := 2800.0
	var k := _vs.x / 1280.0
	var col0 := Color(ground_deep.darkened(0.25), foreground_tree_opacity)
	var r := RandomNumberGenerator.new()
	r.seed = 91
	if _fg_fade.size() != foreground_trees:
		_fg_fade.resize(foreground_trees)
		_fg_fade.fill(1.0)
	# characters in this painter's screen space
	var bodies := PackedVector2Array()
	for b in get_tree().get_nodes_in_group(&"tether_bodies"):
		if b is Node2D:
			bodies.append(((b as Node2D).global_position - n.global_position) * _zoom + _vs * 0.5)
	for i in foreground_trees:
		var u := (float(i) + r.randf_range(0.15, 0.85)) * period / float(foreground_trees)
		var w := r.randf_range(13.0, 22.0)
		var lean := r.randf_range(-22.0, 22.0)
		var sx := fposmod(u - _cam.x * foreground_parallax * 1.15, period) * k - 200.0
		var stubs: Array[Vector3] = []
		for b in 2:
			stubs.append(Vector3(r.randf_range(_vs.y * 0.1, _vs.y * 0.35), r.randf_range(30.0, 70.0), -1.0 if b == 0 else 1.0))
		var leaves: Array[Vector3] = []
		for j in 9:
			leaves.append(Vector3(r.randf_range(-120.0, 120.0), r.randf_range(-60.0, -5.0), r.randf_range(26.0, 50.0)))
		if sx < -260.0 or sx > _vs.x + 260.0:
			_fg_fade[i] = 1.0
			continue
		var base := _vs.y + 20.0
		var top := -40.0
		var behind := false
		for p in bodies:
			var t := clampf(1.0 - (p.y - top) / (base - top), 0.0, 1.0)
			var bx := sx + lean * t
			var half := lerpf(w * 1.6, w * 0.5, t) + 34.0 * _zoom
			if absf(p.x - bx) < half or (p.y < 70.0 and absf(p.x - (sx + lean)) < 170.0):
				behind = true
		_fg_fade[i] = move_toward(_fg_fade[i], foreground_tree_see_through if behind else 1.0, _dt * 4.0)
		var col := Color(col0, col0.a * _fg_fade[i])
		FastDraw.quad(n, PackedVector2Array([Vector2(sx - w * 1.6, base), Vector2(sx + w * 1.6, base),
			Vector2(sx + w * 0.5 + lean, top), Vector2(sx - w * 0.5 + lean, top)]), PackedColorArray([col]))
		for st in stubs:
			var t := 1.0 - (st.x - top) / (base - top)
			var bx := sx + lean * t
			FastDraw.tri(n, Vector2(bx, st.x - 3.5), Vector2(bx, st.x + 3.5), Vector2(bx + st.z * st.y, st.x - st.y * 0.6), col)
		for lf in leaves:
			FastDraw.circle(n, Vector2(sx + lean + lf.x, lf.y), lf.z, col)


# ---------------------------------------------------------------- deep forest backdrop

## Rows of tall trunks fading into fog, a leaf canopy at the top and dim shafts of light.
func _trunk(n: Node2D, x: float, base: float, top: float, w: float, lean: float, col: Color,
		seed_: int, crown: bool, s: float) -> void:
	var h := base - top
	var tx := x + lean * h
	FastDraw.quad(n, PackedVector2Array([Vector2(x - w * 0.55, base), Vector2(x + w * 0.55, base),
		Vector2(tx + w * 0.38, top), Vector2(tx - w * 0.38, top)]), PackedColorArray([col]))
	# root flare
	FastDraw.tri(n, Vector2(x - w * 1.3, base), Vector2(x - w * 0.4, base), Vector2(x - w * 0.45, base - w * 1.4), col)
	FastDraw.tri(n, Vector2(x + w * 1.3, base), Vector2(x + w * 0.4, base), Vector2(x + w * 0.45, base - w * 1.4), col)
	var r := RandomNumberGenerator.new()
	r.seed = seed_
	# a few bare branches
	for b in r.randi_range(0, 2):
		var k := r.randf_range(0.2, 0.6)
		var py := lerpf(top, base, k)
		var px := lerpf(tx, x, k)
		var dir := -1.0 if r.randf() < 0.5 else 1.0
		var ln := r.randf_range(16.0, 40.0) * s
		var bw := maxf(w * 0.14, 1.0)
		var tip := Vector2(px + dir * ln, py - ln * r.randf_range(0.5, 0.9))
		FastDraw.tri(n, Vector2(px, py - bw), Vector2(px, py + bw), tip, col)
	if crown:
		var cc := col.darkened(0.1)
		for j in 9:
			FastDraw.circle(n, Vector2(tx + r.randf_range(-34.0, 34.0) * s, top + r.randf_range(-26.0, 18.0) * s),
				r.randf_range(14.0, 30.0) * s, cc)


func _paint_shafts(n: Node2D, zl: float) -> void:
	if light_shafts <= 0 or shaft_opacity <= 0.0:
		return
	var r := RandomNumberGenerator.new()
	r.seed = 52
	var period := 2600.0
	var f := 0.22
	for i in light_shafts:
		var u := (float(i) + r.randf_range(0.1, 0.9)) * period / float(light_shafts)
		var w := r.randf_range(50.0, 130.0) * zl
		var slant := r.randf_range(0.18, 0.34) * _vs.y
		var a := shaft_opacity * r.randf_range(0.6, 1.0) * (0.8 + 0.2 * sin(_t * 0.35 + float(i) * 1.9))
		var sx := fposmod((u - _cam.x * f) * zl, period * zl) - 400.0
		while sx <= _vs.x + 200.0:
			if sx >= -400.0:
				var top := Color(shaft_color, a)
				var bot := Color(shaft_color, 0.0)
				FastDraw.quad(n, PackedVector2Array([Vector2(sx, -10), Vector2(sx + w, -10),
					Vector2(sx + w * 1.8 + slant, _vs.y * 0.95), Vector2(sx + slant, _vs.y * 0.95)]),
					PackedColorArray([top, top, bot, bot]))
				var core := Color(shaft_color, a * 0.8)
				FastDraw.quad(n, PackedVector2Array([Vector2(sx + w * 0.35, -10), Vector2(sx + w * 0.6, -10),
					Vector2(sx + w * 1.1 + slant, _vs.y * 0.7), Vector2(sx + w * 0.7 + slant, _vs.y * 0.7)]),
					PackedColorArray([core, core, bot, bot]))
			sx += period * zl


## Low fog drifting in front of the level (drawn with the dust, in world space).
func _paint_front_fog(n: Node2D) -> void:
	if front_fog <= 0.0:
		return
	var sz := _vs / maxf(_zoom, 0.25)
	var tl := _cam - sz * 0.5
	var c0 := Color(haze, 0.0)
	var c1 := Color(haze, front_fog * 0.3)
	FastDraw.quad(n, PackedVector2Array([Vector2(tl.x, tl.y + sz.y * 0.68), Vector2(tl.x + sz.x, tl.y + sz.y * 0.68),
		Vector2(tl.x + sz.x, tl.y + sz.y), Vector2(tl.x, tl.y + sz.y)]), PackedColorArray([c0, c0, c1, c1]))
	var r := RandomNumberGenerator.new()
	r.seed = 71
	var period := sz.x + 1200.0
	for i in 9:
		var u := r.randf_range(0.0, period)
		var spd := r.randf_range(6.0, 16.0)
		var y := tl.y + sz.y * r.randf_range(0.78, 1.0)
		var rad := r.randf_range(110.0, 220.0)
		var x := tl.x + fposmod(u + _t * spd - _cam.x * 0.15, period) - 600.0
		n.draw_set_transform(Vector2(x, y), 0.0, Vector2(3.2, 0.45))
		FastDraw.circle(n, Vector2.ZERO, rad, Color(haze, front_fog * 0.06))
		FastDraw.circle(n, Vector2.ZERO, rad * 0.6, Color(haze, front_fog * 0.05))
	n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ---------------------------------------------------------------- parallax bands (cached in tiles)
# The hills, tree clumps and flowers never change shape - only where they sit on screen. So each
# band is drawn ONCE, in tiles TILE_U wide, and every frame the tiles are just slid into place.
# New tiles are drawn only as the view scrolls onto them (at most a couple per frame). This keeps
# the backdrop almost free per frame, which matters a lot in web builds.

const TILE_U := 640.0


class Band:
	var f := 0.0          # horizontal parallax
	var base := 0.0       # ridge height offset (scaled by zl)
	var amp := 0.0
	var freq := 0.0
	var ph := 0.0
	var col := Color.WHITE
	var items: Array = []  # [u (0..period), period, type, data]; type 0 tree clump tree, 1 flower, 2 meadow tree
	var fixed_y := false   # true: stays at the top of the screen (canopy); false: rides the horizon
	var roots: Array[Node2D] = []
	var draws: Array[Callable] = []  # one tile-draw function per root: fn(n, band, tile_index)
	var tiles := {}        # tile index -> Array of Painters (one per root)


var _bands: Array[Band] = []
var _hazes: Array = []     # Painter per haze band (drawn per frame - two quads each)
var _band_zl := -1.0
var _band_vs := Vector2.ZERO


func _build_bands(layer: Node) -> void:
	if backdrop == Backdrop.FOREST_EDGE:
		_add_band(layer, far_parallax, -40.0, 26.0, 0.0022, 1.0, far_hills)
		_band_trees(_bands[-1], 21, 2600.0, 16, 1.5, 0.35, 0.55, far_hills, 6.0)
		_add_haze(layer, 0.0, 80.0, 0.65)
		_add_band(layer, mid_parallax, 12.0, 20.0, 0.0035, 4.0, mid_hills)
		_band_trees(_bands[-1], 8, 3000.0, 12, 1.2, 0.7, 1.15, mid_hills.darkened(0.08), 8.0)
		_add_haze(layer, 44.0, 70.0, 0.38)
		_add_band(layer, meadow_parallax, 74.0, 14.0, 0.0045, 2.0, meadow)
		_band_trees(_bands[-1], 5, 3600.0, 5, 0.7, 1.4, 2.1, meadow.darkened(0.12), 14.0)
		_band_flowers(_bands[-1])
		_add_haze(layer, 96.0, 54.0, 0.2)
	else:  # MEADOW_HILLS
		_add_band(layer, far_parallax, -40.0, 30.0, 0.0022, 1.0, far_hills)
		_add_haze(layer, 0.0, 70.0, 0.6)
		_add_band(layer, mid_parallax, 10.0, 24.0, 0.0035, 4.0, mid_hills)
		_band_meadow_trees(_bands[-1])
		_add_haze(layer, 40.0, 60.0, 0.35)
		_add_band(layer, meadow_parallax, 70.0, 16.0, 0.0045, 2.0, meadow)
		_band_flowers(_bands[-1])
		_add_haze(layer, 90.0, 50.0, 0.18)


func _add_band(layer: Node, f: float, base: float, amp: float, freq: float, ph: float, col: Color) -> void:
	var b := Band.new()
	b.f = f; b.base = base; b.amp = amp; b.freq = freq; b.ph = ph; b.col = col
	_add_roots(b, layer, [_draw_ridge_tile, _draw_deco_tile])


func _add_roots(b: Band, layer: Node, draws: Array) -> void:
	for d in draws:
		var root := Node2D.new()
		FastDraw.use_on(root)
		layer.add_child(root)
		b.roots.append(root)
		b.draws.append(d)
	_bands.append(b)


func _add_haze(layer: Node, off: float, h: float, a: float) -> void:
	_hazes.append(_painter(layer, func(n: Node2D) -> void:
		var zl := lerpf(1.0, _zoom, 0.6)
		_haze_band(n, _horizon() + off * zl, h * zl, a)))


func _ridge_h(b: Band, u: float) -> float:
	return sin(u * b.freq + b.ph) * b.amp + sin(u * b.freq * 2.3 + b.ph * 1.7) * b.amp * 0.45 \
		+ sin(u * b.freq * 5.3 + b.ph * 0.3) * b.amp * 0.15


## Tree clumps with open plain between them (same placement as before: same seeds, same order).
func _band_trees(b: Band, seed_: int, period: float, clumps: int, density: float, s_min: float, s_max: float,
		col: Color, sink: float) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = seed_
	for c in clumps:
		var cu := r.randf_range(0.0, period)
		var width := r.randf_range(160.0, 520.0) * (0.5 + woodland)
		var count := int(width / 26.0 * density)
		if r.randf() > woodland + 0.25:
			count = r.randi_range(0, 2)  # a lone tree or two out on the plain
		for i in count:
			var u := cu + r.randf_range(-width * 0.5, width * 0.5)
			var edge := 1.0 - absf(u - cu) / (width * 0.5)  # clumps are taller in the middle
			var s := lerpf(s_min, s_max, r.randf()) * (0.65 + 0.35 * edge)
			var kind := 0 if r.randf() < 0.55 else 1
			b.items.append([fposmod(u, period), period, 0,
				[s, kind, seed_ * 131 + c * 17 + i, (c + i) % 3 == 0, col, sink]])


func _band_flowers(b: Band) -> void:
	if flower_count <= 0 or flower_colors.is_empty():
		return
	var r := RandomNumberGenerator.new()
	r.seed = 3
	for i in flower_count:
		var u := r.randf_range(0.0, 2400.0)
		var depth := r.randf_range(3.0, 70.0)
		var c: Color = flower_colors[r.randi() % flower_colors.size()]
		var rad := r.randf_range(0.8, 1.9)
		b.items.append([u, 2400.0, 1, [depth, Color(c, flower_opacity), rad]])


func _band_meadow_trees(b: Band) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 8
	var col := mid_hills.darkened(0.12)
	for i in background_trees:
		var u := r.randf_range(-4000.0, 8000.0)
		var s := r.randf_range(0.7, 1.3)
		var blobs := []
		for j in 6:
			blobs.append(Vector3(r.randf_range(-9, 9), r.randf_range(0, 12), r.randf_range(5, 9)))
		b.items.append([fposmod(u, 1480.0), 1480.0, 2, [s, blobs, col]])


func _update_bands() -> void:
	var zl := lerpf(1.0, _zoom, 0.6)
	var fresh := absf(zl - _band_zl) > 0.001 or _vs != _band_vs
	if fresh:  # zoom or window size changed: every tile is redrawn
		_band_zl = zl
		_band_vs = _vs
		for b in _bands:
			for i in b.tiles:
				for p in b.tiles[i]:
					p.queue_free()
			b.tiles.clear()
	var hy := _horizon()
	var budget := 1000 if fresh else 2
	for b in _bands:
		var pos := Vector2(-_cam.x * b.f * zl + _vs.x * 0.5,
			0.0 if b.fixed_y else hy - (_cam.y - reference_y) * b.f * _zoom * 0.5)
		for root in b.roots:
			root.position = pos
		var uc := _cam.x * b.f
		var half := _vs.x * 0.5 / zl + 260.0
		var i_lo := floori((uc - half) / TILE_U)
		var i_hi := floori((uc + half) / TILE_U)
		for i in range(i_lo, i_hi + 1):
			if not b.tiles.has(i) and budget > 0:
				budget -= 1
				var ps := []
				for k in b.roots.size():
					var p := Painter.new()
					p.fn = b.draws[k].bind(b, i)
					FastDraw.use_on(p)
					b.roots[k].add_child(p)
					ps.append(p)
				b.tiles[i] = ps
		for i in b.tiles.keys():
			if i < i_lo - 2 or i > i_hi + 2:
				for p in b.tiles[i]:
					p.queue_free()
				b.tiles.erase(i)
	for h in _hazes:
		h.queue_redraw()


func _draw_ridge_tile(n: Node2D, b: Band, i: int) -> void:
	var zl := _band_zl
	var u0 := i * TILE_U
	var u1 := u0 + TILE_U
	var step := 6.0 / zl
	var pts := PackedVector2Array()
	var u := u0
	while u < u1 + step:  # overlaps the next tile by one step: no seams
		pts.append(Vector2(u * zl, (b.base + _ridge_h(b, u)) * zl))
		u += step
	pts.append(Vector2(u * zl, 4000.0))
	pts.append(Vector2(u0 * zl, 4000.0))
	n.draw_colored_polygon(pts, b.col)


func _draw_deco_tile(n: Node2D, b: Band, i: int) -> void:
	var zl := _band_zl
	var u0 := i * TILE_U
	var u1 := u0 + TILE_U
	for it in b.items:
		var period: float = it[1]
		var u: float = it[0] + ceilf((u0 - float(it[0])) / period) * period
		while u < u1:
			var y := (b.base + _ridge_h(b, u)) * zl
			var d: Array = it[3]
			match int(it[2]):
				0:  # clump tree
					var rr := RandomNumberGenerator.new()
					rr.seed = d[2]
					var c: Color = d[4]
					var tint := c.lerp(Color("8a8450") if d[3] else Color("5e7a78"), rr.randf() * 0.14)
					_bg_tree(n, u * zl, y + float(d[5]) * zl, float(d[0]) * zl, d[1], tint, rr)
				1:  # flower
					FastDraw.circle(n, Vector2(u * zl, y + float(d[0]) * zl), float(d[2]) * zl, d[1])
				2:  # meadow tree: a stick and a round crown
					var s: float = float(d[0]) * zl
					var x := u * zl
					FastDraw.rect(n, Rect2(x - s, y - 14.0 * s, 2.0 * s, 4.0 + 14.0 * s), d[2])
					for bl in d[1]:
						FastDraw.circle(n, Vector2(x + bl.x * s, y - 18.0 * s - bl.y * s), bl.z * s, d[2])
			u += period


# ---------------------------------------------------------------- deep forest (cached bands)

func _build_deep(layer: Node) -> void:
	var rows := maxi(trunk_rows, 1)
	for row in rows:
		var t := float(row) / maxf(float(rows - 1), 1.0)  # 0 = far, 1 = near
		var b := Band.new()
		b.f = lerpf(far_parallax, meadow_parallax, t)
		b.col = trunk_far.lerp(trunk_near, t)
		b.base = lerpf(-20.0, 110.0, t)  # forest floor of this row, below the horizon (zl units)
		var s_unit := lerpf(0.5, 1.7, t)
		var period := 2400.0
		var count := int(trunk_density * period / 1000.0 * lerpf(1.4, 0.7, t))
		var r := RandomNumberGenerator.new()
		r.seed = 400 + row * 37
		for i in count:
			var u := r.randf_range(0.0, period)
			var w := r.randf_range(8.0, 17.0)
			var lean := r.randf_range(-0.035, 0.035)
			var has_crown := r.randf() < 0.4  # a shorter tree whose crown is in view
			var crown_t := r.randf()
			var tint := b.col.lerp(b.col.lightened(0.12), r.randf() * 0.6)
			b.items.append([u, period, 3, [w, lean, has_crown, crown_t, tint, r.randi(), s_unit]])
		_add_roots(b, layer, [_draw_floor_tile, _draw_trunk_tile])
		if row < rows - 1:
			var fa := fog * lerpf(0.5, 0.28, t)
			var bf := b.f
			var bb := b.base
			_hazes.append(_painter(layer, func(n: Node2D) -> void:
				var zl := lerpf(1.0, _zoom, 0.6)
				var floor_y := _horizon() + bb * zl - (_cam.y - reference_y) * bf * _zoom * 0.5
				FastDraw.rect(n, Rect2(0, 0, _vs.x, _vs.y), Color(haze, fa * 0.45))
				_haze_band(n, floor_y, 110.0 * zl, fa)))
	_hazes.append(_painter(layer, func(n: Node2D) -> void: _paint_shafts(n, lerpf(1.0, _zoom, 0.6))))
	if canopy > 0.0:
		_hazes.append(_painter(layer, func(n: Node2D) -> void:
			var depth := _vs.y * 0.3 * canopy
			var c0 := Color(canopy_color, 0.0)
			var c1 := Color(canopy_color, 0.85 * canopy)
			FastDraw.quad(n, PackedVector2Array([Vector2(0, -2), Vector2(_vs.x, -2), Vector2(_vs.x, depth), Vector2(0, depth)]),
				PackedColorArray([c1, c1, c0, c0]))))
		for li in 2:
			var b := Band.new()
			b.fixed_y = true
			b.f = 0.3 if li == 0 else 0.55
			b.col = canopy_color.lerp(haze, 0.38 * canopy) if li == 0 else canopy_color
			b.base = (0.11 if li == 0 else 0.06) * canopy  # leaf drop, as a fraction of the screen height
			var r := RandomNumberGenerator.new()
			r.seed = 61 + li * 9
			for c in 13:
				var cu := r.randf_range(0.0, 1700.0)
				var cy := r.randf_range(0.2, 1.0)
				var blobs := []
				for j in 11:
					blobs.append(Vector3(r.randf_range(-110.0, 110.0), r.randf_range(-45.0, 22.0), r.randf_range(16.0, 42.0)))
				b.items.append([cu, 1700.0, 4, [cy, blobs]])
			_add_roots(b, layer, [_draw_canopy_tile])
	if ground_fog > 0.0:
		_hazes.append(_painter(layer, func(n: Node2D) -> void:
			var zl := lerpf(1.0, _zoom, 0.6)
			var y0 := _horizon() + 60.0 * zl
			_haze_band(n, y0, 120.0 * zl, ground_fog * 0.55)
			_haze_band(n, y0 + 90.0 * zl, 90.0 * zl, ground_fog * 0.35)))


func _draw_floor_tile(n: Node2D, b: Band, i: int) -> void:
	var zl := _band_zl
	FastDraw.rect(n, Rect2(i * TILE_U * zl, b.base * zl, (TILE_U + 2.0) * zl, 4000.0), b.col)


func _draw_trunk_tile(n: Node2D, b: Band, i: int) -> void:
	var zl := _band_zl
	var u0 := i * TILE_U
	var u1 := u0 + TILE_U
	var floor_l := b.base * zl
	# where this floor sits on screen with the camera at the reference height
	var floor_typ := _vs.y * horizon_height + floor_l
	for it in b.items:
		var period: float = it[1]
		var u: float = it[0] + ceilf((u0 - float(it[0])) / period) * period
		var d: Array = it[3]
		while u < u1:
			var s: float = float(d[6]) * zl
			var w: float = float(d[0]) * s
			var base := floor_l + 6.0 * s
			var top := floor_l - 3000.0  # a tall trunk, running off the top of the screen
			if d[2]:  # a shorter tree with its crown in view: same height above its floor as before
				var top_typ := lerpf(_vs.y * 0.04, maxf(floor_typ - 200.0 * s, _vs.y * 0.05), float(d[3]))
				top = floor_l - (floor_typ - top_typ)
			_trunk(n, u * zl, base, top, w, d[1], d[4], d[5], d[2], s)
			u += period


func _draw_canopy_tile(n: Node2D, b: Band, i: int) -> void:
	var zl := _band_zl
	var drop := b.base * _vs.y
	FastDraw.rect(n, Rect2(i * TILE_U * zl, -2.0, (TILE_U + 2.0) * zl, drop * 0.45 + 2.0), b.col)
	var u0 := i * TILE_U
	var u1 := u0 + TILE_U
	for it in b.items:
		var period: float = it[1]
		var u: float = it[0] + ceilf((u0 - float(it[0])) / period) * period
		var d: Array = it[3]
		while u < u1:
			var cy: float = float(d[0]) * drop
			for bl in d[1]:
				FastDraw.circle(n, Vector2(u * zl + bl.x * zl, cy + bl.y * zl), bl.z * zl, b.col)
			u += period
