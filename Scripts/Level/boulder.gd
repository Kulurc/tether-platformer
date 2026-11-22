@tool
class_name Boulder
extends Block
## A boulder blocking the way, drawn in the same style as the level: a dark stone mass lit
## softly from the top (no outlines), mossy on top, sitting in the grass. Collision is always
## exactly `size` (so a level's measured layout doesn't change). Removed by a KeyItem: it
## cracks apart into tumbling stone chunks and a puff of dust.
## Use the prefab Scenes/Prefabs/boulder.tscn: edit the prefab and every boulder follows.

## Change for a differently shaped rock of the same size.
@export var rock_seed := 3:
	set(v):
		rock_seed = v
		queue_redraw()
## Stone colour at the top (lit) and at the base (in shadow, close to the ground's colour).
@export var rock_color := Color("5d625a"):
	set(v):
		rock_color = v
		queue_redraw()
@export var rock_dark := Color("1a1e19"):
	set(v):
		rock_dark = v
		queue_redraw()
## Soft light along the top edge (like the platforms' lit edge). Alpha = strength.
@export var rim_light := Color(0.78, 0.82, 0.78, 0.22):
	set(v):
		rim_light = v
		queue_redraw()
@export var moss_color := Color("4f6a3a"):
	set(v):
		moss_color = v
		queue_redraw()
@export var moss := true:
	set(v):
		moss = v
		queue_redraw()
## Grass tufts along the bottom edge. Untick for a boulder that isn't sitting on the ground
## (e.g. stacked on another boulder), or the grass floats.
@export var base_grass := true:
	set(v):
		base_grass = v
		queue_redraw()
## How many chunks it breaks into (bigger boulders use up to this many).
@export_range(4, 80) var chunks := 26
## Optional sound when it breaks (the KeyItem's impact sound also plays).
@export var break_sound: AudioStream
@export_range(-40.0, 12.0, 0.5) var break_volume_db := -6.0


## The rock's outline as a closed loop: bottom-left -> left -> over the top -> right ->
## bottom-right. A lumpy rounded mass resting on a flat bottom (narrower where it touches).
func _outline() -> PackedVector2Array:
	var r := RandomNumberGenerator.new()
	r.seed = rock_seed
	var ph := [r.randf() * TAU, r.randf() * TAU, r.randf() * TAU]
	var c := _centre()
	var pts := PackedVector2Array()
	var n := 48
	for i in n + 1:
		var a := PI * 0.5 + TAU * i / float(n)
		var d := Vector2(cos(a), sin(a))
		var k := 0.92 + 0.07 * sin(a * 2.0 + ph[0]) + 0.05 * sin(a * 3.0 + ph[1]) + 0.025 * sin(a * 6.0 + ph[2])
		var p := c + Vector2(d.x * size.x * 0.5, d.y * size.y * 0.56) * k
		p.x = clampf(p.x, 0.0, size.x)
		p.y = clampf(p.y, 0.0, size.y)
		pts.append(p)
	return pts


func _centre() -> Vector2:
	return Vector2(size.x * 0.5, size.y * 0.53)


