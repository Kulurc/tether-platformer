@tool
class_name Block
extends StaticBody2D
## Placeholder solid geometry. Position = top-left corner; resize with `size` in the Inspector.
## `look` only changes how it's DRAWN - the collision box is always exactly `size`.
##   PLAIN   flat colour (default)
##   MEADOW  grassy earth: lit top fading to dark, grass + flowers along exposed tops, rough
##           rock on exposed sides. Colours come from the level's LevelArt node.

enum Look { PLAIN, MEADOW }

@export var size := Vector2(128, 32):
	set(v):
		size = v
		_sync()
@export var color := Color(0.2, 0.23, 0.3):
	set(v):
		color = v
		queue_redraw()
@export var look := Look.PLAIN:
	set(v):
		look = v
		queue_redraw()

# Meadow palette, shared by every block (a LevelArt node overrides these).
static var meadow_top := Color("3c6a3c")
static var meadow_body := Color("1d3a29")
static var meadow_deep := Color("0d1813")
static var meadow_flowers: Array[Color] = [Color("ffe066"), Color("ffffff"), Color("ff9fb5"), Color("a8c8ff"), Color("ffb347")]

var _shape: CollisionShape2D


func _enter_tree() -> void:
	add_to_group(&"blocks")
	if Engine.is_editor_hint():
		set_notify_transform(true)  # neighbours redraw their grass/rock edges when this moves


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and Engine.is_editor_hint():
		redraw_all(get_tree())


static func redraw_all(tree: SceneTree) -> void:
	if tree:
		for b in tree.get_nodes_in_group(&"blocks"):
			(b as CanvasItem).queue_redraw()


func _ready() -> void:
	FastDraw.use_on(self)  # meadow flowers are FastDraw discs
	_sync()


func _sync() -> void:
	if not is_inside_tree():
		return
	if _shape == null:
		_drop_stray_shapes()
		_shape = CollisionShape2D.new()
		_shape.shape = RectangleShape2D.new()
		# Internal child: not shown in the Scene dock, not copied by Ctrl+D, never saved.
		add_child(_shape, false, Node.INTERNAL_MODE_FRONT)
	(_shape.shape as RectangleShape2D).size = size
	_shape.position = size * 0.5
	if look == Look.MEADOW and Engine.is_editor_hint():
		redraw_all(get_tree())
	queue_redraw()


func _draw() -> void:
	if look == Look.MEADOW:
		_draw_meadow()
		return
	draw_rect(Rect2(Vector2.ZERO, size), color)
	draw_line(Vector2(0, 1), Vector2(size.x, 1), color.lightened(0.35), 2.0)


# ---------------------------------------------------------------- meadow look

const _BAND := 70.0  # px of sunlit top before the earth goes dark


func _body_col(y: float) -> Color:
	var band := minf(_BAND, size.y)
	if y < band:
		return meadow_top.lerp(meadow_body, y / band)
	return meadow_body.lerp(meadow_deep, clampf((y - band) / maxf(size.y - band, 1.0), 0.0, 1.0))


## Other blocks' rectangles in this block's local space (to find which edges are exposed).
func _neighbour_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	if not is_inside_tree():
		return out
	for b in get_tree().get_nodes_in_group(&"blocks"):
		if b != self and b is Block:
			out.append(Rect2((b as Block).global_position - global_position, (b as Block).size))
	return out


func _covered(p: Vector2, rects: Array[Rect2]) -> bool:
	for r in rects:
		if r.has_point(p):
			return true
	return false


func _draw_meadow() -> void:
	var rects := _neighbour_rects()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(global_position))  # same grass every time for this block
	var band := minf(_BAND, size.y)
	# body: lit top band, then dark earth
	FastDraw.quad(self, PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), Vector2(size.x, band), Vector2(0, band)]),
		PackedColorArray([meadow_top, meadow_top, meadow_body, meadow_body]))
	if size.y > band:
		FastDraw.quad(self, PackedVector2Array([Vector2(0, band), Vector2(size.x, band), size, Vector2(0, size.y)]),
			PackedColorArray([meadow_body, meadow_body, meadow_deep, meadow_deep]))
	# rough rock on exposed sides - drawn OUTSIDE the box only
	for side in [-1.0, 1.0]:
		var sx: float = 0.0 if side < 0.0 else size.x
		var pts := PackedVector2Array()
		var cols := PackedColorArray()
		var y := 3.0
		while y < size.y:
			if _covered(Vector2(sx + side * 3.0, y), rects):
				if pts.size() >= 2:
					_rock_strip(pts, cols, sx, side)
				pts = PackedVector2Array(); cols = PackedColorArray()
				y += 12.0
				continue
			var out := rng.randf_range(1.0, 6.0) * (0.4 if y < 12.0 else 1.0)
			pts.append(Vector2(sx + side * out, y))
			cols.append(_body_col(y))
			y += rng.randf_range(8.0, 16.0)
		if pts.size() >= 2:
			_rock_strip(pts, cols, sx, side)
	# grass, flowers and a sunlit lip along exposed top edges
	var lip := PackedVector2Array()
	var lip_col := Color(0.75, 0.95, 0.6, 0.35)
	var x := 0.0
	while x <= size.x:
		if not _covered(Vector2(x, -2.0), rects):
			var hgt := rng.randf_range(5, 13) * (1.7 if rng.randf() < 0.07 else 1.0)
			var lean := rng.randf_range(-4, 5)
			FastDraw.tri(self, Vector2(x - 1.6, 1), Vector2(x + 1.6, 1), Vector2(x + lean, -hgt), meadow_top)
			if rng.randf() < 0.03 and not meadow_flowers.is_empty():
				var fc: Color = meadow_flowers[rng.randi() % meadow_flowers.size()]
				FastDraw.line(self, Vector2(x, 0), Vector2(x + lean * 1.3, -hgt - 7), meadow_top, 1.0)
				FastDraw.circle(self, Vector2(x + lean * 1.3, -hgt - 8), 2.3, fc)
			lip.append(Vector2(x, 0.5))
		elif lip.size() > 1:
			_lip(lip, lip_col)
			lip = PackedVector2Array()
		x += rng.randf_range(2.0, 4.0)
	if lip.size() > 1:
		_lip(lip, lip_col)


func _rock_strip(pts: PackedVector2Array, cols: PackedColorArray, sx: float, side: float) -> void:
	# the same outline as before, drawn as one quad per segment (batch-friendly)
	for k in pts.size() - 1:
		FastDraw.quad(self, PackedVector2Array([pts[k], pts[k + 1], Vector2(sx - side, pts[k + 1].y), Vector2(sx - side, pts[k].y)]),
			PackedColorArray([cols[k], cols[k + 1], cols[k + 1], cols[k]]))


## The sunlit lip along an exposed top edge (was a polyline), as thin quads.
func _lip(lip: PackedVector2Array, col: Color) -> void:
	for k in lip.size() - 1:
		FastDraw.line(self, lip[k], lip[k + 1], col, 1.5)

## Older versions added this shape as a normal child, so Ctrl+D copied it and every
## duplicate kept a stale extra shape. Remove any unowned leftovers (never your own nodes).
func _drop_stray_shapes() -> void:
	for c in get_children():
		if c is CollisionShape2D and c.owner == null and c != _shape:
			remove_child(c)
			c.queue_free()
