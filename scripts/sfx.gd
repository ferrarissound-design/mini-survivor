extends Node
## 効果音をコードで生成 (外部アセット不要)。

const RATE := 22050
var streams := {}
var players: Array = []
var last := {}
var enabled := true

func _ready() -> void:
	streams["shoot"] = _tone(950.0, 520.0, 0.07, 0.10, 0)
	streams["knife"] = _tone(1600.0, 1100.0, 0.05, 0.06, 2)
	streams["hit"] = _tone(260.0, 140.0, 0.04, 0.10, 2)
	streams["kill"] = _tone(420.0, 90.0, 0.09, 0.12, 0)
	streams["pickup"] = _tone(1250.0, 1900.0, 0.06, 0.08, 1)
	streams["hurt"] = _tone(200.0, 90.0, 0.16, 0.18, 3)
	streams["levelup"] = _arp([523.0, 659.0, 784.0, 1046.0], 0.07, 0.14)
	streams["start"] = _arp([392.0, 523.0, 784.0], 0.08, 0.14)
	streams["click"] = _tone(700.0, 900.0, 0.04, 0.10, 1)
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)

func play(name: String, gap := 0.05) -> void:
	if not enabled or not streams.has(name):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(last.get(name, -10.0)) < gap:
		return
	last[name] = now
	for p in players:
		if not p.playing:
			p.stream = streams[name]
			p.play()
			return

func _wave(kind: int, ph: float) -> float:
	match kind:
		0: return 1.0 if fmod(ph, 1.0) < 0.5 else -1.0
		1: return sin(ph * TAU)
		2: return randf_range(-1.0, 1.0)
		_: return fmod(ph, 1.0) * 2.0 - 1.0

func _make(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	return s

func _tone(f0: float, f1: float, dur: float, vol: float, kind: int) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	for i in n:
		var k := float(i) / n
		ph += lerpf(f0, f1, k) / RATE
		var env := minf(1.0, i / (0.004 * RATE)) * pow(1.0 - k, 2.0)
		out[i] = _wave(kind, ph) * vol * env
	return _make(out)

func _arp(freqs: Array, note: float, vol: float) -> AudioStreamWAV:
	var out := PackedFloat32Array()
	var per := int(note * RATE)
	out.resize(per * freqs.size() + per * 2)
	var ph := 0.0
	for j in freqs.size():
		for i in per * (3 if j == freqs.size() - 1 else 1):
			var idx := j * per + i
			if idx >= out.size():
				break
			ph += float(freqs[j]) / RATE
			var k := float(i) / (per * (3 if j == freqs.size() - 1 else 1))
			out[idx] = (sin(ph * TAU) * 0.6 + (1.0 if fmod(ph, 1.0) < 0.5 else -1.0) * 0.25) * vol * (1.0 - k)
	return _make(out)
