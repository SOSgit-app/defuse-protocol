extends Node
## Procedural SFX — no audio files required.

var _players: Array[AudioStreamPlayer] = []
var _morse: AudioStreamPlayer
var _morse_on: bool = false


func _ready() -> void:
	for i in 6:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)
	_morse = AudioStreamPlayer.new()
	_morse.bus = "Master"
	add_child(_morse)
	_morse.stream = _tone_loop(700.0, 0.08)


func click() -> void:
	_play(_tone(1200.0, 0.04, 0.08))


func strike() -> void:
	_play(_tone(180.0, 0.18, 0.2, -80.0))
	_play(_noise(0.25, 0.15), 0.02)


func solve() -> void:
	_play(_tone(523.0, 0.08, 0.1))
	_play(_tone(784.0, 0.12, 0.1), 0.08)


func win() -> void:
	_play(_tone(523.0, 0.12, 0.12))
	_play(_tone(659.0, 0.12, 0.12), 0.1)
	_play(_tone(784.0, 0.2, 0.14), 0.2)


func lose() -> void:
	_play(_noise(0.55, 0.25))
	_play(_tone(110.0, 0.5, 0.18, -40.0))


func tick_low() -> void:
	_play(_tone(880.0, 0.03, 0.05))


func squish() -> void:
	_play(_noise(0.2, 0.2))
	_play(_tone(90.0, 0.15, 0.12, -30.0))


func morse_tone(on: bool) -> void:
	if on == _morse_on:
		return
	_morse_on = on
	if on:
		if not _morse.playing:
			_morse.play()
	else:
		_morse.stop()


func fan_hum(on: bool) -> void:
	if on:
		_play(_tone(95.0, 0.35, 0.06))
		_play(_noise(0.35, 0.05))


func _play(stream: AudioStream, delay: float = 0.0) -> void:
	var player: AudioStreamPlayer = null
	for p in _players:
		if not p.playing:
			player = p
			break
	if player == null:
		player = _players[0]
	var target := player
	if delay > 0.0:
		get_tree().create_timer(delay).timeout.connect(func():
			target.stream = stream
			target.play()
		)
	else:
		target.stream = stream
		target.play()


func _tone(freq: float, dur: float, vol: float = 0.1, slide: float = 0.0) -> AudioStreamWAV:
	var rate := 22050
	var frames := maxi(1, int(rate * dur))
	var data := PackedByteArray()
	data.resize(frames * 2)
	for i in frames:
		var t := float(i) / float(rate)
		var env := 1.0 - float(i) / float(frames)
		var f := freq + slide * (float(i) / float(frames))
		var sample := int(sin(t * f * TAU) * 32767.0 * vol * env)
		data.encode_s16(i * 2, sample)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	return stream


func _tone_loop(freq: float, vol: float = 0.08) -> AudioStreamWAV:
	var rate := 22050
	var frames := rate # 1s loop
	var data := PackedByteArray()
	data.resize(frames * 2)
	for i in frames:
		var t := float(i) / float(rate)
		var sample := int(sin(t * freq * TAU) * 32767.0 * vol)
		data.encode_s16(i * 2, sample)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = frames
	stream.data = data
	return stream


func _noise(dur: float, vol: float = 0.15) -> AudioStreamWAV:
	var rate := 22050
	var frames := maxi(1, int(rate * dur))
	var data := PackedByteArray()
	data.resize(frames * 2)
	for i in frames:
		var env := 1.0 - float(i) / float(frames)
		var sample := int((randf() * 2.0 - 1.0) * 32767.0 * vol * env)
		data.encode_s16(i * 2, sample)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	return stream
