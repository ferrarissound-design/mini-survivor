extends CanvasLayer
## 画面UI: タイトル / HUD / レベルアップ / 一時停止 / リザルト。タッチ操作しやすい大きなボタン。

signal start_requested
signal choice_made(idx: int)
signal retry_requested
signal title_requested
signal pause_requested
signal resume_requested

const FONT := preload("res://fonts/NotoSansJP-Bold-subset.otf")
const HudScript := preload("res://scripts/hud.gd")
const JoyScript := preload("res://scripts/joystick.gd")
const IconScript := preload("res://scripts/icon.gd")

var root: Control
var hud
var joystick
var pause_button: Button
var title_layer: Control
var start_button: Button
var best_label: Label
var levelup_layer: Control
var cards_box: VBoxContainer
var cards: Array = []
var pause_layer: Control
var resume_button: Button
var end_layer: Control
var end_title: Label
var end_stats: Label
var retry_button: Button
var panels: Array = []
var wide_buttons: Array = []
var card_w := 600.0
var title_label: Label

func _ready() -> void:
	layer = 10
	root = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _make_theme()
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud = HudScript.new()
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud)
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	joystick = JoyScript.new()
	joystick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(joystick)
	joystick.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_button = Button.new()
	pause_button.text = "II"
	pause_button.focus_mode = Control.FOCUS_NONE
	pause_button.add_theme_font_size_override("font_size", 26)
	root.add_child(pause_button)
	pause_button.anchor_left = 1.0
	pause_button.anchor_right = 1.0
	pause_button.offset_left = -78
	pause_button.offset_right = -12
	pause_button.offset_top = 28
	pause_button.offset_bottom = 94
	pause_button.pressed.connect(func(): pause_requested.emit())
	joystick.block_controls = [pause_button]
	_build_title()
	_build_levelup()
	_build_pause()
	_build_end()
	get_viewport().size_changed.connect(_on_resize)
	_on_resize()

# ---------- テーマ ----------
func _sb(bg: Color, border: Color, bw := 3, radius := 16) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 6
	s.shadow_offset = Vector2(0, 3)
	return s

func _make_theme() -> Theme:
	var th := Theme.new()
	th.default_font = FONT
	th.default_font_size = 26
	th.set_stylebox("normal", "Button", _sb(Color("26314d"), Color("6f8fff")))
	th.set_stylebox("hover", "Button", _sb(Color("33426a"), Color("9fb6ff")))
	th.set_stylebox("pressed", "Button", _sb(Color("1a2236"), Color("ffd166")))
	th.set_stylebox("disabled", "Button", _sb(Color("26314d"), Color("4a5a8a")))
	var focus := _sb(Color(0, 0, 0, 0), Color("ffd166"), 4)
	focus.draw_center = false
	focus.shadow_size = 0
	th.set_stylebox("focus", "Button", focus)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		th.set_color(c, "Button", Color.WHITE)
	th.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.8))
	var panel := _sb(Color(0.08, 0.1, 0.16, 0.94), Color("4f6bd8"), 3, 22)
	panel.content_margin_left = 26
	panel.content_margin_right = 26
	panel.content_margin_top = 22
	panel.content_margin_bottom = 26
	th.set_stylebox("panel", "PanelContainer", panel)
	th.set_constant("outline_size", "Label", 0)
	return th

func _label(text: String, fs: int, col := Color.WHITE, outline := 0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	if outline > 0:
		l.add_theme_constant_override("outline_size", outline)
		l.add_theme_color_override("font_outline_color", Color(0.04, 0.04, 0.1))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _button(text: String, fs := 32, h := 84.0) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", fs)
	b.custom_minimum_size = Vector2(340, h)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	wide_buttons.append(b)
	return b

func _overlay(dim: float, with_panel := true) -> Array:
	var layer_c := Control.new()
	layer_c.mouse_filter = Control.MOUSE_FILTER_STOP
	layer_c.visible = false
	root.add_child(layer_c)
	layer_c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.03, 0.07, dim)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer_c.add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var cc := CenterContainer.new()
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer_c.add_child(cc)
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 18)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	if with_panel:
		var panel := PanelContainer.new()
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cc.add_child(panel)
		panel.add_child(vb)
		panels.append(panel)
	else:
		cc.add_child(vb)
	return [layer_c, vb]

# ---------- 画面構築 ----------
func _build_title() -> void:
	var o := _overlay(0.45, false)
	title_layer = o[0]
	var vb: VBoxContainer = o[1]
	vb.add_theme_constant_override("separation", 22)
	title_label = _label("ミニ・サバイバー", 72, Color("ffd166"), 14)
	vb.add_child(title_label)
	vb.add_child(_label("10分間 生き延びろ！", 30, Color("e6ecff"), 8))
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 16)
	vb.add_child(sp)
	start_button = _button("スタート", 40, 96)
	start_button.pressed.connect(func(): start_requested.emit())
	vb.add_child(start_button)
	best_label = _label("", 24, Color("9fb6ff"), 6)
	vb.add_child(best_label)
	var hint := _label("移動: WASD / 矢印キー / スティック\nスマホ: 画面をドラッグ　攻撃は自動！", 22, Color("c8d2ea"), 6)
	vb.add_child(hint)

func _build_levelup() -> void:
	var o := _overlay(0.6)
	levelup_layer = o[0]
	var vb: VBoxContainer = o[1]
	vb.add_child(_label("レベルアップ！", 44, Color("ffd166"), 10))
	vb.add_child(_label("強化を1つ選んでください", 22, Color("c8d2ea")))
	cards_box = VBoxContainer.new()
	cards_box.add_theme_constant_override("separation", 14)
	vb.add_child(cards_box)

