class_name Sprites
extends RefCounted
## All art is generated at startup from these small pixel maps, so the prototype
## has no external assets to replace later.

const PLAYER_BODY := [
	"....KKKKKK....",
	"...KGGGGGGK...",
	"..KGGGGGGGGK..",
	"..KGGGGGGGGGK.",
	"..KKKSSSSSKK..",
	"...KSSKSSKSK..",
	"...KSSSSSSSK..",
	"....KKKKKK....",
	"...KVVVVVVK...",
	"..KVVVYVVVVK..",
	"..KVVVVVVVVK..",
	"..KSVVVVVVSK..",
	"...KVVVVVVK...",
	"...KPPPPPPK...",
]
const PLAYER_LEGS_A := [
	"...KPPKKPPK...",
	"...KPPKKPPK...",
	"...KBBKKBBK...",
	"...KBBKKBBK...",
]
const PLAYER_LEGS_B := [
	"..KPPK..KPPK..",
	"..KPPK..KPPK..",
	"..KBBK..KBBK..",
	".KBBBK..KBBBK.",
]
const ZOMBIE_BODY := [
	"....KKKKKK....",
	"...KZZZZZZK...",
	"...KZZZZZZK...",
	"...KZEZZEZK...",
	"...KZZZZZZK...",
	"...KZKKKKZK...",
	"....KKKKKK....",
	"...KRRRRRRKKK.",
	"..KRRRRRRRZZZK",
	"..KRRRRRRRKKK.",
	"..KRRRRRRK....",
	"...KRRRRK.....",
	"...KPPPPK.....",
]
const ZOMBIE_LEGS_A := [
	"...KPKKPK.....",
	"...KPKKPK.....",
	"...KZKKZK.....",
]
const ZOMBIE_LEGS_B := [
	"..KPK..KPK....",
	"..KPK..KPK....",
	".KZK...KZK....",
]

const OUTLINE := Color(0.06, 0.05, 0.07)

var player: Array[Texture2D] = []
var player_flash: Texture2D
## zombies[kind] is an array of two walk frames.
var zombies: Array = []
var zombie_flash: Texture2D
var blob: Texture2D
var ring: Texture2D


func _init() -> void:
	var soldier := {
		"K": OUTLINE, "G": Color(0.27, 0.42, 0.22), "S": Color(0.91, 0.70, 0.54),
		"V": Color(0.38, 0.47, 0.25), "Y": Color(0.84, 0.70, 0.26),
		"P": Color(0.24, 0.27, 0.22), "B": Color(0.16, 0.13, 0.11),
	}
	player = [_tex(PLAYER_BODY + PLAYER_LEGS_A, soldier), _tex(PLAYER_BODY + PLAYER_LEGS_B, soldier)]
	player_flash = _tex(PLAYER_BODY + PLAYER_LEGS_A, soldier, true)
	zombie_flash = _tex(ZOMBIE_BODY + ZOMBIE_LEGS_A, {}, true)
	zombies = [
		_zombie(Color(0.42, 0.66, 0.34), Color(0.33, 0.37, 0.48), Color(0.25, 0.24, 0.30), Color(0.95, 0.20, 0.15)),
		_zombie(Color(0.78, 0.74, 0.30), Color(0.58, 0.30, 0.24), Color(0.30, 0.22, 0.20), Color(1.0, 0.85, 0.20)),
		_zombie(Color(0.45, 0.36, 0.60), Color(0.23, 0.18, 0.30), Color(0.15, 0.12, 0.20), Color(1.0, 0.35, 0.60)),
		_zombie(Color(0.95, 0.52, 0.20), Color(0.70, 0.24, 0.12), Color(0.35, 0.16, 0.10), Color(1.0, 1.0, 0.45)),
		_zombie(Color(0.72, 0.22, 0.22), Color(0.22, 0.20, 0.26), Color(0.12, 0.10, 0.14), Color(1.0, 0.95, 0.40)),
	]
	blob = _radial()
	ring = _ring_texture()


func _zombie(skin: Color, cloth: Color, pants: Color, eye: Color) -> Array[Texture2D]:
	var palette := {"K": OUTLINE, "Z": skin, "R": cloth, "P": pants, "E": eye}
	var frames: Array[Texture2D] = [
		_tex(ZOMBIE_BODY + ZOMBIE_LEGS_A, palette),
		_tex(ZOMBIE_BODY + ZOMBIE_LEGS_B, palette),
	]
	return frames


func _tex(rows: Array, palette: Dictionary, white := false) -> Texture2D:
	var h := rows.size()
	var w: int = (rows[0] as String).length()
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var row: String = rows[y]
		for x in w:
			var ch := row[x]
			if ch == ".":
				continue
			img.set_pixel(x, y, Color.WHITE if white else palette.get(ch, Color.MAGENTA))
	return ImageTexture.create_from_image(img)


func _radial() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = 64
	tex.height = 64
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	return tex


func _ring_texture() -> Texture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.72, 0.86, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0.05), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = 128
	tex.height = 128
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	return tex
