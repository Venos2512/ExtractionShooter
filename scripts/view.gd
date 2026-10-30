class_name View
extends RefCounted
## The fake 3D. Gameplay happens in (x, height, depth) on a floor and this class
## projects it to 2D with a pinhole camera that follows the player on x.
## Each floor gets the same eye height, so every floor reads like a doll house
## tilted toward the viewer and every floor plane shows as a trapezoid.

var t: Tuning
var cam := Vector2.ZERO
var spacing := 0.0


func _init(tuning: Tuning) -> void:
	t = tuning
	spacing = t.room_h + t.slab


func floor_y(f: int) -> float:
	return -float(f) * spacing


func s_at(z: float) -> float:
	return t.focal / (t.focal + z)


func pt(x: float, h: float, z: float, f: int) -> Vector2:
	var fy := -float(f) * spacing
	var s := t.focal / (t.focal + z)
	var ey := fy - t.eye_h + clampf((cam.y - (fy - 110.0)) * 0.05, -24.0, 24.0)
	return Vector2(cam.x + (x - cam.x) * s, ey + (fy - h - ey) * s)


## For things far outside the building, such as the skyline.
func far_pt(x: float, y: float, z: float) -> Vector2:
	var s := t.focal / (t.focal + z)
	return Vector2(cam.x + (x - cam.x) * s, cam.y + (y - cam.y) * s)
