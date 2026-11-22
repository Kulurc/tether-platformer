@tool
class_name MeadowTree
extends Node2D
## A decorative silhouette tree, generated from a seed. Purely visual - no collision.
## Position = the base of the trunk; put it on top of a platform (it sinks in a few px).
## Change `tree_seed` for a different tree with the same overall size.

@export var tree_seed := 4:
	set(v):
		tree_seed = v
		queue_redraw()
@export_range(30.0, 300.0, 1.0) var trunk_length := 110.0:
	set(v):
		trunk_length = v
		queue_redraw()
@export_range(2.0, 40.0, 0.5) var trunk_width := 16.0:
	set(v):
		trunk_width = v
		queue_redraw()
## How many times branches split (more = a bigger, fuller crown).
@export_range(2, 6) var branch_levels := 5:
	set(v):
		branch_levels = v
		queue_redraw()
## How spread out the leaf clusters are around each branch tip.
@export_range(10.0, 80.0, 1.0) var leaf_spread := 38.0:
	set(v):
		leaf_spread = v
		queue_redraw()
@export var leaf_color := Color("1d3a29"):
	set(v):
		leaf_color = v
		queue_redraw()
## Sunlit edge on the top-right of the crown.
@export var highlight_color := Color("4a7a49"):
	set(v):
		highlight_color = v
		queue_redraw()
## Off = a dead, bare tree: just the branches, with thin twigs at the tips.
@export var leaves := true:
	set(v):
		leaves = v
		queue_redraw()
## Gentle sway in the wind, roughly radians of lean at the crown (0 = still). Done on the GPU by
## Shaders/sway.gdshader: the tree is drawn once and only bent, so it costs almost nothing.
@export_range(0.0, 0.3, 0.005) var sway := 0.0
## Sway cycles per second.
@export_range(0.01, 2.0, 0.01) var sway_speed := 0.2

@export var blossoms := true:
	set(v):
		blossoms = v
		queue_redraw()
@export var blossom_color := Color(1.0, 0.85, 0.9, 0.7):
	set(v):
		blossom_color = v
		queue_redraw()


func _ready() -> void:
	FastDraw.use_on(self)  # circles below are FastDraw discs (batched: ~1 draw call, not thousands)
	z_as_relative = false
	z_index = -1  # behind the characters and the cord, in front of the backdrop
	if sway > 0.0 and not Engine.is_editor_hint():
		var m := ShaderMaterial.new()
		m.shader = preload("res://Shaders/sway.gdshader")
		var h := trunk_length * 2.6  # roughly the tree's height
		m.set_shader_parameter("mode", 0)
		m.set_shader_parameter("height", h)
		m.set_shader_parameter("amount", sway * h)
		m.set_shader_parameter("speed", sway_speed)
		m.set_shader_parameter("phase", float(tree_seed) * 1.7)
		material = m


func _draw() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = tree_seed
	var tips: Array[Vector2] = []
	_branch(r, Vector2(0, 4), -PI / 2 + 0.04, trunk_length, trunk_width, 0, tips)
	if not leaves:
		_twigs(tips)
		return
	for pass_ in 2:
		var rr := RandomNumberGenerator.new()
		rr.seed = tree_seed * 11 + 40
		var c := highlight_color if pass_ == 0 else leaf_color
		var off := Vector2(4, -4) if pass_ == 0 else Vector2.ZERO
		for t in tips:
			for j in 26:
				var a := rr.randf() * TAU
				var d := sqrt(rr.randf()) * leaf_spread
				FastDraw.circle(self, t + off + Vector2(cos(a), sin(a) * 0.8) * d, rr.randf_range(5.0, 13.0), c)
	var rf := RandomNumberGenerator.new()
	rf.seed = tree_seed * 11 + 41
	for t in tips:
		for j in 10:
			var a := rf.randf() * TAU
			FastDraw.circle(self, t + Vector2(cos(a), sin(a) * 0.8) * rf.randf_range(leaf_spread + 2.0, leaf_spread + 14.0), rf.randf_range(1.5, 3.5), leaf_color)
	if blossoms:
		for t in tips:
			if rf.randf() < 0.5:
				FastDraw.circle(self, t + Vector2(rf.randf_range(-30, 30), rf.randf_range(-24, 20)), 1.8, blossom_color)


func _branch(r: RandomNumberGenerator, p: Vector2, ang: float, length: float, w: float, depth: int, tips: Array[Vector2]) -> void:
	var q := p + Vector2(cos(ang), sin(ang)) * length
	var side := Vector2(-sin(ang), cos(ang))
	FastDraw.quad(self, PackedVector2Array([p - side * w * 0.5, p + side * w * 0.5, q + side * w * 0.33, q - side * w * 0.33]), PackedColorArray([leaf_color]))
	if depth >= branch_levels:
		tips.append(q)
		return
	var kids := 3 if depth == 0 else 2
	for i in kids:
		var spread := r.randf_range(0.25, 0.6) * (1.0 if i % 2 == 0 else -1.0)
		_branch(r, q, ang + spread * 0.85, length * r.randf_range(0.6, 0.74), w * 0.68, depth + 1, tips)


func _twigs(tips: Array[Vector2]) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = tree_seed * 7 + 3
	for t in tips:
		for j in 3:
			var a := -PI / 2 + r.randf_range(-1.1, 1.1)
			var ln := r.randf_range(8.0, 20.0)
			var q := t + Vector2(cos(a), sin(a)) * ln
			draw_line(t, q, leaf_color, r.randf_range(1.0, 1.8), true)
			if r.randf() < 0.5:
				var a2 := a + r.randf_range(-0.7, 0.7)
				draw_line(q, q + Vector2(cos(a2), sin(a2)) * ln * 0.5, leaf_color, 1.0, true)
