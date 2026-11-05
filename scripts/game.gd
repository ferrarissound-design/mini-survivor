extends Node2D
## ゲーム世界: 敵・弾・経験値・エフェクトをデータ指向で管理し、1つの _draw でまとめて描画する。

signal died
signal won

const WIN_TIME := 600.0
const MAX_ENEMIES := 420
const MAX_GEMS := 320
const MAX_PARTICLES := 360
const MAX_NUMS := 70
const CELL := 64.0
const PLAYER_R := 14.0
const ZOOM := 1.15
const FONT := preload("res://fonts/NotoSansJP-Bold-subset.otf")

class Enemy:
	var pos := Vector2.ZERO
	var push := Vector2.ZERO
	var hp := 1.0
	var max_hp := 1.0
	var type := 0
	var r := 10.0
	var speed := 60.0
	var dmg := 10.0
	var xp := 1
	var flash := 0.0
	var blade_cd := 0.0
	var phase := 0.0
	var dead := false

class Proj:
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var dmg := 10.0
	var pierce := 0
	var life := 1.0
	var kind := 0 # 0 魔法弾, 1 ナイフ
	var r := 6.0
	var hits := []

class Gem:
	var pos := Vector2.ZERO
	var value := 1
	var kind := 0 # 0 経験値, 1 回復
	var magnet := false
	var spd := 0.0
	var dead := false

class Particle:
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var life := 0.5
	var max_life := 0.5
	var col := Color.WHITE
	var size := 3.0

class DmgNum:
	var pos := Vector2.ZERO
	var text := ""
	var life := 0.6
	var col := Color.WHITE

var ETYPES := [
	{"name": "スライム", "hp": 10.0, "speed": 86.0, "dmg": 10.0, "r": 13.0, "xp": 1, "col": Color("63d471"), "out": Color("1d4d27")},
	{"name": "コウモリ", "hp": 6.0, "speed": 150.0, "dmg": 7.0, "r": 10.0, "xp": 1, "col": Color("b48cff"), "out": Color("3b2470")},
	{"name": "ゴーレム", "hp": 50.0, "speed": 56.0, "dmg": 18.0, "r": 21.0, "xp": 5, "col": Color("b5a993"), "out": Color("4a4236")},
	{"name": "オーガ", "hp": 700.0, "speed": 62.0, "dmg": 30.0, "r": 34.0, "xp": 40, "col": Color("ff6f5e"), "out": Color("6b1a12")},
]

const WEAPONS := ["bolt", "blade", "aura", "knife"]
var WNAME := {"bolt": "魔法弾", "blade": "回転ブレード", "aura": "聖なるオーラ", "knife": "貫通ナイフ"}
var WCOL := {"bolt": Color("57d5ff"), "blade": Color("ffb347"), "aura": Color("ffe066"), "knife": Color("dfe6ee")}
var WDESC := {
	"bolt": ["最も近い敵に魔法弾を自動発射", "ダメージ +4・連射アップ", "弾数 +1", "敵を1体貫通する", "弾数 +1・ダメージ +4"],
	"blade": ["自分の周りを回る刃 2本", "ダメージ +6", "刃 +1本", "刃 +1本・回転半径アップ", "刃 +1本・回転速度アップ"],
	"aura": ["周囲の敵に継続ダメージ", "範囲アップ", "ダメージ +4", "範囲アップ・押し返し強化", "ダメージ +5・範囲アップ"],
	"knife": ["移動方向へ貫通ナイフを投げる", "本数 +1", "ダメージ +5・貫通 +1", "本数 +1", "本数 +1・連射アップ"],
}
var PASSIVES := {
	"speed": {"name": "移動速度", "desc": "移動速度 +10%", "col": Color("7cf0b0"), "max": 5},
	"maxhp": {"name": "最大HP", "desc": "最大HP +20・HPを20回復", "col": Color("ff7a8a"), "max": 5},
	"magnet": {"name": "回収範囲", "desc": "経験値を拾う範囲 +40%", "col": Color("6ab8ff"), "max": 4},
	"might": {"name": "攻撃力", "desc": "すべての攻撃ダメージ +15%", "col": Color("ff9f43"), "max": 5},
	"haste": {"name": "クールダウン", "desc": "攻撃の間隔 -8%", "col": Color("c792ff"), "max": 5},
	"regen": {"name": "再生", "desc": "毎秒HPが 0.6 回復", "col": Color("9be564"), "max": 3},
}

