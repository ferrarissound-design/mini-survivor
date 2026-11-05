extends Node
## ゲーム全体の状態管理 + オートプレイ/スクリーンショット/タッチ自己テスト。
## ユーザー引数: -- --autoplay --shots --shot-dir=PATH --shot-prefix=X --timeskip=SEC --fight-shot-after=SEC --touchtest

enum State { TITLE, PLAYING, LEVELUP, PAUSED, GAMEOVER, WIN }

const GameScript := preload("res://scripts/game.gd")
const UIScript := preload("res://scripts/ui.gd")
const SfxScript := preload("res://scripts/sfx.gd")
const SAVE_PATH := "user://save.cfg"

var state := State.TITLE
var game
var ui
var sfx
var choices: Array = []
var best := 0.0

var autoplay := false
var take_shots := false
var shot_dir := ""
var shot_prefix := ""
var timeskip := 0.0
var fight_shot_after := 12.0
var touchtest := false
var stats := false
var _stats_t := 0.0
var shots_done := {}
var real_t := 0.0
var state_t := 0.0

func _ready() -> void:
	_parse_args()
	_setup_input()
	_load_best()
	sfx = SfxScript.new()
	add_child(sfx)
	game = GameScript.new()
	game.sfx = sfx
	add_child(game)
	game.died.connect(_on_died)
	game.won.connect(_on_won)
	ui = UIScript.new()
	add_child(ui)
	ui.hud.game = game
	ui.start_requested.connect(start_game)
	ui.retry_requested.connect(start_game)
	ui.title_requested.connect(go_title)
	ui.choice_made.connect(_on_choice)
	ui.pause_requested.connect(toggle_pause)
	ui.resume_requested.connect(toggle_pause)
	get_window().size_changed.connect(_update_scale)
	_update_scale()
	go_title()
	if touchtest:
		_run_touchtest()

func _parse_args() -> void:
	shot_dir = ProjectSettings.globalize_path("res://out")
	for a in OS.get_cmdline_user_args():
		if a == "--autoplay":
			autoplay = true
		elif a == "--shots":
			take_shots = true
		elif a == "--stats":
			stats = true
		elif a == "--touchtest":
			touchtest = true
		elif a.begins_with("--shot-dir="):
			shot_dir = a.get_slice("=", 1)
		elif a.begins_with("--shot-prefix="):
			shot_prefix = a.get_slice("=", 1)
		elif a.begins_with("--timeskip="):
			timeskip = a.get_slice("=", 1).to_float()
		elif a.begins_with("--fight-shot-after="):
			fight_shot_after = a.get_slice("=", 1).to_float()

func _setup_input() -> void:
	var keys := {"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT], "move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN]}
	var axes := {"move_left": [JOY_AXIS_LEFT_X, -1.0], "move_right": [JOY_AXIS_LEFT_X, 1.0], "move_up": [JOY_AXIS_LEFT_Y, -1.0], "move_down": [JOY_AXIS_LEFT_Y, 1.0]}
	var dpad := {"move_left": JOY_BUTTON_DPAD_LEFT, "move_right": JOY_BUTTON_DPAD_RIGHT, "move_up": JOY_BUTTON_DPAD_UP, "move_down": JOY_BUTTON_DPAD_DOWN}
	for act in keys:
		if not InputMap.has_action(act):
			InputMap.add_action(act, 0.2)
		for k in keys[act]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(act, ev)
		var jm := InputEventJoypadMotion.new()
		jm.axis = axes[act][0]
		jm.axis_value = axes[act][1]
		InputMap.action_add_event(act, jm)
		var jb := InputEventJoypadButton.new()
		jb.button_index = dpad[act]
		InputMap.action_add_event(act, jb)

func _load_best() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) == OK:
		best = float(cf.get_value("record", "best", 0.0))

func _save_best() -> void:
	var cf := ConfigFile.new()
	cf.set_value("record", "best", best)
	cf.save(SAVE_PATH)

func _set_state(s: State) -> void:
	state = s
	state_t = 0.0

## 縦画面(スマホ)では基準解像度を小さくして文字やボタンを大きく表示する
func _update_scale() -> void:
	var ws := get_window().size
	var base := 520 if ws.y > ws.x * 1.15 else 720
	get_window().content_scale_size = Vector2i(base, base)

# ---------- 状態遷移 ----------
func go_title() -> void:
	game.reset()
	game.show_player = false
	_set_state(State.TITLE)
	ui.show_title(best)

