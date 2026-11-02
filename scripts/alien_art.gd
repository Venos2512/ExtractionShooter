class_name AlienArt
extends RefCounted
## The base alien exported from Figma by tools/export_alien.py: one atlas plus where
## each part sits in the drawing. All positions are in the drawing's own pixels.

const BASE := "alien_base"
const ASSETS := "res://assets/%s/"
## How the two forelimbs of each kind move. See AlienRig.ARM_POSES.
const ARM_STYLES := {"alien_base": "claws", "alien_bomber": "claws", "alien_leaper": "scythe", "alien_stalker": "scythe", "alien_charger": "shield"}
## Where each foot stands along the surface, from the thorax in the drawing's pixels.
## The dark near legs stand wide, the pale far legs inside them, so the near pair frames
## the body and each pair keeps clear of itself.
const DEFAULT_FOOT_X := {"leg_rear_near": -48.0, "leg_rear_far": -22.0, "leg_front_far": 14.0, "leg_front_near": 30.0}
## The same stance for other kinds: how far from its hip, against the length of its leg.
const FOOT_FROM_HIP := {"leg_rear_near": -42.87, "leg_rear_far": -18.74, "leg_front_far": 10.85, "leg_front_near": 28.71}
## How long the base alien's legs are, on each end of the body.
const BASE_REAR_REACH := 76.31
const BASE_FRONT_REACH := 54.55
## How each part of the body moves, as SecondOrder's f, zeta and r. The body pulls back
## before it sets off and bounces a little when it stops. The head and abdomen trail it.
const DEFAULT_MOTION := {
	"body": {"f": 3.0, "zeta": 0.5, "r": -1.0},
	"turn": {"f": 2.2, "zeta": 0.7, "r": 0.0},
	"head": {"f": 1.5, "zeta": 1.0, "r": 0.0},
	"abdomen": {"f": 2.0, "zeta": 0.35, "r": 0.0},
	"arms": {"f": 5.0, "zeta": 0.45, "r": 1.0},
}

## How long the legs are against the drawing. "all" multiplies every leg, the others one
## bone on one end of the body. Near and far legs on an end always match.
const DEFAULT_LEG_LENGTH := {
	"all": 1.0,
	"front_thigh": 1.0, "front_calf": 1.0, "front_shin": 1.0,
	"rear_thigh": 1.0, "rear_calf": 1.0, "rear_shin": 1.0,
}
## How unhinged it moves. 0 is a calm walk, 1 bolts and thrashes, 2 is out of its mind.
const DEFAULT_FRENZY := 1.0
## How far apart its steps are. Only the steps change, never how fast it goes: longer
## steps just come less often. A leg can only step as far as it can reach.
const DEFAULT_STRIDE := 1.0

class Part:
	## In the drawing.
	var rect := Rect2()
	## In the atlas.
	var region := Rect2()

var folder := BASE
## Limb positions, written by the rig lab. Without this file the defaults below apply.
var stance_path := ""
var arm_style := "claws"
## How long its legs are against the base alien's, which sets how far they step and lift.
var size := 1.0
var atlas: Texture2D
var flash: Texture2D
var origin := Vector2.ZERO
var ground_y := 0.0
var order: Array[String] = []
var parts: Dictionary = {}
## Limb name to its four joints: hip, knee, ankle, tip.
var limbs: Dictionary = {}
## Limb name to how it is posed, relative to the thorax in the drawing's pixels. +y is
## down. Legs: hip, foot_x, ankle (from the foot), knee (1 out, -1 in), and pole if the
## knee has been placed by hand, which then decides the ankle. Arms: hip, and turn, the
## radians each segment is turned from the drawing.
var stance: Dictionary = {}
var motion: Dictionary = {}
var leg_length: Dictionary = {}
var frenzy := DEFAULT_FRENZY
var stride := DEFAULT_STRIDE


func _init(the_folder := BASE) -> void:
	folder = the_folder
	arm_style = ARM_STYLES[folder]
	var root := ASSETS % folder
	stance_path = root + "stance.json"
	atlas = load(root + "atlas.png")
	flash = load(root + "atlas_flash.png")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(root + "rig.json"))
	origin = _vec(data.origin)
	ground_y = data.ground_y
	order.assign(data.order)
	var scale: float = data.scale
	for key: String in data.parts:
		var row: Dictionary = data.parts[key]
		var part := Part.new()
		var region: Array = row.region
		part.region = Rect2(region[0], region[1], region[2], region[3])
		part.rect = Rect2(row.box[0], row.box[1], region[2] / scale, region[3] / scale)
		parts[key] = part
	for key: String in data.limbs:
		var joints: Array[Vector2] = []
		for j: Array in data.limbs[key].joints:
			joints.append(_vec(j))
		limbs[key] = joints
	if folder != BASE:
		size = (_reach_of("leg_rear_near") / BASE_REAR_REACH + _reach_of("leg_front_near") / BASE_FRONT_REACH) * 0.5
	load_stance(stance_path)


func _reach_of(limb: String) -> float:
	var joints: Array[Vector2] = limbs[limb]
	return joints[0].distance_to(joints[1]) + joints[1].distance_to(joints[2]) + joints[2].distance_to(joints[3])


func _foot_x(limb: String, hip: Vector2) -> float:
	if folder == BASE:
		return DEFAULT_FOOT_X[limb]
	var end := "leg_rear_near" if limb.contains("rear") else "leg_front_near"
	var base_reach := BASE_REAR_REACH if limb.contains("rear") else BASE_FRONT_REACH
	return hip.x + float(FOOT_FROM_HIP[limb]) * _reach_of(end) / base_reach


func default_stance() -> Dictionary:
	var out := {}
	for limb: String in limbs:
		var joints: Array[Vector2] = limbs[limb]
		var hip := joints[0] - origin
		if limb.begins_with("leg_"):
			var foot_x := _foot_x(limb, hip)
			var shin := joints[2] - joints[3]
			# The shin leans in toward the body, whichever way the drawing had it.
			out[limb] = {"hip": [hip.x, hip.y], "foot_x": foot_x, "ankle": [-signf(foot_x) * absf(shin.x), shin.y], "knee": 1}
		else:
			out[limb] = {"hip": [hip.x, hip.y], "turn": [0.0, 0.0, 0.0]}
	return out


func use_defaults() -> void:
	stance = default_stance()
	motion = DEFAULT_MOTION.duplicate(true)
	leg_length = DEFAULT_LEG_LENGTH.duplicate()
	frenzy = DEFAULT_FRENZY
	stride = DEFAULT_STRIDE


## Anything the file does not mention keeps its default, so old files stay usable.
func load_stance(path: String) -> void:
	use_defaults()
	if not FileAccess.file_exists(path):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		return
	for limb: String in stance:
		if data.has(limb):
			(stance[limb] as Dictionary).merge(data[limb], true)
	var saved_motion: Dictionary = data.get("motion", {})
	for part: String in motion:
		if saved_motion.has(part):
			(motion[part] as Dictionary).merge(saved_motion[part], true)
	var saved_lengths: Dictionary = data.get("leg_length", {})
	leg_length.merge(saved_lengths, true)
	frenzy = data.get("frenzy", frenzy)
	stride = data.get("stride", stride)


func save_stance(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	var out := stance.duplicate()
	out["motion"] = motion
	out["leg_length"] = leg_length
	out["frenzy"] = frenzy
	out["stride"] = stride
	file.store_string(JSON.stringify(out, "\t"))
	return true


func _vec(v: Array) -> Vector2:
	return Vector2(v[0], v[1])