var sfx = null
var camera: Camera2D
var move_input := Vector2.ZERO
var show_player := true

var t := 0.0
var kills := 0
var level := 1
var xp := 0
var pending_levelups := 0
var finished := false
var ppos := Vector2.ZERO
var php := 100.0
var facing := Vector2.RIGHT
var walk_phase := 0.0
var moving := false
var hurt_flash := 0.0
var shake := 0.0
var wlv := {}
var wt := {}
var plv := {}
var blade_angle := 0.0
var aura_pulse := 0.0
var spawn_acc := 0.0
var next_wave := 60.0
var next_boss := 180.0
var announce_text := ""
var announce_t := 0.0

var enemies: Array = []
var projs: Array = []
var gems: Array = []
var particles: Array = []
var nums: Array = []
var grid := {}
var _oct := PackedVector2Array()

func _ready() -> void:
	camera = Camera2D.new()
	camera.zoom = Vector2(ZOOM, ZOOM)
	add_child(camera)
	for i in 8:
		_oct.append(Vector2.from_angle(TAU * i / 8.0 + PI / 8.0))
	reset()

func reset() -> void:
	t = 0.0
	kills = 0
	level = 1
	xp = 0
	pending_levelups = 0
	finished = false
	ppos = Vector2.ZERO
	facing = Vector2.RIGHT
	hurt_flash = 0.0
	shake = 0.0
	wlv = {"bolt": 1, "blade": 0, "aura": 0, "knife": 0}
	wt = {"bolt": 0.4, "knife": 0.0, "aura": 0.0}
	plv = {}
	for k in PASSIVES:
		plv[k] = 0
	php = max_hp()
	enemies.clear()
	projs.clear()
	gems.clear()
	particles.clear()
	nums.clear()
	grid.clear()
	spawn_acc = 0.0
	next_wave = 60.0
	next_boss = 180.0
	announce_text = ""
	announce_t = 0.0
	blade_angle = 0.0
	move_input = Vector2.ZERO

func set_time(v: float) -> void:
	t = v
	next_wave = (floor(t / 60.0) + 1.0) * 60.0
	next_boss = 180.0 if t < 180.0 else 180.0 + (floor((t - 180.0) / 120.0) + 1.0) * 120.0

# ---- ステータス ----
func max_hp() -> float: return 100.0 + 20.0 * plv["maxhp"]
func move_speed() -> float: return 165.0 * (1.0 + 0.1 * plv["speed"])
func pickup_r() -> float: return 70.0 * (1.0 + 0.4 * plv["magnet"])
func might() -> float: return 1.0 + 0.15 * plv["might"]
func haste() -> float: return 1.0 - 0.08 * plv["haste"]
func regen() -> float: return 0.6 * plv["regen"]
func xp_need() -> int: return 5 + (level - 1) * 4 + int(pow(level - 1, 1.5))

func announce(text: String) -> void:
	announce_text = text
	announce_t = 2.5

func _snd(name: String, gap := 0.05) -> void:
	if sfx:
		sfx.play(name, gap)

# ---- レベルアップ選択肢 ----
func roll_choices(n := 3) -> Array:
	var pool := []
	for w in WEAPONS:
		var lv: int = wlv[w]
		if lv < 5:
			pool.append({"id": "w:" + w, "title": WNAME[w] + ("" if lv == 0 else "  Lv.%d" % (lv + 1)),
				"desc": WDESC[w][lv], "new": lv == 0, "col": WCOL[w], "icon": w})
	for p in PASSIVES:
		var lv: int = plv[p]
		if lv < PASSIVES[p]["max"]:
			pool.append({"id": "p:" + p, "title": PASSIVES[p]["name"] + "  Lv.%d" % (lv + 1),
				"desc": PASSIVES[p]["desc"], "new": false, "col": PASSIVES[p]["col"], "icon": p})
	pool.shuffle()
	var res := pool.slice(0, n)
	while res.size() < n:
		res.append({"id": "heal", "title": "回復", "desc": "HPを40回復", "new": false, "col": Color("ff7a8a"), "icon": "heal"})
	return res

func apply_id(id: String) -> void:
	if id == "heal":
		php = minf(max_hp(), php + 40.0)
		return
	var parts := id.split(":")
	if parts[0] == "w":
		wlv[parts[1]] = mini(5, int(wlv[parts[1]]) + 1)
	else:
		plv[parts[1]] += 1
		if parts[1] == "maxhp":
			php = minf(max_hp(), php + 20.0)