func start_game() -> void:
	game.reset()
	game.show_player = true
	if timeskip > 0.0:
		game.set_time(timeskip)
		for id in ["w:blade", "w:aura", "w:knife", "w:bolt", "w:blade", "p:might", "w:bolt", "w:aura", "p:speed", "w:blade"]:
			game.apply_id(id)
		game.level = 11
	_set_state(State.PLAYING)
	ui.show_playing()
	sfx.play("start")
	if autoplay or DisplayServer.is_touchscreen_available():
		ui.joystick.show_hint("画面をドラッグして移動", 4.0)
	else:
		ui.joystick.show_hint("WASD / 矢印キーで移動", 4.0)

func toggle_pause() -> void:
	if state == State.PLAYING:
		_set_state(State.PAUSED)
		ui.show_pause()
	elif state == State.PAUSED:
		_set_state(State.PLAYING)
		ui.show_playing()

func _open_levelup() -> void:
	_set_state(State.LEVELUP)
	choices = game.roll_choices(3)
	ui.show_levelup(choices)

func _on_choice(i: int) -> void:
	if state != State.LEVELUP or i >= choices.size():
		return
	game.apply_id(choices[i]["id"])
	game.pending_levelups -= 1
	sfx.play("click", 0.0)
	if game.pending_levelups > 0:
		_open_levelup()
	else:
		_set_state(State.PLAYING)
		ui.hide_levelup()

func _end(won: bool) -> void:
	print("WEAPONS ", game.wlv, " PASSIVES ", game.plv)
	print("GAME END won=", won, " time=", snappedf(game.t, 0.1), " kills=", game.kills, " level=", game.level)
	var new_best: bool = game.t > best
	if new_best:
		best = game.t
		if not autoplay and not touchtest:
			_save_best()
	_set_state(State.WIN if won else State.GAMEOVER)
	ui.show_end(won, game.t, game.kills, game.level, best, new_best)

func _on_died() -> void:
	_end(false)

func _on_won() -> void:
	_end(true)

func _unhandled_input(event: InputEvent) -> void:
	var pause_key: bool = (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ESCAPE or event.keycode == KEY_P)) \
		or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START)
	if pause_key and (state == State.PLAYING or state == State.PAUSED):
		toggle_pause()
		get_viewport().set_input_as_handled()

# ---------- ループ ----------
func _process(delta: float) -> void:
	real_t += delta
	state_t += delta
	match state:
		State.TITLE:
			if autoplay and state_t > 1.5:
				start_game()
		State.PLAYING:
			var mv := Input.get_vector("move_left", "move_right", "move_up", "move_down")
			var jv: Vector2 = ui.joystick.get_vector()
			if jv != Vector2.ZERO:
				mv = jv
			if autoplay:
				mv = _auto_dir()
				ui.joystick.simulate(mv)
			game.move_input = mv
			game.step(delta)
			if state == State.PLAYING and game.pending_levelups > 0:
				_open_levelup()
		State.LEVELUP:
			if autoplay and state_t > 1.2:
				var pick := 0
				for i in choices.size():
					if String(choices[i]["id"]).begins_with("w:"):
						pick = i
						break
				_on_choice(pick)
		State.GAMEOVER, State.WIN:
			if autoplay and state_t > 3.0:
				start_game()
	if take_shots:
		_check_shots()
	if stats and state == State.PLAYING and game.t - _stats_t >= 5.0:
		_stats_t = game.t
		var ds := []
		for e in game.enemies: ds.append(game.ppos.distance_to(e.pos))
		ds.sort()
		if ds.size() > 0: print("  dist min=%.0f med=%.0f max=%.0f ppos=%s vp=%s" % [ds[0], ds[ds.size()/2], ds[-1], str(game.ppos), str(get_viewport().get_visible_rect().size)])
		print("STATS t=%.0f enemies=%d gems=%d projs=%d kills=%d lv=%d hp=%.0f fps=%d proc_ms=%.2f" % [game.t, game.enemies.size(), game.gems.size(), game.projs.size(), game.kills, game.level, game.php, Engine.get_frames_per_second(), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0])

func _auto_dir() -> Vector2:
	var p: Vector2 = game.ppos
	var away := Vector2.ZERO
	for e in game.enemies:
		var dv: Vector2 = p - e.pos
		var d := dv.length()
		if d < 130.0 and d > 0.1:
			away += dv / d * (1.0 - d / 130.0) * (2.0 if e.type >= 2 else 1.0)
	var a := real_t * 0.45
	var target := Vector2(cos(a), sin(a * 1.3)) * 150.0
	var dir := (target - p).normalized() * 0.7 + away * 1.6
	return dir.normalized() if dir.length() > 0.05 else Vector2.ZERO

