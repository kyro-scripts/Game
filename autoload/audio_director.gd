extends Node
## Placeholder audio + bus routing (autoload "AudioDirector").
##
## No audio files exist yet, so every placeholder sound is synthesised at
## startup into an AudioStreamWAV. Replace any entry by dropping a real stream
## into `_library` under the same name (or call `register_stream`), and every
## caller keeps working.
##
## Bus layout (created in code so there is no bus-layout file to keep in sync):
##   Master
##   ├─ World      low-pass + reverb; pitch-follows the AUDIO time channel
##   │  └─ Ambience
##   ├─ Player     gun, body, movement (stays crisp during Borrow Time)
##   ├─ Stopwatch  ticking / stopwatch mechanics
##   └─ UI
##
## During Borrow Time the World bus is low-passed and world voices are pitched
## by TimeDirector's AUDIO channel. Nothing is simply muted.

const MIX_RATE := 22050
const MAX_VOICES_PER_SOUND := 6

const BUS_WORLD := &"World"
const BUS_AMBIENCE := &"Ambience"
const BUS_PLAYER := &"Player"
const BUS_STOPWATCH := &"Stopwatch"
const BUS_UI := &"UI"

## Low-pass cutoff when the AUDIO channel is fully slowed.
const BORROW_CUTOFF_HZ := 700.0
const OPEN_CUTOFF_HZ := 20000.0
## AUDIO channel value treated as "fully slowed" for the bus effect.
const BORROW_REFERENCE_SCALE := 0.55

var _library: Dictionary = {}  # StringName -> AudioStream
var _voices: Dictionary = {}  # StringName -> Array[Node]
var _tracked: Array[Dictionary] = []  # {node, base_pitch}
var _world_lowpass: AudioEffectLowPassFilter
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	_build_library()


func _process(_delta: float) -> void:
	var audio_scale := TimeDirector.get_scale(TimeDirector.Channel.AUDIO)
	# World voices follow the AUDIO channel's pitch/tempo.
	var alive: Array[Dictionary] = []
	for entry in _tracked:
		var obj: Variant = entry["node"]
		if not is_instance_valid(obj):
			continue
		var node := obj as Node
		if node.is_inside_tree():
			node.set("pitch_scale", maxf(float(entry["base_pitch"]) * audio_scale, 0.05))
			alive.append(entry)
	_tracked = alive
	# Muffle the world bus proportionally to the slowdown.
	var k := clampf((1.0 - audio_scale) / (1.0 - BORROW_REFERENCE_SCALE), 0.0, 1.0)
	_world_lowpass.cutoff_hz = OPEN_CUTOFF_HZ * pow(BORROW_CUTOFF_HZ / OPEN_CUTOFF_HZ, k)


func _exit_tree() -> void:
	# Stop anything still playing so streams/playbacks are released cleanly.
	for child in get_children():
		if child is AudioStreamPlayer:
			(child as AudioStreamPlayer).stop()
			child.queue_free()
	_tracked.clear()
	_voices.clear()
	_library.clear()


# --- Public API ---------------------------------------------------------------

func has_sound(sound: StringName) -> bool:
	return _library.has(sound)


func register_stream(sound: StringName, stream: AudioStream) -> void:
	_library[sound] = stream


## Play a one-shot. Pass a Vector3 as `at` for a positional sound, or null for
## a flat one. Returns the player node (or null if the sound is missing or the
## per-sound voice cap is hit).
func play(sound: StringName, at: Variant = null, volume_db: float = 0.0, pitch: float = 1.0,
		bus: StringName = BUS_WORLD, pitch_variance: float = 0.04) -> Node:
	var stream: AudioStream = _library.get(sound)
	if stream == null:
		push_warning("AudioDirector: unknown sound '%s'" % sound)
		return null
	var base_pitch := pitch * (1.0 + _rng.randf_range(-pitch_variance, pitch_variance))
	var player := _create_player(stream, at, volume_db, bus)
	if player == null:
		return null
	_claim_voice(sound, player)
	player.connect("finished", player.queue_free)
	_start(player, base_pitch, bus)
	return player