func _build_pause() -> void:
	var o := _overlay(0.6)
	pause_layer = o[0]
	var vb: VBoxContainer = o[1]
	vb.add_child(_label("一時停止", 48, Color("ffd166"), 10))
	resume_button = _button("再開")
	resume_button.pressed.connect(func(): resume_requested.emit())
	vb.add_child(resume_button)
	var tb := _button("タイトルへ", 30, 76)
	tb.pressed.connect(func(): title_requested.emit())
	vb.add_child(tb)

func _build_end() -> void:
	var o := _overlay(0.65)
	end_layer = o[0]
	var vb: VBoxContainer = o[1]
	end_title = _label("ゲームオーバー", 56, Color("ff6b6b"), 12)
	vb.add_child(end_title)
	end_stats = _label("", 30, Color.WHITE)
	vb.add_child(end_stats)
	retry_button = _button("リトライ", 36, 92)
	retry_button.pressed.connect(func(): retry_requested.emit())
	vb.add_child(retry_button)
	var tb := _button("タイトルへ", 30, 76)
	tb.pressed.connect(func(): title_requested.emit())
	vb.add_child(tb)

func _on_resize() -> void:
	var vw := get_viewport().get_visible_rect().size.x
	card_w = minf(640.0, vw - 80.0)
	title_label.add_theme_font_size_override("font_size", int(minf(72.0, (vw - 40.0) / 8.4)))
	for b in wide_buttons:
		b.custom_minimum_size.x = minf(380.0, vw - 120.0)
	for c in cards:
		if is_instance_valid(c):
			c.custom_minimum_size.x = card_w

# ---------- 表示切り替え ----------
func _hide_all() -> void:
	for l in [title_layer, levelup_layer, pause_layer, end_layer]:
		l.visible = false

func show_title(best: float) -> void:
	_hide_all()
	hud.visible = false
	pause_button.visible = false
	joystick.set_enabled(false)
	best_label.text = "ベスト記録  %s" % HudScript.fmt_time(best) if best > 0.0 else ""
	best_label.visible = best > 0.0
	title_layer.visible = true
	start_button.grab_focus()

func show_playing() -> void:
	_hide_all()
	hud.visible = true
	pause_button.visible = true
	joystick.set_enabled(true)

func show_pause() -> void:
	joystick.set_enabled(false)
	pause_layer.visible = true
	resume_button.grab_focus()

func show_levelup(choices: Array) -> void:
	joystick.set_enabled(false)
	for c in cards:
		c.queue_free()
	cards.clear()
	for i in choices.size():
		var ch: Dictionary = choices[i]
		var b := Button.new()
		b.custom_minimum_size = Vector2(card_w, 112)
		b.disabled = true
		var m := MarginContainer.new()
		for side in ["left", "right", "top", "bottom"]:
			m.add_theme_constant_override("margin_" + side, 14 if side != "left" else 16)
		b.add_child(m)
		m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 16)
		m.add_child(hb)
		var icon = IconScript.new()
		icon.custom_minimum_size = Vector2(76, 76)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.col = ch["col"]
		icon.kind = ch["icon"]
		hb.add_child(icon)
		var vb := VBoxContainer.new()
		vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vb.alignment = BoxContainer.ALIGNMENT_CENTER
		vb.add_theme_constant_override("separation", 2)
		hb.add_child(vb)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		vb.add_child(row)
		var tl := _label(ch["title"], 30, Color.WHITE)
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.add_child(tl)
		if ch["new"]:
			row.add_child(_label("NEW!", 22, Color("ffd166")))
		var dl := _label(ch["desc"], 21, Color("b8c6ee"))
		dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(dl)
		_ignore_mouse(m)
		b.pressed.connect(func(): choice_made.emit(i))
		cards_box.add_child(b)
		cards.append(b)
	levelup_layer.visible = true
	# 誤タップ防止: 少し待ってから押せるようにする
	await get_tree().create_timer(0.35).timeout
	for b in cards:
		if is_instance_valid(b):
			b.disabled = false
	if not cards.is_empty() and is_instance_valid(cards[0]) and levelup_layer.visible:
		cards[0].grab_focus()

func hide_levelup() -> void:
	levelup_layer.visible = false
	joystick.set_enabled(true)

func show_end(won: bool, time_sec: float, kills: int, level: int, best: float, new_best: bool) -> void:
	_hide_all()
	pause_button.visible = false
	joystick.set_enabled(false)
	end_title.text = "生存成功！" if won else "ゲームオーバー"
	end_title.add_theme_color_override("font_color", Color("7dff9a") if won else Color("ff6b6b"))
	var s := "生存時間  %s\n撃破数  %d\nレベル  %d" % [HudScript.fmt_time(time_sec), kills, level]
	s += "\n" + ("ベスト記録更新！" if new_best else "ベスト  %s" % HudScript.fmt_time(best))
	end_stats.text = s
	end_layer.visible = true
	retry_button.grab_focus()

func _ignore_mouse(n: Node) -> void:
	if n is Control:
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in n.get_children():
		_ignore_mouse(c)

func _unhandled_input(event: InputEvent) -> void:
	if levelup_layer.visible and event is InputEventKey and event.pressed and not event.echo:
		var idx: int = event.keycode - KEY_1
		if idx >= 0 and idx < cards.size() and not cards[idx].disabled:
			choice_made.emit(idx)
			get_viewport().set_input_as_handled()
