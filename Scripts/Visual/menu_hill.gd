@tool
class_name MenuHill
extends Node2D
## A grassy ground line with one smooth rounded rise (the main menu's hill). Purely visual.
## Position = the left end of the flat ground. Shape it in the Inspector; it redraws live.

@export var width := 1700.0:
	set(v):
		width = v
		queue_redraw()
## How far the ground fills downward below the ground line.
@export var depth := 320.0:
	set(v):
		depth = v
		queue_redraw()
## Where the top of the rise is, measured from this node's position.
@export var rise_center := 1135.0:
	set(v):
		rise_center = v
		queue_redraw()
## Width of the rise at its base.
@export var rise_width := 760.0:
	set(v):
		rise_width = v
		queue_redraw()
@export var rise_height := 150.0:
	set(v):
		rise_height = v
		queue_redraw()
@export var top_color := Color("3a2a2b"):
	set(v):
		top_color = v
		queue_redraw()
@export var body_color := Color("1a1214"):
	set(v):
		body_color = v
		queue_redraw()
@export var grass := true:
	set(v):
		grass = v
		queue_redraw()
@export var grass_color := Color("2a1d1f"):
	set(v):
		grass_color = v
		queue_redraw()
## Grass blades sway by up to this many px at their tips (0 = still). Done on the GPU by
## Shaders/sway.gdshader, so the hill is drawn once and costs almost nothing per frame.
@export_range(0.0, 10.0, 0.1) var grass_sway := 0.0
## Sway cycles per second.
@export_range(0.01, 2.0, 0.01) var grass_sway_speed := 0.18

## Change for a different scatter of grass blades.
@export var grass_seed := 5:
	set(v):
		grass_seed = v
		queue_redraw()


func _ready() -> void:
	if grass_sway > 0.0 and not Engine.is_editor_hint():
		var m := ShaderMaterial.new()
		m.shader = preload("res://Shaders/sway.gdshader")
		m.set_shader_parameter("mode", 1)
		m.set_shader_parameter("amount", grass_sway)
		m.set_shader_parameter("speed", grass_sway_speed)
		material = m


## Height of the ground line at local x (negative = up).
func ground_y(x: float) -> float:
	var t := (x - rise_center) / maxf(rise_width * 0.5, 1.0)
	if absf(t) >= 1.0:
		return 0.0
	return -rise_height * (cos(t * PI) + 1.0) * 0.5


func _draw() -> void:
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var x := 0.0
	while x <= width:
		pts.append(Vector2(x, ground_y(x)))
		cols.append(top_color)
		x += 8.0
	pts.append(Vector2(width, depth))
	cols.append(body_color)
	pts.append(Vector2(0.0, depth))
	cols.append(body_color)
	var uvs := PackedVector2Array()
	uvs.resize(pts.size())
	uvs.fill(Vector2(0.5, 0.5))  # solid centre of FastDraw's disc: same texture as the blades
	draw_polygon(pts, cols, uvs, FastDraw.disc())
	if not grass:
		return
	var r := RandomNumberGenerator.new()
	r.seed = grass_seed
	x = 0.0
	while x <= width:
		var y := ground_y(x)
		var h := r.randf_range(5.0, 15.0) * (1.8 if r.randf() < 0.06 else 1.0)
		var lean := r.randf_range(-4.0, 5.0)
		# tip drawn with UV.y = 0.25: the sway shader moves only those points
		var tip := Vector2(x + lean, y - h)
		draw_primitive(PackedVector2Array([Vector2(x - 1.8, y + 2.0), Vector2(x + 1.8, y + 2.0), tip, tip]),
			PackedColorArray([grass_color, grass_color, grass_color, grass_color]),
			PackedVector2Array([Vector2(0.5, 0.5), Vector2(0.5, 0.5), Vector2(0.5, 0.25), Vector2(0.5, 0.25)]), FastDraw.disc())
		x += r.randf_range(2.0, 4.5)