# ---- メインループ ----
func _process(delta: float) -> void:
	_update_fx(delta)
	var off := Vector2.ZERO
	if shake > 0.0:
		off = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake
		shake = maxf(0.0, shake - delta * 25.0)
	camera.position = ppos + off
	if announce_t > 0.0:
		announce_t -= delta
	queue_redraw()

func step(delta: float) -> void:
	if finished:
		return
	t += delta
	if t >= WIN_TIME:
		finished = true
		won.emit()
		return
	_update_player(delta)
	_spawn(delta)
	_build_grid()
	_update_enemies(delta)
	if finished:
		return
	_update_weapons(delta)
	_update_projs(delta)
	_update_gems(delta)
	_cleanup()

func _update_player(delta: float) -> void:
	var mv := move_input
	if mv.length() > 1.0:
		mv = mv.normalized()
	ppos += mv * move_speed() * delta
	moving = mv.length() > 0.1
	if moving:
		facing = mv.normalized()
		walk_phase += delta * 12.0
	php = minf(max_hp(), php + regen() * delta)
	hurt_flash = maxf(0.0, hurt_flash - delta)

func _ring_r() -> float:
	return get_viewport_rect().size.length() * 0.5 / ZOOM + 60.0

func _pick_type() -> int:
	var r := randf()
	var bat_w: float = clamp((t - 30.0) / 200.0, 0.0, 0.4)
	var golem_w: float = clamp((t - 90.0) / 300.0, 0.0, 0.3)
	if r < golem_w:
		return 2
	if r < golem_w + bat_w:
		return 1
	return 0

func spawn_enemy(type: int, pos: Vector2) -> void:
	if enemies.size() >= MAX_ENEMIES:
		return
	var d: Dictionary = ETYPES[type]
	var e := Enemy.new()
	e.type = type
	e.pos = pos
	var scale := 1.0 + t / 240.0 + pow(t / 400.0, 2.0)
	e.max_hp = d["hp"] * scale
	e.hp = e.max_hp
	e.speed = d["speed"] * randf_range(0.9, 1.1) * (1.0 + minf(t, 600.0) / 1500.0)
	e.dmg = d["dmg"] * (1.0 + t / 600.0)
	e.r = d["r"]
	e.xp = d["xp"]
	e.phase = randf() * TAU
	enemies.append(e)

func _spawn(delta: float) -> void:
	var rate := 1.6 + t * 0.06 + pow(t / 60.0, 2.0) * 0.12
	spawn_acc += delta * rate
	var rr := _ring_r()
	while spawn_acc >= 1.0:
		spawn_acc -= 1.0
		spawn_enemy(_pick_type(), ppos + Vector2.from_angle(randf() * TAU) * rr)
	if t >= next_wave:
		next_wave += 60.0
		var n := 16 + int(t / 60.0) * 4
		for i in n:
			var ty := 1 if (t > 120.0 and i % 2 == 0) else 0
			spawn_enemy(ty, ppos + Vector2.from_angle(TAU * i / n) * (rr - 20.0))
		announce("大群が来る！")
	if t >= next_boss:
		next_boss += 120.0
		spawn_enemy(3, ppos + Vector2.from_angle(randf() * TAU) * rr)
		announce("強敵 オーガ 出現！")

func _cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / CELL), floori(p.y / CELL))

func _build_grid() -> void:
	grid.clear()
	for e in enemies:
		var k := _cell(e.pos)
		var arr = grid.get(k)
		if arr == null:
			grid[k] = [e]
		else:
			arr.append(e)