## Start a looping sound. Parent it to `follow` (a Node3D) for positional
## audio, or pass null for a flat loop. The caller owns the returned node and
## should queue_free() it to stop.
func play_loop(sound: StringName, follow: Node3D = null, volume_db: float = 0.0,
		bus: StringName = BUS_WORLD, pitch: float = 1.0) -> Node:
	var stream: AudioStream = _library.get(sound)
	if stream == null:
		push_warning("AudioDirector: unknown loop '%s'" % sound)
		return null
	var player: Node
	if follow != null:
		var p3 := AudioStreamPlayer3D.new()
		p3.stream = stream
		p3.volume_db = volume_db
		p3.bus = bus
		p3.unit_size = 5.0
		p3.max_distance = 60.0
		follow.add_child(p3)
		player = p3
	else:
		var p2 := AudioStreamPlayer.new()
		p2.stream = stream
		p2.volume_db = volume_db
		p2.bus = bus
		add_child(p2)
		player = p2
	_start(player, pitch, bus)
	return player


# --- Internals ----------------------------------------------------------------

func _create_player(stream: AudioStream, at: Variant, volume_db: float, bus: StringName) -> Node:
	if at is Vector3:
		var root := _scene_root()
		var p3 := AudioStreamPlayer3D.new()
		p3.stream = stream
		p3.volume_db = volume_db
		p3.bus = bus
		p3.unit_size = 7.0
		p3.max_distance = 90.0
		root.add_child(p3)
		p3.global_position = at
		return p3
	var p2 := AudioStreamPlayer.new()
	p2.stream = stream
	p2.volume_db = volume_db
	p2.bus = bus
	add_child(p2)
	return p2


func _start(player: Node, base_pitch: float, bus: StringName) -> void:
	var world_bus := bus == BUS_WORLD or bus == BUS_AMBIENCE
	var audio_scale := TimeDirector.get_scale(TimeDirector.Channel.AUDIO) if world_bus else 1.0
	player.set("pitch_scale", maxf(base_pitch * audio_scale, 0.05))
	if world_bus:
		_tracked.append({"node": player, "base_pitch": base_pitch})
	player.call("play")


func _claim_voice(sound: StringName, player: Node) -> void:
	var list: Array = _voices.get(sound, [])
	list = list.filter(func(n: Variant) -> bool: return is_instance_valid(n))
	while list.size() >= MAX_VOICES_PER_SOUND:
		var oldest: Node = list.pop_front()
		oldest.queue_free()
	list.append(player)
	_voices[sound] = list


func _scene_root() -> Node:
	var tree := get_tree()
	if tree.current_scene != null:
		return tree.current_scene
	return tree.root


func _setup_buses() -> void:
	_ensure_bus(BUS_WORLD, &"Master")
	_ensure_bus(BUS_AMBIENCE, BUS_WORLD)
	_ensure_bus(BUS_PLAYER, &"Master")
	_ensure_bus(BUS_STOPWATCH, &"Master")
	_ensure_bus(BUS_UI, &"Master")
	var world_idx := AudioServer.get_bus_index(BUS_WORLD)
	if AudioServer.get_bus_effect_count(world_idx) == 0:
		_world_lowpass = AudioEffectLowPassFilter.new()
		_world_lowpass.cutoff_hz = OPEN_CUTOFF_HZ
		_world_lowpass.resonance = 0.9
		AudioServer.add_bus_effect(world_idx, _world_lowpass)
		var reverb := AudioEffectReverb.new()
		reverb.room_size = 0.78
		reverb.damping = 0.45
		reverb.spread = 0.8
		reverb.wet = 0.16
		reverb.dry = 1.0
		AudioServer.add_bus_effect(world_idx, reverb)
	else:
		_world_lowpass = AudioServer.get_bus_effect(world_idx, 0) as AudioEffectLowPassFilter
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(BUS_AMBIENCE), -6.0)


