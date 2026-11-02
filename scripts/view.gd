class_name View
extends RefCounted
## Flat side view. Gameplay happens in (x, height) on a floor and this class maps
## it to world space. All sense of depth is drawn: Parallax2D layers and the fake-3D
## rooms in Depth.

var cam := Vector2.ZERO
var spacing := 0.0


func _init(tuning: Tuning) -> void:
	spacing = tuning.room_h + tuning.slab


func floor_y(f: int) -> float:
	return -float(f) * spacing


func pt(x: float, h: float, f: int) -> Vector2:
	return Vector2(x, -float(f) * spacing - h)