func _update_enemies(delta: float) -> void:
	var contact := 0.0
	var rr := _ring_r()
	for e in enemies:
		e.flash -= delta
		e.blade_cd -= delta
		e.phase += delta
		var to: Vector2 = ppos - e.pos
		var d := to.length()
		if d > rr + 320.0:
			e.pos = ppos + (to / d) * rr
			continue
		var dir := to / maxf(d, 0.001)
		e.pos += (dir * e.speed + e.push) * delta
		e.push = e.push.lerp(Vector2.ZERO, minf(1.0, 7.0 * delta))
		# 分離 (近傍セルのみ、最大10体)
		var k := _cell(e.pos)
		var sep := Vector2.ZERO
		var cnt := 0
		for dx in range(-1, 2):
			if cnt > 10:
				break
			for dy in range(-1, 2):
				var arr = grid.get(k + Vector2i(dx, dy))
				if arr == null:
					continue
				for o in arr:
					if o == e:
						continue
					var dv: Vector2 = e.pos - o.pos
					var dd := dv.length_squared()
					var minr: float = e.r + o.r
					if dd < minr * minr and dd > 0.01:
						var dl := sqrt(dd)
						sep += dv / dl * (minr - dl)
					cnt += 1
					if cnt > 10:
						break
		e.pos += sep * 0.35
		if d < e.r + PLAYER_R:
			contact += e.dmg
	if contact > 0.0:
		php -= minf(contact, 45.0) * delta
		if hurt_flash <= 0.05:
			_snd("hurt", 0.25)
		hurt_flash = 0.15
		shake = maxf(shake, 4.0)
		if php <= 0.0:
			php = 0.0
			finished = true
			_burst(ppos, Color("4a90e2"), 24, 260.0)
			died.emit()

func _nearest(n: int, maxd: float) -> Array:
	var best := []
	var bestd := []
	var m2 := maxd * maxd
	for e in enemies:
		if e.dead:
			continue
		var d2: float = ppos.distance_squared_to(e.pos)
		if d2 > m2:
			continue
		var i := bestd.size()
		while i > 0 and bestd[i - 1] > d2:
			i -= 1
		if i < n:
			best.insert(i, e)
			bestd.insert(i, d2)
			if best.size() > n:
				best.pop_back()
				bestd.pop_back()
	return best

func _fire(kind: int, dir: Vector2, speed: float, dmg: float, pierce: int, life: float) -> void:
	var p := Proj.new()
	p.kind = kind
	p.pos = ppos + dir * 10.0
	p.vel = dir * speed
	p.dmg = dmg
	p.pierce = pierce
	p.life = life
	p.r = 7.0 if kind == 0 else 6.0
	projs.append(p)

func blade_stats() -> Dictionary:
	var lv: int = wlv["blade"]
	return {"n": [0, 2, 2, 3, 4, 5][lv], "dmg": 12.0 + 6.0 * int(lv >= 2), "radius": 74.0 + 16.0 * int(lv >= 4),
		"spd": 3.0 + 1.3 * int(lv >= 5)}

func aura_radius() -> float:
	var lv: int = wlv["aura"]
	return 62.0 + 14.0 * int(lv >= 2) + 14.0 * int(lv >= 4) + 12.0 * int(lv >= 5)

func _update_weapons(delta: float) -> void:
	var h := haste()
	# 魔法弾
	var lv: int = wlv["bolt"]
	if lv > 0:
		wt["bolt"] -= delta
		if wt["bolt"] <= 0.0:
			var count := 1 + int(lv >= 3) + int(lv >= 5)
			var targets := _nearest(count, 560.0)
			if targets.is_empty():
				wt["bolt"] = 0.1
			else:
				wt["bolt"] = (0.75 if lv < 2 else 0.6) * h
				var dmg := 12.0 + 4.0 * int(lv >= 2) + 4.0 * int(lv >= 5)
				for i in count:
					var tg = targets[i % targets.size()]
					var dir: Vector2 = (tg.pos - ppos).normalized()
					if i >= targets.size():
						dir = dir.rotated(0.18 * (i - targets.size() + 1))
					_fire(0, dir, 480.0, dmg, int(lv >= 4), 1.4)
				_snd("shoot", 0.08)
	# 貫通ナイフ
	lv = wlv["knife"]
	if lv > 0:
		wt["knife"] -= delta
		if wt["knife"] <= 0.0:
			wt["knife"] = (0.9 if lv < 5 else 0.65) * h
			var count := 1 + int(lv >= 2) + int(lv >= 4) + int(lv >= 5)
			for i in count:
				var dir := facing.rotated((i - (count - 1) / 2.0) * 0.16)
				_fire(1, dir, 680.0, 14.0 + 5.0 * int(lv >= 3), 2 + int(lv >= 3), 0.9)
			_snd("knife", 0.08)
	# 回転ブレード
	lv = wlv["blade"]
	if lv > 0:
		var bs := blade_stats()
		blade_angle += bs["spd"] * delta
		var n: int = bs["n"]
		for i in n:
			var bp: Vector2 = ppos + Vector2.from_angle(blade_angle + TAU * i / n) * bs["radius"]
			var k := _cell(bp)
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					var arr = grid.get(k + Vector2i(dx, dy))
					if arr == null:
						continue
					for e in arr:
						if e.dead or e.blade_cd > 0.0:
							continue
						if bp.distance_squared_to(e.pos) < pow(e.r + 13.0, 2):
							e.blade_cd = 0.4
							hit_enemy(e, bs["dmg"], (e.pos - ppos).normalized(), 90.0)
	# 聖なるオーラ
	lv = wlv["aura"]
	aura_pulse = maxf(0.0, aura_pulse - delta * 2.5)
	if lv > 0:
		wt["aura"] -= delta
		if wt["aura"] <= 0.0:
			wt["aura"] = 0.5 * h
			aura_pulse = 1.0
			var ar := aura_radius()
			var dmg := 7.0 + 4.0 * int(lv >= 3) + 5.0 * int(lv >= 5)
			var kb := 40.0 if lv >= 4 else 18.0
			for e in enemies:
				if e.dead:
					continue
				var dv: Vector2 = e.pos - ppos
				if dv.length_squared() < pow(ar + e.r, 2):
					hit_enemy(e, dmg, dv.normalized(), kb, false)

