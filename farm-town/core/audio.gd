extends Node
## 音效和背景音乐全部用代码合成，没有外部音频文件。

const RATE := 22050

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _music: AudioStreamPlayer
var _music_task := -1
var _music_stream: AudioStreamWAV
var music_on := true
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 12345
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.volume_db = -16.0
	add_child(_music)
	_streams["step"] = _wav(_noise_hit(0.06, 0.22, 70.0, 0.25))
	_streams["hoe"] = _wav(_thud())
	_streams["water"] = _wav(_splash())
	_streams["plant"] = _wav(_sweep(420.0, 760.0, 0.12, 0.35))
	_streams["harvest"] = _wav(_notes([76, 81, 88], 0.07, 0.4))
	_streams["select"] = _wav(_sweep(900.0, 1000.0, 0.035, 0.18))
	_streams["deny"] = _wav(_sweep(200.0, 150.0, 0.11, 0.3))
	_streams["sleep"] = _wav(_notes([72, 76, 79, 84], 0.16, 0.35))
	_music_task = WorkerThreadPool.add_task(_gen_music)


func _process(_delta: float) -> void:
	if _music_task >= 0 and WorkerThreadPool.is_task_completed(_music_task):
		WorkerThreadPool.wait_for_task_completion(_music_task)
		_music_task = -1
		_music.stream = _music_stream
		if music_on:
			_music.play()


func _exit_tree() -> void:
	# 音乐还在后台线程里合成时退出，要等它做完，否则线程会访问已释放的节点
	if _music_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_music_task)
		_music_task = -1


func play(n: String, pitch_var := 0.08, vol_db := 0.0) -> void:
	if not _streams.has(n):
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[n]
	p.pitch_scale = 1.0 + _rng.randf_range(-pitch_var, pitch_var)
	p.volume_db = vol_db
	p.play()


func toggle_music() -> void:
	music_on = not music_on
	if music_on:
		if _music.stream != null:
			_music.play()
	else:
		_music.stop()


func _wav(buf: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(buf.size() * 2)
	for i in buf.size():
		bytes.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = buf.size()
	return w


func _noise_hit(dur: float, vol: float, decay: float, lp: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var s := 0.0
	for i in n:
		var t := float(i) / RATE
		s += (rng.randf_range(-1.0, 1.0) - s) * lp
		buf[i] = s * exp(-t * decay) * vol * 3.0
	return buf


func _thud() -> PackedFloat32Array:
	var n := int(0.18 * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var s := 0.0
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := lerpf(130.0, 55.0, minf(t / 0.1, 1.0))
		ph += f / RATE
		s += (rng.randf_range(-1.0, 1.0) - s) * 0.35
		buf[i] = sin(ph * TAU) * exp(-t * 22.0) * 0.7 + s * exp(-t * 45.0) * 0.6
	return buf


func _splash() -> PackedFloat32Array:
	var n := int(0.5 * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var white := rng.randf_range(-1.0, 1.0)
		lp += (white - lp) * 0.25
		var hp := white - lp
		var env := minf(t / 0.04, 1.0) * exp(-t * 6.0)
		var trem := 0.7 + 0.3 * sin(t * 90.0)
		buf[i] = (hp * 0.35 + lp * 0.25) * env * trem * 0.5
	return buf


func _sweep(f0: float, f1: float, dur: float, vol: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		ph += lerpf(f0, f1, t / dur) / RATE
		var tri := 4.0 * absf(fmod(ph, 1.0) - 0.5) - 1.0
		var env := minf(t / 0.005, 1.0) * (1.0 - t / dur)
		buf[i] = tri * env * vol
	return buf


func _notes(midis: Array, step: float, vol: float) -> PackedFloat32Array:
	var total := step * midis.size() + 0.25
	var buf := PackedFloat32Array()
	buf.resize(int(total * RATE))
	for i in midis.size():
		var m: int = midis[i]
		_note(buf, i * step, m, 0.3, vol, 0, 9.0)
	return buf


func _note(buf: PackedFloat32Array, start: float, midi: int, dur: float, vol: float, kind: int, decay: float) -> void:
	var f := 440.0 * pow(2.0, (midi - 69) / 12.0)
	var s0 := int(start * RATE)
	var n := int(dur * RATE)
	var size := buf.size()
	for i in n:
		var t := float(i) / RATE
		var ph := fmod(t * f, 1.0)
		var w := 0.0
		if kind == 0:
			w = 4.0 * absf(ph - 0.5) - 1.0
		else:
			w = sin(ph * TAU)
		var env := minf(t / 0.008, 1.0) * exp(-t * decay) * minf((dur - t) / 0.03, 1.0)
		buf[(s0 + i) % size] += w * env * vol


func _gen_music() -> void:
	var eighth := 0.3
	var melody := [
		72, 0, 76, 79, 0, 76, 74, 72,
		69, 0, 72, 76, 0, 72, 71, 69,
		65, 0, 69, 72, 0, 77, 76, 72,
		74, 0, 71, 74, 79, 0, 74, 0,
		76, 0, 79, 84, 0, 79, 76, 79,
		81, 0, 76, 72, 0, 76, 81, 0,
		77, 76, 72, 69, 0, 72, 74, 0,
		74, 0, 71, 67, 0, 71, 74, 0,
	]
	var chords := [[48, 60, 64, 67], [45, 57, 60, 64], [41, 57, 60, 65], [43, 55, 59, 62]]
	var buf := PackedFloat32Array()
	buf.resize(int(64 * eighth * RATE))
	for i in 64:
		var m: int = melody[i]
		if m > 0:
			_note(buf, i * eighth, m, 0.7, 0.2, 0, 4.5)
		var ch: Array = chords[(i / 8) % 4]
		var arp: int = ch[1 + [0, 1, 2, 1][i % 4]]
		_note(buf, i * eighth, arp, 0.4, 0.07, 1, 6.0)
		if i % 4 == 0:
			var root: int = ch[0]
			_note(buf, i * eighth, root, 1.1, 0.2, 1, 2.0)
	_music_stream = _wav(buf, true)
