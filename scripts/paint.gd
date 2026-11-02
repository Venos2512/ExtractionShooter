class_name Paint
extends RefCounted
## Low resolution image painter behind all generated art. Spans go through
## fill_rect, which is native, so painting whole city layers stays cheap.

const CLEAR := Color(0, 0, 0, 0)

var img: Image
var w := 0
var h := 0


func _init(width: int, height: int) -> void:
	w = width
	h = height
	img = Image.create_empty(w, h, false, Image.FORMAT_RGBA8)


func rect(x: int, y: int, rw: int, rh: int, col: Color) -> void:
	if rw > 0 and rh > 0:
		img.fill_rect(Rect2i(x, y, rw, rh), col)


func dot(x: int, y: int, col: Color) -> void:
	if x >= 0 and y >= 0 and x < w and y < h:
		img.set_pixel(x, y, col)


func disc(cx: float, cy: float, rx: float, ry: float, col: Color) -> void:
	for y in range(floori(cy - ry), ceili(cy + ry) + 1):
		var u := (y + 0.5 - cy) / ry
		if absf(u) < 1.0:
			var half := rx * sqrt(1.0 - u * u)
			rect(roundi(cx - half), y, roundi(half * 2.0), 1, col)


func line(a: Vector2, b: Vector2, col: Color, thick := 1) -> void:
	var steps := int(maxf(absf(b.x - a.x), absf(b.y - a.y))) + 1
	var half := int(thick * 0.5)
	for i in steps + 1:
		var q := a.lerp(b, float(i) / steps)
		rect(floori(q.x) - half, floori(q.y) - half, thick, thick, col)


## One vertical slice through an ellipse, used for carapace segments.
func band(cx: float, cy: float, rx: float, ry: float, x: int, col: Color) -> void:
	var u := (x + 0.5 - cx) / rx
	if absf(u) < 1.0:
		var half := ry * sqrt(1.0 - u * u)
		rect(x, roundi(cy - half), 1, roundi(half * 2.0), col)


func outline(col: Color) -> void:
	var src := img.duplicate() as Image
	for y in h:
		for x in w:
			if src.get_pixel(x, y).a > 0.0:
				continue
			if (x > 0 and src.get_pixel(x - 1, y).a > 0.0) or (x < w - 1 and src.get_pixel(x + 1, y).a > 0.0) or (y > 0 and src.get_pixel(x, y - 1).a > 0.0) or (y < h - 1 and src.get_pixel(x, y + 1).a > 0.0):
				img.set_pixel(x, y, col)


## Same silhouette in solid white, drawn on top for hit flashes.
func flash_texture() -> Texture2D:
	var white := img.duplicate() as Image
	for y in h:
		for x in w:
			if white.get_pixel(x, y).a > 0.0:
				white.set_pixel(x, y, Color.WHITE)
	return ImageTexture.create_from_image(white)


func texture() -> Texture2D:
	return ImageTexture.create_from_image(img)