func _ensure_bus(bus_name: StringName, send: StringName) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, send)


# --- Synthesis ------------------------------------------------------------------
# Small, deterministic generators. These are deliberately crude placeholders;
# their only job is to make timing, feedback and the Borrow Time treatment
# audible until real sound design exists.

func _build_library() -> void:
	_rng.seed = 7741
	_library[&"tick"] = _wav(_click_sound(2900.0, 0.035, 0.5))
	_library[&"tock"] = _wav(_click_sound(2150.0, 0.04, 0.45))
	_library[&"low_time_tick"] = _wav(_click_sound(3600.0, 0.05, 0.85))
	_library[&"debt_tick"] = _wav(_click_sound(1500.0, 0.05, 0.4))
	_library[&"stopwatch_click"] = _wav(_stopwatch_click())
	_library[&"borrow_in"] = _wav(_sweep_tone(0.55, 520.0, 85.0, true))
	_library[&"borrow_out"] = _wav(_sweep_tone(0.38, 90.0, 430.0, false))
	_library[&"time_gain"] = _wav(_time_gain())
	_library[&"gunshot"] = _wav(_gunshot())
	_library[&"door_breach"] = _wav(_door_breach())
	_library[&"door_creak"] = _wav(_door_creak())
	_library[&"enemy_hit"] = _wav(_thud(0.12, 190.0, 40.0, 0.75))
	_library[&"enemy_death"] = _wav(_enemy_death())
	_library[&"enemy_windup"] = _wav(_whisper(0.45, true))
	_library[&"enemy_attack"] = _wav(_whisper(0.22, false))
	_library[&"player_hurt"] = _wav(_player_hurt())
	_library[&"projectile_fire"] = _wav(_projectile_fire())
	_library[&"chime"] = _wav(_bell(196.0, 2.8, 0.8))
	_library[&"footstep"] = _wav(_thud(0.07, 110.0, 60.0, 0.35))
	_library[&"land"] = _wav(_thud(0.16, 78.0, 22.0, 0.7))
	_library[&"jump"] = _wav(_whisper(0.1, false, 0.25))
	_library[&"slide_loop"] = _wav(_friction_loop(), true)
	_library[&"room_tone"] = _wav(_room_tone(), true)
	# Atmosphere: sparse, unexplained, never loud.
	_library[&"distant_tick"] = _wav(_distant_tick())
	_library[&"drone_swell"] = _wav(_drone_swell())
	_library[&"whisper"] = _wav(_whisper_voice())
	_library[&"distant_slam"] = _wav(_distant_slam())
	_library[&"wrong_note"] = _wav(_wrong_note())
	_library[&"breath"] = _wav(_breath())
	_library[&"light_click"] = _wav(_click_sound(900.0, 0.08, 0.7))
	_library[&"guest_cue"] = _wav(_guest_cue())
	_library[&"pressure"] = _wav(_pressure(), true)