func _update_projs(delta: float) -> void:
	for p in projs:
		p.pos += p.vel * delta
		p.life -= delta
		if p.life <= 0.0:
			continue
		var k := _cell(p.pos)
		var done := false
		for dx in range(-1, 2):
			if done:
				break
			for dy in range(-1, 2):
				if done:
					break
				var arr = grid.get(k + Vector2i(dx, dy))
				if arr == null:
					continue
				for e in arr:
					if e.dead or p.hits.has(e):
						continue
					if p.pos.distance_squared_to(e.pos) < pow(e.r + p.r, 2):
						p.hits.append(e)
						hit_enemy(e, p.dmg, p.vel.normalized(), 60.0 if p.kind == 0 else 30.0)
						p.pierce -= 1
						if p.pierce < 0:
							p.life = 0.0
							done = true
							break

func hit_enemy(e, dmg: float, kb_dir: Vector2, kb: float, show_num := true) -> void:
	dmg *= might() * randf_range(0.9, 1.1)
	e.hp -= dmg
	e.flash = 0.1
	e.push += kb_dir * kb * (13.0 / e.r)
	if show_num or e.hp <= 0.0:
		_num(e.pos + Vector2(randf_range(-8, 8), -e.r - 4.0), str(int(round(dmg))), Color("fff3b0") if dmg > 20.0 else Color.WHITE)
	if e.hp <= 0.0 and not e.dead:
		_kill(e)
	else:
		_snd("hit", 0.06)

func _kill(e) -> void:
	e.dead = true
	kills += 1
	var d: Dictionary = ETYPES[e.type]
	_drop_gem(e.pos, e.xp, 0)
	if randf() < 0.008 or e.type == 3:
		_drop_gem(e.pos + Vector2(12, 0), 0, 1)
	_burst(e.pos, d["col"], 6 if e.type < 3 else 30, 140.0)
	_snd("kill", 0.07)

func _drop_gem(pos: Vector2, value: int, kind: int) -> void:
	if kind == 0 and gems.size() >= MAX_GEMS:
		var g = gems[randi() % gems.size()]
		if g.kind == 0:
			g.value += value
			return
	var g := Gem.new()
	g.pos = pos
	g.value = value
	g.kind = kind
	gems.append(g)

func _update_gems(delta: float) -> void:
	var pr := pickup_r()
	for g in gems:
		var to: Vector2 = ppos - g.pos
		var d := to.length()
		if not g.magnet and d < pr:
			g.magnet = true
			g.spd = -120.0
		if g.magnet:
			g.spd += 1100.0 * delta
			g.pos += to / maxf(d, 0.001) * clamp(g.spd * delta, -4.0, d)
		if d < PLAYER_R + 8.0:
			g.dead = true
			if g.kind == 1:
				php = minf(max_hp(), php + 30.0)
				_num(ppos + Vector2(0, -30), "+30", Color("7dff9a"))
				_snd("levelup", 0.1)
			else:
				xp += g.value
				_snd("pickup", 0.04)
				while xp >= xp_need():
					xp -= xp_need()
					level += 1
					pending_levelups += 1
					_snd("levelup", 0.1)

