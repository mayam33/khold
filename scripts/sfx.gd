extends Node

## Tiny synth so the game has feedback sounds without shipping audio files.

const RATE := 22050
const POOL := 8

var _players: Array[AudioStreamPlayer] = []
var _cache: Dictionary = {}
var _next := 0

func _ready() -> void:
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)

	_cache["dig"] = _tone(170.0, 55.0, 0.10, 0.30, 0.55)
	_cache["step"] = _tone(120.0, 80.0, 0.05, 0.12, 0.25)
	_cache["push"] = _tone(130.0, 60.0, 0.14, 0.28, 0.30)
	_cache["rock"] = _tone(95.0, 35.0, 0.22, 0.40, 0.45)
	_cache["bump"] = _tone(85.0, 55.0, 0.06, 0.22, 0.10)
	_cache["click"] = _tone(760.0, 520.0, 0.035, 0.10, 0.0)
	_cache["collect"] = _sequence([660.0, 880.0, 1320.0], 0.060, 0.28)
	_cache["unlock"] = _sequence([523.0, 659.0, 784.0, 1046.0], 0.075, 0.30)
	_cache["win"] = _sequence([523.0, 659.0, 784.0, 1046.0, 1318.0], 0.095, 0.32)
	_cache["die"] = _tone(320.0, 55.0, 0.52, 0.35, 0.18)

func play(name: String, pitch := 1.0) -> void:
	if not bool(Store.settings.get("sound", true)):
		return
	var stream: AudioStream = _cache.get(name, null)
	if stream == null:
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stop()
	p.stream = stream
	p.pitch_scale = clampf(pitch, 0.5, 2.0)
	p.play()

func stop_all() -> void:
	for p in _players:
		p.stop()
		p.stream = null

func haptic(ms := 10) -> void:
	if not bool(Store.settings.get("haptics", true)):
		return
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)

func _tone(f0: float, f1: float, duration: float, volume: float, noise: float) -> AudioStreamWAV:
	var count := int(RATE * duration)
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase := 0.0
	for i in count:
		var k := float(i) / float(count)
		var f := lerpf(f0, f1, k)
		phase += TAU * f / float(RATE)
		var s := sin(phase)
		if noise > 0.0:
			s = lerpf(s, randf_range(-1.0, 1.0), noise)
		var env := minf(1.0, float(i) / (RATE * 0.005)) * pow(1.0 - k, 1.7)
		data.encode_s16(i * 2, int(clampf(s * env * volume, -1.0, 1.0) * 32767.0))
	return _make_wav(data)

func _sequence(freqs: Array, note_duration: float, volume: float) -> AudioStreamWAV:
	var count := int(RATE * note_duration * float(freqs.size()))
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var t := float(i) / float(RATE)
		var index := mini(int(t / note_duration), freqs.size() - 1)
		var local := fmod(t, note_duration)
		var k := local / note_duration
		var f: float = freqs[index]
		var env := minf(1.0, local / 0.004) * pow(1.0 - k, 1.3)
		var s := sin(TAU * f * t) * 0.8 + sin(TAU * f * 2.0 * t) * 0.2
		data.encode_s16(i * 2, int(clampf(s * env * volume, -1.0, 1.0) * 32767.0))
	return _make_wav(data)

func _make_wav(data: PackedByteArray) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	return wav