func _wav(samples: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = bytes
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = samples.size()
	return stream


func _buffer(seconds: float) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(int(seconds * MIX_RATE))
	return a


func _normalize(a: PackedFloat32Array, peak: float) -> PackedFloat32Array:
	var m := 0.0001
	for v in a:
		m = maxf(m, absf(v))
	var g := peak / m
	for i in a.size():
		a[i] *= g
	return a


## One-pole low-pass coefficient for a cutoff frequency.
func _lp_coeff(cutoff_hz: float) -> float:
	return 1.0 - exp(-TAU * cutoff_hz / MIX_RATE)


func _noise() -> float:
	return _rng.randf_range(-1.0, 1.0)


func _add_click(a: PackedFloat32Array, start: float, freq: float, amp: float) -> void:
	var s := int(start * MIX_RATE)
	var n := int(0.03 * MIX_RATE)
	for j in n:
		var i := s + j
		if i >= a.size():
			break
		var t := float(j) / MIX_RATE
		var env := exp(-t * 160.0)
		a[i] += amp * env * (sin(TAU * freq * t) * 0.6 + sin(TAU * freq * 2.71 * t) * 0.25
				+ _noise() * 0.4 * exp(-t * 700.0))


func _click_sound(freq: float, seconds: float, peak: float) -> PackedFloat32Array:
	var a := _buffer(seconds)
	_add_click(a, 0.0, freq, 1.0)
	return _normalize(a, peak)


func _stopwatch_click() -> PackedFloat32Array:
	var a := _buffer(0.13)
	_add_click(a, 0.0, 3400.0, 1.0)
	_add_click(a, 0.05, 2500.0, 0.7)
	return _normalize(a, 0.7)


func _sweep_tone(seconds: float, f_from: float, f_to: float, swell: bool) -> PackedFloat32Array:
	var a := _buffer(seconds)
	var phase := 0.0
	var lp := 0.0
	var n := a.size()
	for i in n:
		var p := float(i) / n
		var f := lerpf(f_from, f_to, pow(p, 0.6))
		phase += TAU * f / MIX_RATE
		var env: float
		if swell:
			env = smoothstep(0.0, 0.75, p) * (1.0 - smoothstep(0.88, 1.0, p))
		else:
			env = exp(-p * 5.0) * smoothstep(0.0, 0.02, p)
		lp += (_noise() - lp) * _lp_coeff(300.0 + 2500.0 * (p if swell else 1.0 - p))
		a[i] = env * (sin(phase) * 0.55 + sin(phase * 1.5) * 0.18 + lp * 0.6)
	return _normalize(a, 0.75)


func _time_gain() -> PackedFloat32Array:
	var a := _buffer(0.4)
	for i in a.size():
		var t := float(i) / MIX_RATE
		var v := sin(TAU * 1320.0 * t) * exp(-t * 16.0)
		if t > 0.075:
			var t2 := t - 0.075
			v += sin(TAU * 1760.0 * t2) * exp(-t2 * 12.0) * 0.9
		a[i] = v
	return _normalize(a, 0.6)


func _gunshot() -> PackedFloat32Array:
	var a := _buffer(0.5)
	var lp_body := 0.0
	var lp_tail := 0.0
	var phase := 0.0
	for i in a.size():
		var t := float(i) / MIX_RATE
		var n := _noise()
		lp_body += (n - lp_body) * _lp_coeff(1800.0)
		lp_tail += (n - lp_tail) * _lp_coeff(500.0)
		phase += TAU * lerpf(150.0, 52.0, minf(t * 8.0, 1.0)) / MIX_RATE
		var crack := (n - lp_body) * exp(-t * 95.0)
		var body := lp_body * exp(-t * 20.0)
		var thump := sin(phase) * exp(-t * 14.0)
		var tail := lp_tail * exp(-t * 6.0) * 0.5
		a[i] = crack * 0.9 + body * 0.9 + thump * 0.8 + tail
	return _normalize(a, 0.95)


func _door_breach() -> PackedFloat32Array:
	var a := _buffer(1.0)
	var phase := 0.0
	var lp := 0.0
	var bursts: Array[float] = []
	for _k in 7:
		bursts.append(_rng.randf_range(0.0, 0.28))
	for i in a.size():
		var t := float(i) / MIX_RATE
		var n := _noise()
		lp += (n - lp) * _lp_coeff(1100.0)
		phase += TAU * lerpf(72.0, 38.0, minf(t * 3.0, 1.0)) / MIX_RATE
		var v := sin(phase) * exp(-t * 6.5) * 1.1
		for b in bursts:
			if t >= b:
				v += (n - lp) * exp(-(t - b) * 55.0) * 0.55
		v += lp * exp(-t * 3.8) * 0.55 * (0.6 + 0.4 * sin(TAU * 17.0 * t))
		a[i] = v
	return _normalize(a, 0.98)


func _door_creak() -> PackedFloat32Array:
	var a := _buffer(1.35)
	var phase := 0.0
	for i in a.size():
		var t := float(i) / MIX_RATE
		var f := 250.0 + 90.0 * sin(TAU * 1.6 * t) + 35.0 * sin(TAU * 5.3 * t)
		phase += TAU * f / MIX_RATE
		var saw := sin(phase) + 0.5 * sin(phase * 2.0) + 0.33 * sin(phase * 3.0)
		var stick := pow(0.5 + 0.5 * sin(TAU * 23.0 * t), 3.0)
		var env := smoothstep(0.0, 0.1, t) * (1.0 - smoothstep(1.05, 1.35, t))
		a[i] = saw * stick * env + _noise() * 0.05 * env
	return _normalize(a, 0.6)


func _thud(seconds: float, freq: float, decay: float, peak: float) -> PackedFloat32Array:
	var a := _buffer(seconds)
	var lp := 0.0
	var phase := 0.0
	for i in a.size():
		var t := float(i) / MIX_RATE
		lp += (_noise() - lp) * _lp_coeff(900.0)
		phase += TAU * lerpf(freq, freq * 0.5, minf(t / seconds, 1.0)) / MIX_RATE
		a[i] = sin(phase) * exp(-t * decay) + lp * exp(-t * decay * 1.6) * 0.8
	return _normalize(a, peak)


func _enemy_death() -> PackedFloat32Array:
	var a := _buffer(1.2)
	var lp := 0.0
	var lp2 := 0.0
	for i in a.size():
		var t := float(i) / MIX_RATE
		var n := _noise()
		lp += (n - lp) * _lp_coeff(1800.0)
		lp2 += (lp - lp2) * _lp_coeff(300.0)
		var exhale := (lp - lp2) * smoothstep(0.0, 0.06, t) * exp(-t * 3.0)
		var bell := (sin(TAU * 660.0 * t) + 0.5 * sin(TAU * 660.0 * 2.76 * t)
				+ 0.25 * sin(TAU * 660.0 * 5.4 * t)) * exp(-t * 2.6) * 0.12
		a[i] = exhale + bell
	return _normalize(a, 0.65)


func _whisper(seconds: float, rising: bool, peak: float = 0.5) -> PackedFloat32Array:
	var a := _buffer(seconds)
	var lp := 0.0
	var n_samples := a.size()
	for i in n_samples:
		var p := float(i) / n_samples
		var cutoff := lerpf(400.0, 3200.0, p) if rising else lerpf(3000.0, 500.0, p)
		lp += (_noise() - lp) * _lp_coeff(cutoff)
		var env := (p * p) if rising else sin(PI * p)
		a[i] = lp * env
	return _normalize(a, peak)


func _player_hurt() -> PackedFloat32Array:
	var a := _buffer(0.4)
	for i in a.size():
		var t := float(i) / MIX_RATE
		a[i] = sin(TAU * 88.0 * t) * exp(-t * 20.0) + sin(TAU * 1240.0 * t) * exp(-t * 6.0) * 0.22
	return _normalize(a, 0.8)


func _projectile_fire() -> PackedFloat32Array:
	var a := _buffer(0.38)
	var phase := 0.0
	var lp := 0.0
	for i in a.size():
		var t := float(i) / MIX_RATE
		phase += TAU * lerpf(240.0, 120.0, minf(t * 4.0, 1.0)) / MIX_RATE
		lp += (_noise() - lp) * _lp_coeff(700.0)
		a[i] = (sin(phase) + 0.3 * sin(phase * 1.5)) * exp(-t * 9.0) + lp * exp(-t * 12.0) * 0.4
	return _normalize(a, 0.6)


func _bell(f0: float, seconds: float, peak: float) -> PackedFloat32Array:
	var a := _buffer(seconds)
	var ratios := [1.0, 2.0, 2.76, 5.40, 8.93]
	var amps := [1.0, 0.6, 0.45, 0.25, 0.12]
	var decays := [1.1, 1.5, 2.1, 3.4, 5.0]
	for i in a.size():
		var t := float(i) / MIX_RATE
		var v := 0.0
		for k in ratios.size():
			v += sin(TAU * f0 * float(ratios[k]) * t) * float(amps[k]) * exp(-t * float(decays[k]))
		v += _noise() * exp(-t * 300.0) * 0.3
		a[i] = v
	return _normalize(a, peak)


func _friction_loop() -> PackedFloat32Array:
	var a := _buffer(1.0)
	var lp := 0.0
	var lp2 := 0.0
	for i in a.size():
		var n := _noise()
		lp += (n - lp) * _lp_coeff(2200.0)
		lp2 += (lp - lp2) * _lp_coeff(500.0)
		a[i] = (lp - lp2)
	return _normalize(a, 0.4)


func _room_tone() -> PackedFloat32Array:
	# Generate extra samples and crossfade the tail into the head so the loop
	# point is seamless.
	var seconds := 4.0
	var fade := int(0.25 * MIX_RATE)
	var n := int(seconds * MIX_RATE)
	var raw := PackedFloat32Array()
	raw.resize(n + fade)
	var brown := 0.0
	for i in raw.size():
		var t := float(i) / MIX_RATE
		brown = brown * 0.996 + _noise() * 0.04
		raw[i] = brown + sin(TAU * 49.0 * t) * 0.05 + sin(TAU * 98.0 * t) * 0.02
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		if i < fade:
			var w := float(i) / fade
			out[i] = raw[n + i] * (1.0 - w) + raw[i] * w
		else:
			out[i] = raw[i]
	return _normalize(out, 0.35)



# --- Atmosphere synthesis ---------------------------------------------------------------

func _distant_tick() -> PackedFloat32Array:
	# A tick heard through walls: low-passed, with a short hollow tail.
	var a := _buffer(0.25)
	_add_click(a, 0.0, 1700.0, 1.0)
	var lp := 0.0
	for i in a.size():
		lp += (a[i] - lp) * _lp_coeff(1100.0)
		var t := float(i) / MIX_RATE
		a[i] = lp + sin(TAU * 420.0 * t) * exp(-t * 30.0) * 0.08
	return _normalize(a, 0.5)


func _drone_swell() -> PackedFloat32Array:
	# Two sub tones beating against each other, swelling and receding.
	var a := _buffer(6.0)
	var lp := 0.0
	var n := a.size()
	for i in n:
		var t := float(i) / MIX_RATE
		var p := float(i) / n
		var env := sin(PI * p) * sin(PI * p)
		lp += (_noise() - lp) * _lp_coeff(180.0)
		a[i] = env * (sin(TAU * 41.0 * t) * 0.5 + sin(TAU * 43.3 * t) * 0.5 + sin(TAU * 82.6 * t) * 0.15 + lp * 0.6)
	return _normalize(a, 0.6)


func _whisper_voice() -> PackedFloat32Array:
	# Breathy noise pushed through two moving formants: speech without words.
	var a := _buffer(2.2)
	var n := a.size()
	var b1 := 0.0
	var b1l := 0.0
	var b2 := 0.0
	var b2l := 0.0
	for i in n:
		var t := float(i) / MIX_RATE
		var p := float(i) / n
		var noise := _noise()
		var f1 := 600.0 + 300.0 * sin(t * 7.0) + 200.0 * sin(t * 13.0)
		var f2 := 1700.0 + 500.0 * sin(t * 5.0 + 1.0)
		b1 += (noise - b1) * _lp_coeff(f1 * 1.3)
		b1l += (b1 - b1l) * _lp_coeff(f1 * 0.7)
		b2 += (noise - b2) * _lp_coeff(f2 * 1.2)
		b2l += (b2 - b2l) * _lp_coeff(f2 * 0.8)
		var syll := pow(0.5 + 0.5 * sin(t * TAU * 3.1 + sin(t * 4.0)), 2.0)
		var env := smoothstep(0.0, 0.1, p) * (1.0 - smoothstep(0.75, 1.0, p))
		a[i] = ((b1 - b1l) + (b2 - b2l) * 0.7) * syll * env
	return _normalize(a, 0.45)


func _distant_slam() -> PackedFloat32Array:
	# A door somewhere far off: a dull thump and a long, dark tail.
	var a := _buffer(3.0)
	var phase := 0.0
	var lp := 0.0
	for i in a.size():
		var t := float(i) / MIX_RATE
		phase += TAU * lerpf(70.0, 40.0, minf(t * 2.0, 1.0)) / MIX_RATE
		lp += (_noise() - lp) * _lp_coeff(260.0)
		a[i] = sin(phase) * exp(-t * 9.0) + lp * exp(-t * 1.4) * 0.5
	return _normalize(a, 0.55)


func _wrong_note() -> PackedFloat32Array:
	# One piano-ish note, slightly out of tune with itself.
	var a := _buffer(4.5)
	var f := 233.0
	for i in a.size():
		var t := float(i) / MIX_RATE
		var v := sin(TAU * f * t) * exp(-t * 0.9) + sin(TAU * f * 1.012 * t) * exp(-t * 1.1) * 0.8
		v += sin(TAU * f * 2.0 * t) * exp(-t * 1.8) * 0.35 + sin(TAU * f * 3.03 * t) * exp(-t * 2.6) * 0.15
		v += _noise() * exp(-t * 200.0) * 0.2
		a[i] = v
	return _normalize(a, 0.45)


func _breath() -> PackedFloat32Array:
	# A slow inhale and exhale, too close and too even.
	var a := _buffer(3.2)
	var lp := 0.0
	var lp2 := 0.0
	var n := a.size()
	for i in n:
		var p := float(i) / n
		lp += (_noise() - lp) * _lp_coeff(1400.0)
		lp2 += (lp - lp2) * _lp_coeff(350.0)
		var env := pow(sin(PI * clampf(p / 0.45, 0.0, 1.0)), 2.0) * 0.8 + pow(sin(PI * clampf((p - 0.5) / 0.5, 0.0, 1.0)), 2.0)
		a[i] = (lp - lp2) * env
	return _normalize(a, 0.4)


func _guest_cue() -> PackedFloat32Array:
	# A reversed bell swelling out of a sub tone: the Red Death is here.
	var a := _buffer(3.5)
	var n := a.size()
	var bell := _bell(98.0, 3.5, 1.0)
	for i in n:
		var t := float(i) / MIX_RATE
		var rev := bell[n - 1 - i] if n - 1 - i < bell.size() else 0.0
		a[i] = rev * 0.8 + sin(TAU * 36.7 * t) * smoothstep(0.0, 2.5, t) * 0.4
	return _normalize(a, 0.7)


func _pressure() -> PackedFloat32Array:
	# Almost silence: a faint sub pressure with a seamless loop.
	var seconds := 6.0
	var fade := int(0.4 * MIX_RATE)
	var n := int(seconds * MIX_RATE)
	var raw := PackedFloat32Array()
	raw.resize(n + fade)
	var brown := 0.0
	for i in raw.size():
		var t := float(i) / MIX_RATE
		brown = brown * 0.998 + _noise() * 0.02
		raw[i] = brown * 0.6 + sin(TAU * 30.0 * t) * 0.05
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		if i < fade:
			var w := float(i) / fade
			out[i] = raw[n + i] * (1.0 - w) + raw[i] * w
		else:
			out[i] = raw[i]
	return _normalize(out, 0.3)