func _cleanup() -> void:
	enemies = enemies.filter(func(e): return not e.dead)
	projs = projs.filter(func(p): return p.life > 0.0)
	gems = gems.filter(func(g): return not g.dead)

# ---- エフェクト ----
func _burst(pos: Vector2, col: Color, n: int, spd: float) -> void:
	for i in n:
		if particles.size() >= MAX_PARTICLES:
			particles.pop_front()
		var p := Particle.new()
		p.pos = pos
		p.vel = Vector2.from_angle(randf() * TAU) * randf_range(0.3, 1.0) * spd
		p.max_life = randf_range(0.25, 0.55)
		p.life = p.max_life
		p.col = col
		p.size = randf_range(2.0, 4.5)
		particles.append(p)

func _num(pos: Vector2, text: String, col: Color) -> void:
	if nums.size() >= MAX_NUMS:
		nums.pop_front()
	var n := DmgNum.new()
	n.pos = pos
	n.text = text
	n.col = col
	nums.append(n)

func _update_fx(delta: float) -> void:
	for p in particles:
		p.pos += p.vel * delta
		p.vel *= 0.9
		p.life -= delta
	particles = particles.filter(func(p): return p.life > 0.0)
	for n in nums:
		n.pos.y -= 40.0 * delta
		n.life -= delta
	nums = nums.filter(func(n): return n.life > 0.0)

# ---- 描画 ----
func _star(c: Vector2, ro: float, ri: float, n: int, rot: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n * 2:
		var rad := ro if i % 2 == 0 else ri
		pts.append(c + Vector2.from_angle(rot + PI * i / n) * rad)
	return pts

func _poly_outline(pts: PackedVector2Array, fill: Color, outline: Color, w := 2.0) -> void:
	draw_colored_polygon(pts, fill)
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, outline, w, true)

func _draw() -> void:
	var vs := get_viewport_rect().size / ZOOM
	var center := camera.get_screen_center_position()
	var vr := Rect2(center - vs * 0.5, vs).grow(64.0)
	_draw_ground(vr)
	# 経験値
	for g in gems:
		if not vr.has_point(g.pos):
			continue
		if g.kind == 1:
			draw_circle(g.pos, 9.0, Color("5a0f1a"))
			draw_circle(g.pos, 7.5, Color("ff4d6d"))
			draw_rect(Rect2(g.pos - Vector2(1.5, 5), Vector2(3, 10)), Color.WHITE)
			draw_rect(Rect2(g.pos - Vector2(5, 1.5), Vector2(10, 3)), Color.WHITE)
			continue
		var s := 5.5 if g.value < 5 else (7.5 if g.value < 20 else 9.5)
		var col := Color("4fc3ff") if g.value < 5 else (Color("7cf07c") if g.value < 20 else Color("ff5ccd"))
		var pts := PackedVector2Array([g.pos + Vector2(0, -s * 1.3), g.pos + Vector2(s, 0), g.pos + Vector2(0, s * 1.3), g.pos + Vector2(-s, 0)])
		_poly_outline(pts, col, col.darkened(0.6), 1.5)
		draw_circle(g.pos + Vector2(-s * 0.25, -s * 0.4), s * 0.25, Color(1, 1, 1, 0.7))
	# オーラ
	if wlv["aura"] > 0:
		var ar := aura_radius()
		draw_circle(ppos, ar, Color(1.0, 0.88, 0.4, 0.09 + aura_pulse * 0.08))
		draw_arc(ppos, ar, 0, TAU, 56, Color(1.0, 0.9, 0.45, 0.35 + aura_pulse * 0.4), 2.5, true)
		draw_arc(ppos, ar * (1.0 - aura_pulse * 0.3), 0, TAU, 48, Color(1.0, 0.95, 0.6, aura_pulse * 0.4), 2.0, true)
	# 敵
	for e in enemies:
		if vr.has_point(e.pos):
			_draw_enemy(e)
	# プレイヤー
	_draw_player()
	# 弾
	for p in projs:
		if p.kind == 0:
			draw_circle(p.pos - p.vel * 0.02, 5.0, Color(0.35, 0.85, 1.0, 0.25))
			draw_circle(p.pos, 9.0, Color(0.35, 0.85, 1.0, 0.35))
			draw_circle(p.pos, 5.0, Color("dff8ff"))
		else:
			var dir: Vector2 = p.vel.normalized()
			var nrm := Vector2(-dir.y, dir.x)
			var pts := PackedVector2Array([p.pos + dir * 13.0, p.pos + nrm * 3.5, p.pos - dir * 9.0, p.pos - nrm * 3.5])
			_poly_outline(pts, Color("e8eef5"), Color("4a5568"), 1.5)
	# ブレード
	if wlv["blade"] > 0:
		var bs := blade_stats()
		var n: int = bs["n"]
		for i in n:
			var bp: Vector2 = ppos + Vector2.from_angle(blade_angle + TAU * i / n) * bs["radius"]
			_poly_outline(_star(bp, 14.0, 5.5, 4, blade_angle * 4.0), Color("ffb347"), Color("7a3e00"), 2.0)
			draw_circle(bp, 3.0, Color("fff1d6"))
	# パーティクル
	for p in particles:
		var a: float = p.life / p.max_life
		draw_rect(Rect2(p.pos - Vector2.ONE * p.size * 0.5, Vector2.ONE * p.size), Color(p.col, a))
	# ダメージ数値
	for n in nums:
		var a: float = clamp(n.life / 0.3, 0.0, 1.0)
		var w: float = n.text.length() * 9.0
		draw_string_outline(FONT, n.pos - Vector2(w * 0.5, 0), n.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 5, Color(0, 0, 0, a * 0.85))
		draw_string(FONT, n.pos - Vector2(w * 0.5, 0), n.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(n.col, a))

