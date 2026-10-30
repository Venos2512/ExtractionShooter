class_name Sfx
extends Node
## Placeholder sounds synthesized at startup, played through a small voice pool.
## A per-sound rate limit stops the horde from turning into one long hiss.

const RATE := 22050
const VOICES := 12

var streams: Dictionary = {}
var players: Array[AudioStreamPlayer] = []
var next_voice := 0
var last_played: Dictionary = {}
var rng := RandomNumberGenerator.new()
var muted := false


func _ready() -> void:
	rng.seed = 7
	streams = {
		"shot": _noise(0.10, 34.0, 0.45),
		"hit": _noise(0.05, 70.0, 0.25),
		"die": _noise(0.16, 20.0, 0.75),
		"boom": _noise(0.60, 6.0, 0.92),
		"pick": _tone(880.0, 1320.0, 0.10, 0.5),
		"card": _tone(520.0, 1040.0, 0.22, 0.5),
		"alarm": _tone(620.0, 380.0, 0.70, 0.4),
		"hurt": _tone(220.0, 110.0, 0.16, 0.6),
		"dash": _noise(0.18, 10.0, 0.25),
		"door": _noise(0.12, 16.0, 0.85),
		"win": _tone(440.0, 1320.0, 0.8, 0.5),
		"lose": _tone(330.0, 90.0, 0.9, 0.5),
	}
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)


func play(id: String, volume_db := 0.0, min_gap := 0.03) -> void:
	if muted or not streams.has(id):
		return
	var now := Time.get_ticks_msec() * 0.001
	if now - float(last_played.get(id, -1.0)) < min_gap:
		return
	last_played[id] = now
	var p := players[next_voice]
	next_voice = (next_voice + 1) % VOICES
	p.stream = streams[id]
	p.volume_db = volume_db
	p.pitch_scale = rng.randf_range(0.92, 1.08)
	p.play()


func _noise(length: float, decay: float, smooth: float) -> AudioStreamWAV:
	var n := int(RATE * length)
	var data := PackedByteArray()
	data.resize(n * 2)
	var last := 0.0
	for i in n:
		var env := exp(-decay * float(i) / RATE)
		last = lerpf(rng.randf_range(-1.0, 1.0), last, smooth)
		data.encode_s16(i * 2, int(clampf(last * env * 1.4, -1.0, 1.0) * 32000.0))
	return _wav(data)


func _tone(from_hz: float, to_hz: float, length: float, volume: float) -> AudioStreamWAV:
	var n := int(RATE * length)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	for i in n:
		var u := float(i) / n
		phase += TAU * lerpf(from_hz, to_hz, u) / RATE
		var env := (1.0 - u) * minf(u * 40.0, 1.0)
		data.encode_s16(i * 2, int(sin(phase) * env * volume * 32000.0))
	return _wav(data)


func _wav(data: PackedByteArray) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w