func _draw() -> void:
	var pts := _outline()
	var r := RandomNumberGenerator.new()
	r.seed = rock_seed * 7 + 1
	var c := _centre()
	var light := Vector2(-0.55, -0.85).normalized()
	# smooth shading: a fan from the centre, each edge vertex lit by which way it faces
	var mid_col := rock_color.lerp(rock_dark, 0.45)
	for i in pts.size() - 1:
		FastDraw.tri3(self, c, pts[i], pts[i + 1], mid_col, _shade_at(pts[i], c, light), _shade_at(pts[i + 1], c, light))
	# a few broad chipped planes on the lit side (slightly lighter flats, no lines)
	for k in 3:
		var i0 := r.randi_range(14, 30)
		var i1 := mini(i0 + r.randi_range(3, 5), pts.size() - 1)
		var inset := pts[i0].lerp(pts[i1], 0.5).lerp(c, r.randf_range(0.3, 0.45))
		var poly := PackedVector2Array([inset])
		for j in range(i0, i1 + 1):
			poly.append(pts[j])
		var tone := Color(rock_color.lightened(0.12), 0.10) if k != 1 else Color(rock_dark, 0.14)
		for j in range(1, poly.size() - 1):  # a fan from the inset point (same shape, batch-friendly)
			FastDraw.tri(self, poly[0], poly[j], poly[j + 1], tone)
	# a couple of soft weathering streaks (tone, not lines)
	for k in 2:
		var x := size.x * r.randf_range(0.3, 0.7)
		var y0 := size.y * r.randf_range(0.15, 0.3)
		FastDraw.quad(self, PackedVector2Array([Vector2(x - 5, y0), Vector2(x + 5, y0), Vector2(x + 2, size.y * 0.85), Vector2(x - 2, size.y * 0.85)]),
			PackedColorArray([Color(rock_dark, 0.0), Color(rock_dark, 0.0), Color(rock_dark, 0.14), Color(rock_dark, 0.14)]))
	# soft rim light along the upper edge (a glow, not a line)
	for e in pts.size() - 1:
		var a := pts[e]
		var b := pts[e + 1]
		var up := (b - a).orthogonal().normalized()
		if up.y > 0.0:
			up = -up
		var facing := clampf(-up.y, 0.0, 1.0)  # strongest on top
		if facing < 0.2:
			continue
		var rc := Color(rim_light, rim_light.a * facing)
		FastDraw.quad(self, PackedVector2Array([a, b, b - up * 7.0, a - up * 7.0]),
			PackedColorArray([rc, rc, Color(rc, 0.0), Color(rc, 0.0)]))
	# moss: clumps hugging the top, a few strands creeping down the sides
	if moss:
		var mc := moss_color
		for m in range(3, pts.size() - 4):
			if r.randf() < 0.55:
				continue
			var p := pts[m].lerp(pts[m + 1], r.randf())
			if p.y > size.y * 0.42:
				continue
			for j in 4:
				var off := Vector2(r.randf_range(-9, 9), r.randf_range(1.0, 6.0))
				FastDraw.circle(self, p + off, r.randf_range(3.0, 6.5), mc.darkened(r.randf_range(0.1, 0.4)))
			FastDraw.circle(self, p + Vector2(r.randf_range(-4, 4), 0.5), r.randf_range(2.0, 3.5), Color(mc.lightened(0.08), 0.8))
			if r.randf() < 0.35:
				var len_ := r.randf_range(10.0, 26.0)
				FastDraw.tri(self, p + Vector2(-3, 2), p + Vector2(3, 2), p + Vector2(r.randf_range(-3, 3), len_), Color(mc.darkened(0.35), 0.8))
	# grass growing up in front of the base, so it sits IN the ground rather than on it
	if not base_grass:
		return
	var gc := Block.meadow_top.darkened(0.15)
	var x := size.x * 0.1
	while x < size.x * 0.9:
		var hgt := r.randf_range(5.0, 15.0)
		FastDraw.tri(self, Vector2(x - 2.5, size.y + 1.0), Vector2(x + 2.5, size.y + 1.0), Vector2(x + r.randf_range(-4, 4), size.y - hgt), gc)
		x += r.randf_range(3.0, 7.0)


func _shade_at(p: Vector2, c: Vector2, light: Vector2) -> Color:
	var nrm := (p - c).normalized()
	var lit := clampf(nrm.dot(light) * 0.5 + 0.5, 0.0, 1.0)
	var t := clampf(p.y / maxf(size.y, 1.0), 0.0, 1.0)
	return rock_dark.lerp(rock_color, clampf(lit * 0.9 + (1.0 - t) * 0.25 - 0.1, 0.0, 1.0))


## Called by a KeyItem instead of the default burst.
func break_apart() -> void:
	var rect := Rect2(global_position, size)
	var cols: Array[Color] = [rock_color, rock_color.darkened(0.25), rock_dark.lightened(0.1), rock_dark]
	if moss:
		cols.append(moss_color.darkened(0.2))
	KeyBurst.spawn(self, rect, cols, clampi(int(rect.get_area() / 900.0), 8, chunks), 1.0, Vector2(7.0, 18.0), false)
	var dust: Array[Color] = [Color(0.62, 0.64, 0.6, 0.28), Color(0.5, 0.52, 0.5, 0.22)]
	KeyBurst.spawn(self, rect.grow(-size.x * 0.2), dust, 14, 0.4, Vector2(8.0, 18.0), false)
	if break_sound:
		var sm := get_node_or_null("/root/SoundManager")
		if sm:
			sm.play_sound(break_sound, break_volume_db)
	queue_free()