func _draw_ground(vr: Rect2) -> void:
	draw_rect(vr, Color("18202b"))
	var step := 128.0
	var x0 := floorf(vr.position.x / step)
	var y0 := floorf(vr.position.y / step)
	var x1 := ceilf(vr.end.x / step)
	var y1 := ceilf(vr.end.y / step)
	for cx in range(int(x0), int(x1) + 1):
		for cy in range(int(y0), int(y1) + 1):
			var h := hash(Vector2i(cx, cy))
			var base := Vector2(cx * step, cy * step)
			if (cx + cy) % 2 == 0:
				draw_rect(Rect2(base, Vector2(step, step)), Color("1b2430"))
			var m := h % 7
			var p := base + Vector2(float(h % 97) / 97.0 * step, float((h >> 8) % 89) / 89.0 * step)
			if m == 0:
				for j in 3:
					var bx := p + Vector2(j * 5 - 5, 0)
					draw_line(bx, bx + Vector2((j - 1) * 2.5, -8 - (j % 2) * 3), Color("2f5a3a"), 2.0)
			elif m == 1:
				draw_circle(p, 4.0, Color("2a3442"))
				draw_circle(p + Vector2(-1, -1), 2.5, Color("364254"))
			elif m == 2:
				draw_circle(p, 2.0, Color("3d5a7a"))

