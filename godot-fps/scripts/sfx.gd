extends Node
## Procedural sound effects (autoloaded as `Sfx`).
## Every sound is synthesised at startup, so the project ships with no audio
## files. Swap any entry in `streams` for a real AudioStream to upgrade it.

const RATE := 22050

var streams := {}
var _players: Array[AudioStreamPlayer] = []
var _players_3d: Array[AudioStreamPlayer3D] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# dur: seconds, noise/tone: mix amounts, decay: envelope speed,
	# lp: low-pass amount (0..1, lower = duller), f0 -> f1: pitch sweep in Hz.
	streams = {
		"pistol": _synth({dur = 0.25, noise = 0.8, tone = 0.5, decay = 22.0, lp = 0.45, f0 = 190.0, f1 = 60.0}),
		"shotgun": _synth({dur = 0.55, noise = 1.0, tone = 0.6, decay = 8.0, lp = 0.3, f0 = 110.0, f1 = 40.0}),
		"rifle": _synth({dur = 0.16, noise = 0.8, tone = 0.4, decay = 32.0, lp = 0.6, f0 = 240.0, f1 = 90.0}),
		"enemy_shot": _synth({dur = 0.25, noise = 0.1, tone = 0.6, decay = 10.0, lp = 0.9, f0 = 950.0, f1 = 260.0, wave = "square"}),
		"hit": _synth({dur = 0.06, tone = 0.6, decay = 40.0, lp = 1.0, f0 = 1300.0, f1 = 1100.0}),
		"headshot": _synth({dur = 0.12, tone = 0.6, decay = 25.0, lp = 1.0, f0 = 1800.0, f1 = 2200.0, wave = "square"}),
		"hurt": _synth({dur = 0.3, noise = 0.3, tone = 0.6, decay = 9.0, lp = 0.4, f0 = 150.0, f1 = 80.0, wave = "saw"}),
		"melee": _synth({dur = 0.2, noise = 0.9, tone = 0.4, decay = 18.0, lp = 0.15, f0 = 90.0, f1 = 50.0}),
		"enemy_death": _synth({dur = 0.6, noise = 0.2, tone = 0.6, decay = 5.0, lp = 0.5, f0 = 320.0, f1 = 55.0, wave = "saw"}),
		"alert": _synth({dur = 0.25, tone = 0.4, decay = 8.0, lp = 0.6, f0 = 200.0, f1 = 340.0, wave = "square"}),
		"pickup": _synth({dur = 0.25, tone = 0.5, decay = 9.0, lp = 1.0, f0 = 600.0, f1 = 1500.0}),
		"key": _synth({dur = 0.5, tone = 0.5, decay = 4.0, lp = 1.0, f0 = 500.0, f1 = 1000.0, wave = "square"}),
		"door": _synth({dur = 0.8, noise = 0.7, tone = 0.3, decay = 3.5, lp = 0.08, f0 = 70.0, f1 = 50.0}),
		"locked": _synth({dur = 0.3, tone = 0.5, decay = 6.0, lp = 0.7, f0 = 160.0, f1 = 140.0, wave = "square"}),
		"empty": _synth({dur = 0.04, noise = 0.6, decay = 80.0, lp = 0.9}),
		"reload": _synth({dur = 0.18, noise = 0.6, tone = 0.2, decay = 30.0, lp = 0.7, f0 = 900.0, f1 = 700.0}),
		"exit": _synth({dur = 1.0, tone = 0.5, decay = 2.5, lp = 1.0, f0 = 300.0, f1 = 900.0}),
		"player_death": _synth({dur = 1.2, noise = 0.3, tone = 0.6, decay = 2.5, lp = 0.4, f0 = 220.0, f1 = 40.0, wave = "saw"}),
	}
	for i in 12:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	for i in 12:
		var p3 := AudioStreamPlayer3D.new()
		p3.unit_size = 6.0
		p3.max_distance = 60.0
		add_child(p3)
		_players_3d.append(p3)


## Plays a non-positional sound (player weapons, UI).
func play(sound: String, volume_db := 0.0, pitch_jitter := 0.06) -> void:
	if not streams.has(sound):
		return
	var p := _free_player(_players) as AudioStreamPlayer
	p.stream = streams[sound]
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.play()


## Plays a sound at a world position (enemies, doors).
func play_at(sound: String, pos: Vector3, volume_db := 0.0) -> void:
	if not streams.has(sound):
		return
	var p := _free_player(_players_3d) as AudioStreamPlayer3D
	p.stream = streams[sound]
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-0.08, 0.08)
	p.global_position = pos
	p.play()


func _free_player(pool: Array) -> Node:
	for p in pool:
		if not p.playing:
			return p
	return pool[0]


func _synth(o: Dictionary) -> AudioStreamWAV:
	var dur: float = o.get("dur", 0.2)
	var noise_amt: float = o.get("noise", 0.0)
	var tone_amt: float = o.get("tone", 0.0)
	var decay: float = o.get("decay", 10.0)
	var lp: float = o.get("lp", 1.0)
	var f0: float = o.get("f0", 440.0)
	var f1: float = o.get("f1", f0)
	var wave: String = o.get("wave", "sine")

	var n := int(dur * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	var filtered := 0.0
	for i in n:
		var t := float(i) / RATE
		var k := t / dur
		var freq := lerpf(f0, f1, k)
		phase = fmod(phase + freq / RATE, 1.0)
		var tone := 0.0
		match wave:
			"square":
				tone = 1.0 if phase < 0.5 else -1.0
			"saw":
				tone = phase * 2.0 - 1.0
			_:
				tone = sin(phase * TAU)
		var s := randf_range(-1.0, 1.0) * noise_amt + tone * tone_amt
		filtered += (s - filtered) * lp
		var env := exp(-t * decay) * minf(1.0, t * 400.0)
		var v := clampi(int(filtered * env * 26000.0), -32768, 32767)
		data.encode_s16(i * 2, v)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = data
	return stream
