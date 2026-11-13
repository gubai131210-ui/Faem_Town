extends Node
## 音效和背景音乐全部用代码合成。唯一的音频文件是收音机播报的人声（audio/radio/），
## 由 tools/radio_voice.py 用语音合成生成；收音机的失真和沙沙声在这里加。

const RATE := 22050
const RADIO_DIR := "res://audio/radio/"
const RADIO_BUS := &"Radio"

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _music: AudioStreamPlayer
var _music_task := -1
var _music_stream: AudioStreamWAV
var music_on := true
var _rng := RandomNumberGenerator.new()
var _radio: AudioStreamPlayer
var _radio_static: AudioStreamPlayer
var _radio_queue: Array[AudioStream] = []
var _radio_fade: Tween
## 正在退出：不再放任何新的声音
var muted := false


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
	# 井里：挥武器、打中、被壳弹开、挨打、翻滚
	_streams["swing"] = _wav(_sweep(520.0, 260.0, 0.09, 0.22))
	_streams["hit"] = _wav(_noise_hit(0.09, 0.4, 45.0, 0.3))
	_streams["clang"] = _wav(_notes([96, 91], 0.04, 0.3))
	_streams["hurt"] = _wav(_sweep(320.0, 130.0, 0.18, 0.35))
	_streams["roll"] = _wav(_noise_hit(0.16, 0.22, 18.0, 0.12))
	# 井里深处：苔蛙落地一声闷的，矿车撞墙一声带铁响的，吐水“噗”一声，大鱼出水、入水一大片水声
	_streams["thump"] = _wav(_mix(_noise_hit(0.14, 0.3, 28.0, 0.1), _sweep(110.0, 60.0, 0.12, 0.3)))
	_streams["crash"] = _wav(_mix(_mix(_noise_hit(0.4, 0.42, 9.0, 0.45), _sweep(170.0, 55.0, 0.3, 0.4)), _notes([62, 69], 0.03, 0.22)))
	_streams["spit"] = _wav(_mix(_sweep(380.0, 760.0, 0.07, 0.22), _noise_hit(0.07, 0.15, 50.0, 0.5)))
	_streams["plunge"] = _wav(_mix(_splash(), _sweep(150.0, 60.0, 0.28, 0.35)))
	_streams["sleep"] = _wav(_notes([72, 76, 79, 84], 0.16, 0.35))
	_streams["radio_tune"] = _wav(_radio_tune())
	# 钓鱼：甩竿是一声短促的风声接落水，咬钩两个高音，挣扎一下闷响，断线一声脆响
	_streams["cast"] = _wav(_cast())
	_streams["bite"] = _wav(_notes([88, 93], 0.06, 0.35))
	_streams["struggle"] = _wav(_noise_hit(0.09, 0.3, 40.0, 0.12))
	_streams["snap"] = _wav(_noise_hit(0.05, 0.4, 120.0, 0.7))
	# 动物：鸡两声短的，鸭一声扁的，羊一声颤的，牛一声低的
	_streams["cluck"] = _wav(_calls([[720.0, 480.0, 0.05], [760.0, 520.0, 0.06]], 0.3))
	_streams["quack"] = _wav(_calls([[420.0, 330.0, 0.11], [400.0, 300.0, 0.13]], 0.32))
	_streams["bleat"] = _wav(_calls([[520.0, 470.0, 0.09], [500.0, 450.0, 0.09], [480.0, 400.0, 0.14]], 0.28))
	_streams["moo"] = _wav(_calls([[150.0, 185.0, 0.25], [185.0, 130.0, 0.4]], 0.34))
	_streams["bark"] = _wav(_calls([[300.0, 210.0, 0.07], [320.0, 200.0, 0.09]], 0.34))
	_streams["meow"] = _wav(_calls([[620.0, 780.0, 0.12], [780.0, 540.0, 0.22]], 0.22))
	_streams["caw"] = _wav(_calls([[540.0, 430.0, 0.12], [520.0, 400.0, 0.15]], 0.3))
	_setup_radio()
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
	silence()


## 所有声音立刻停下。退出游戏前调一次：还在播的声音会让引擎在退出时报“对象未释放”。
func silence() -> void:
	for p in _players:
		p.stop()
	_music.stop()
	if _radio_fade != null:
		_radio_fade.kill()
	_radio_queue.clear()
	_radio.stop()
	_radio_static.stop()


## 停掉声音，等声音线程放手，再退出。code 是进程的退出码。
## 等的是真实时间而不是帧数：无窗口运行时一帧几乎不占时间，等两帧声音线程来不及放手。
func quit_game(code: int = 0) -> void:
	music_on = false
	muted = true
	silence()
	await get_tree().create_timer(0.2, true, false, true).timeout
	silence()
	get_tree().quit(code)


func play(n: String, pitch_var := 0.08, vol_db := 0.0) -> void:
	if muted or not _streams.has(n):
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[n]
	p.pitch_scale = 1.0 + _rng.randf_range(-pitch_var, pitch_var)
	p.volume_db = vol_db
	p.play()