func _draw_enemy(e) -> void:
	var d: Dictionary = ETYPES[e.type]
	var col: Color = Color.WHITE if e.flash > 0.0 else d["col"]
	var out: Color = d["out"]
	var p: Vector2 = e.pos
	var r: float = e.r
	var look: Vector2 = (ppos - p).normalized()
	var perp := Vector2(-look.y, look.x)
	match e.type:
		0:
			var sq := sin(e.phase * 8.0) * 0.08
			draw_set_transform(p, 0.0, Vector2(1.0 + sq, 1.0 - sq))
			draw_circle(Vector2.ZERO, r + 2.5, out)
			draw_circle(Vector2.ZERO, r, col)
			draw_circle(Vector2(-r * 0.35, -r * 0.4), r * 0.25, Color(1, 1, 1, 0.35))
			draw_set_transform(Vector2.ZERO)
		1:
			var flap := sin(e.phase * 16.0) * 0.6
			for s in [-1.0, 1.0]:
				var wing := PackedVector2Array([p + Vector2(s * r * 0.5, -r * 0.1), p + Vector2(s * r * 2.0, -r * (0.6 + flap)),
					p + Vector2(s * r * 1.6, r * 0.2), p + Vector2(s * r * 1.1, r * 0.5)])
				_poly_outline(wing, col.darkened(0.15), out, 1.5)
			draw_circle(p, r + 2.0, out)
			draw_circle(p, r, col)
		2:
			var pts := PackedVector2Array()
			for v in _oct:
				pts.append(p + v * (r + 2.5))
			draw_colored_polygon(pts, out)
			pts = PackedVector2Array()
			for v in _oct:
				pts.append(p + v * r)
			draw_colored_polygon(pts, col)
			draw_line(p + Vector2(-r * 0.5, r * 0.3), p + Vector2(r * 0.2, r * 0.5), out, 2.0)
			draw_line(p + Vector2(r * 0.1, -r * 0.6), p + Vector2(r * 0.5, -r * 0.2), out, 2.0)
		3:
			for s in [-1.0, 1.0]:
				var horn := PackedVector2Array([p + Vector2(s * r * 0.35, -r * 0.75), p + Vector2(s * r * 0.75, -r * 1.45), p + Vector2(s * r * 0.75, -r * 0.55)])
				_poly_outline(horn, Color("f4e9d0"), out, 2.0)
			draw_circle(p, r + 3.0, out)
			draw_circle(p, r, col)
			draw_circle(p + Vector2(-r * 0.3, -r * 0.4), r * 0.22, Color(1, 1, 1, 0.25))
			var bw := r * 2.0
			draw_rect(Rect2(p + Vector2(-bw * 0.5, -r - 22.0), Vector2(bw, 6)), Color(0, 0, 0, 0.7))
			draw_rect(Rect2(p + Vector2(-bw * 0.5, -r - 22.0), Vector2(bw * e.hp / e.max_hp, 6)), Color("ff3b3b"))
	# 目
	if e.type == 2:
		for s in [-1.0, 1.0]:
			draw_circle(p + look * r * 0.35 + perp * s * r * 0.3, r * 0.14, Color("ffb020"))
	else:
		var er := r * (0.22 if e.type != 1 else 0.26)
		for s in [-1.0, 1.0]:
			var ep: Vector2 = p + look * r * 0.3 + perp * s * r * 0.33 + Vector2(0, -r * 0.1)
			draw_circle(ep, er, Color.WHITE)
			draw_circle(ep + look * er * 0.4, er * 0.55, Color("1a1a2e") if e.type != 1 else Color("c0102a"))

func _draw_player() -> void:
	if not show_player or (finished and php <= 0.0):
		return
	var bob := sin(walk_phase) * 2.0 if moving else 0.0
	var p := ppos + Vector2(0, bob)
	draw_set_transform(ppos + Vector2(0, 14), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 14.0, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO)
	# 回収範囲のうっすら表示
	draw_arc(ppos, pickup_r(), 0, TAU, 48, Color(0.4, 0.75, 1.0, 0.07), 1.5, true)
	var body := Color("4a90e2")
	if hurt_flash > 0.0:
		body = Color("ff8080") if int(hurt_flash * 40.0) % 2 == 0 else Color.WHITE
	# マント
	var back := -facing
	var cape := PackedVector2Array([p + Vector2(-10, 0), p + Vector2(10, 0), p + Vector2(12, 0) + back * 10 + Vector2(0, 12), p + Vector2(-12, 0) + back * 10 + Vector2(0, 12)])
	draw_colored_polygon(cape, Color("8e3fd6"))
	draw_circle(p, PLAYER_R + 2.5, Color("f2f6ff"))
	draw_circle(p, PLAYER_R, body)
	draw_circle(p + Vector2(-4, -5), 4.0, Color(1, 1, 1, 0.35))
	# 帽子
	var hat := PackedVector2Array([p + Vector2(-15, -8), p + Vector2(15, -8), p + Vector2(4 - facing.x * 6, -34)])
	_poly_outline(hat, Color("6c2bb5"), Color("f2f6ff"), 2.0)
	draw_line(p + Vector2(-15, -8), p + Vector2(15, -8), Color("ffd166"), 3.0)
	# 目
	var perp := Vector2(-facing.y, facing.x)
	for s in [-1.0, 1.0]:
		var ep: Vector2 = p + facing * 5.0 + perp * s * 4.5 + Vector2(0, -1)
		draw_circle(ep, 2.6, Color("10162a"))
	# HPバー
	var frac: float = php / max_hp()
	draw_rect(Rect2(ppos + Vector2(-20, 22), Vector2(40, 5)), Color(0, 0, 0, 0.7))
	draw_rect(Rect2(ppos + Vector2(-20, 22), Vector2(40 * frac, 5)), Color("ff4d4d").lerp(Color("5ee07a"), frac))