# ---------- スクリーンショット ----------
func _check_shots() -> void:
	if state == State.TITLE and state_t > 0.8 and not shots_done.has("title"):
		_shot("title")
	if state == State.LEVELUP and state_t > 0.6 and not shots_done.has("levelup"):
		_shot("levelup")
	if state == State.PLAYING and game.t - timeskip > fight_shot_after and not shots_done.has("fight"):
		_shot("fight")

func _shot(name: String) -> void:
	shots_done[name] = true
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(shot_dir)
	var path := shot_dir.path_join(shot_prefix + name + ".png")
	img.save_png(path)
	print("SHOT saved ", path, " ", img.get_size(), " enemies=", game.enemies.size())

# ---------- タッチ自己テスト ----------
func _to_window(canvas_pos: Vector2) -> Vector2:
	return get_viewport().get_final_transform() * canvas_pos

func _touch(idx: int, canvas_pos: Vector2, pressed: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = idx
	ev.position = _to_window(canvas_pos)
	ev.pressed = pressed
	Input.parse_input_event(ev)

func _drag(idx: int, canvas_pos: Vector2, rel: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = idx
	ev.position = _to_window(canvas_pos)
	ev.relative = rel
	Input.parse_input_event(ev)

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _run_touchtest() -> void:
	var results := []
	await _frames(10)
	var vs := get_viewport().get_visible_rect().size
	print("TOUCHTEST viewport(canvas)=", vs, " window=", DisplayServer.window_get_size(), " final_xform=", get_viewport().get_final_transform())
	# 1) タイトルの「スタート」ボタンをタップ
	var c: Vector2 = ui.start_button.get_global_rect().get_center()
	_touch(0, c, true)
	await _frames(2)
	_touch(0, c, false)
	await _frames(5)
	results.append(["タップでスタート", state == State.PLAYING])
	# 2) 画面左下でドラッグ → 右方向へ移動するか
	var p0: Vector2 = game.ppos
	var o := Vector2(vs.x * 0.3, vs.y * 0.7)
	_touch(0, o, true)
	await _frames(2)
	for i in 1 + 20:
		_drag(0, o + Vector2(i * 5.0, 0), Vector2(5, 0))
		await _frames(1)
	await _frames(20)
	var jv: Vector2 = ui.joystick.get_vector()
	var dx: float = game.ppos.x - p0.x
	results.append(["ドラッグで右へ移動 (dx=%.1f, stick=%s)" % [dx, str(jv)], dx > 20.0 and jv.x > 0.9])
	if take_shots:
		_shot("joystick")
		await _frames(3)
	# 3) 指を離すと停止
	_touch(0, o + Vector2(100, 0), false)
	await _frames(3)
	var p1: Vector2 = game.ppos
	await _frames(10)
	results.append(["指を離すと停止", game.ppos.distance_to(p1) < 0.5])
	# 4) 一時停止ボタンをタップ (ジョイスティックが出ないこと)
	var pc: Vector2 = ui.pause_button.get_global_rect().get_center()
	_touch(0, pc, true)
	await _frames(2)
	var joy_on_pause: bool = ui.joystick.is_active()
	_touch(0, pc, false)
	await _frames(5)
	results.append(["一時停止ボタン (ジョイスティック非表示)", state == State.PAUSED and not joy_on_pause])
	# 5) 再開ボタン
	var rc: Vector2 = ui.resume_button.get_global_rect().get_center()
	_touch(0, rc, true)
	await _frames(2)
	_touch(0, rc, false)
	await _frames(5)
	results.append(["再開ボタン", state == State.PLAYING])
	# 6) レベルアップカードをタップ
	game.xp = game.xp_need()
	game.pending_levelups = 1
	game.level += 1
	await _frames(40)
	var ok6 := false
	if state == State.LEVELUP and ui.cards.size() == 3:
		var cc: Vector2 = ui.cards[1].get_global_rect().get_center()
		_touch(0, cc, true)
		await _frames(2)
		_touch(0, cc, false)
		await _frames(5)
		ok6 = state == State.PLAYING
	results.append(["レベルアップカードをタップ", ok6])
	var all_ok := true
	for r in results:
		print("TOUCHTEST ", "PASS" if r[1] else "FAIL", " - ", r[0])
		all_ok = all_ok and r[1]
	print("TOUCHTEST RESULT: ", "ALL PASS" if all_ok else "FAILED")
	get_tree().quit(0 if all_ok else 1)