## 收音机播报：先是一声调台的啸叫，然后依次念出各段人声，底下一直有沙沙声。
## clips 是 audio/radio/ 下的文件名（不带扩展名）；缺的那段直接跳过。
func play_radio(clips: PackedStringArray) -> void:
	stop_radio()
	if muted:
		return
	_radio_queue.append(_streams["radio_tune"])
	for clip in clips:
		var path := RADIO_DIR + clip + ".wav"
		if ResourceLoader.exists(path):
			var stream := load(path) as AudioStream
			if stream != null:
				_radio_queue.append(stream)
	_radio_static.volume_db = -20.0
	_radio_static.play()
	_radio_next()


func stop_radio() -> void:
	if _radio_fade != null:
		_radio_fade.kill()
		_radio_fade = null
	_radio_queue.clear()
	_radio.stop()
	_radio_static.stop()


func is_radio_playing() -> bool:
	return _radio.playing or _radio_static.playing


func _setup_radio() -> void:
	# 收音机专用的混音总线：削掉低频和高频，再加一点过载，听起来像小喇叭
	if AudioServer.get_bus_index(RADIO_BUS) < 0:
		var idx := AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, RADIO_BUS)
		var high_pass := AudioEffectHighPassFilter.new()
		high_pass.cutoff_hz = 420.0
		AudioServer.add_bus_effect(idx, high_pass)
		var low_pass := AudioEffectLowPassFilter.new()
		low_pass.cutoff_hz = 3000.0
		AudioServer.add_bus_effect(idx, low_pass)
		var drive := AudioEffectDistortion.new()
		drive.mode = AudioEffectDistortion.MODE_OVERDRIVE
		drive.drive = 0.3
		drive.post_gain = -3.0
		AudioServer.add_bus_effect(idx, drive)
	_radio = AudioStreamPlayer.new()
	_radio.bus = RADIO_BUS
	_radio.volume_db = -5.0
	_radio.finished.connect(_radio_next)
	add_child(_radio)
	_radio_static = AudioStreamPlayer.new()
	_radio_static.bus = RADIO_BUS
	_radio_static.stream = _wav(_radio_hiss(), true)
	add_child(_radio_static)


func _radio_next() -> void:
	if _radio_queue.is_empty():
		# 念完以后沙沙声再响一小会儿，慢慢关掉
		if _radio_static.playing:
			_radio_fade = create_tween()
			_radio_fade.tween_interval(0.25)
			_radio_fade.tween_property(_radio_static, "volume_db", -50.0, 0.5)
			_radio_fade.tween_callback(_radio_static.stop)
		return
	_radio.stream = _radio_queue.pop_front()
	_radio.pitch_scale = 1.0
	_radio.play()


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


## 有没有叫这个名字的声音。
func has_sound(n: String) -> bool:
	return _streams.has(n)


## 两段声音叠在一起，长度按长的那段。
func _mix(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	buf.resize(maxi(a.size(), b.size()))
	for i in buf.size():
		buf[i] = (a[i] if i < a.size() else 0.0) + (b[i] if i < b.size() else 0.0)
	return buf


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


## 甩竿：一声由高到低的风声，接一小声落水。
func _cast() -> PackedFloat32Array:
	var swish := _sweep(1400.0, 500.0, 0.14, 0.18)
	var plop := _splash()
	var n := swish.size() + int(0.06 * RATE) + plop.size() / 2
	var buf := PackedFloat32Array()
	buf.resize(n)
	for i in swish.size():
		buf[i] = swish[i]
	var start := swish.size() + int(0.06 * RATE)
	for i in plop.size() / 2:
		buf[start + i] += plop[i] * 0.8
	return buf


## 收音机的底噪：嘶嘶声加上零星的噼啪声，循环播放。
func _radio_hiss() -> PackedFloat32Array:
	var n := int(1.7 * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var lp := 0.0
	var crackle := 0.0
	for i in n:
		var t := float(i) / RATE
		var white := rng.randf_range(-1.0, 1.0)
		lp += (white - lp) * 0.5
		if rng.randf() < 0.0012:
			crackle = rng.randf_range(0.5, 1.0) * (1.0 if rng.randf() < 0.5 else -1.0)
		crackle *= 0.72
		var wobble := 0.75 + 0.25 * sin(t * TAU * 2.0 / 1.7)
		buf[i] = lp * 0.5 * wobble + crackle * 0.6
	return buf


## 调台时的那一声：音高滑动的啸叫混着噪声。
func _radio_tune() -> PackedFloat32Array:
	var dur := 0.45
	var n := int(dur * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 43
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		var k := t / dur
		ph += (2400.0 - 1500.0 * k + 300.0 * sin(t * 40.0)) / RATE
		var env := minf(t / 0.02, 1.0) * (1.0 - k)
		buf[i] = (sin(ph * TAU) * 0.3 + rng.randf_range(-1.0, 1.0) * 0.35) * env
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


## 几段滑音接在一起：calls 里每段是 [起始频率, 结束频率, 时长]。
func _calls(calls: Array, vol: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for c: Array in calls:
		out.append_array(_sweep(c[0], c[1], c[2], vol))
	return out


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
