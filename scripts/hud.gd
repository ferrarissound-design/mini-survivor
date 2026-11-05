extends Control
## HUD (経験値バー、HP、レベル、タイマー、撃破数、告知)。サイズに合わせて自動配置。

const FONT := preload("res://fonts/NotoSansJP-Bold-subset.otf")
var game

func _process(_d: float) -> void:
	if visible:
		queue_redraw()

func _text(pos: Vector2, s: String, fs: int, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0, col := Color.WHITE) -> void:
	draw_string_outline(FONT, pos, s, align, width, fs, 7, Color(0.02, 0.03, 0.08, 0.85))
	draw_string(FONT, pos, s, align, width, fs, col)

static func fmt_time(sec: float) -> String:
	var s := int(sec)
	return "%02d:%02d" % [s / 60, s % 60]

func _draw() -> void:
	if game == null:
		return
	var w := size.x
	var h := size.y
	# 低HP時の赤い縁
	var frac: float = game.php / game.max_hp()
	if frac < 0.3:
		var a := (0.3 - frac) / 0.3 * (0.45 + 0.15 * sin(Time.get_ticks_msec() / 120.0))
		for i in 6:
			var t := 10.0 * i
			draw_rect(Rect2(t, t, w - t * 2.0, h - t * 2.0), Color(1, 0.1, 0.1, a * (1.0 - i / 6.0) * 0.5), false, 10.0)
	# 経験値バー
	var xf := clampf(float(game.xp) / game.xp_need(), 0.0, 1.0)
	draw_rect(Rect2(0, 0, w, 18), Color(0.02, 0.03, 0.08, 0.8))
	draw_rect(Rect2(0, 0, w * xf, 18), Color("3aa8ff"))
	draw_rect(Rect2(0, 0, w * xf, 5), Color(1, 1, 1, 0.25))
	# HPバー
	var hw := clampf(w * 0.32, 150.0, 320.0)
	var hr := Rect2(14, 30, hw, 24)
	draw_rect(hr.grow(3), Color(0.02, 0.03, 0.08, 0.85))
	draw_rect(Rect2(hr.position, Vector2(hw * frac, hr.size.y)), Color("ff4d4d").lerp(Color("4cd964"), frac))
	draw_rect(Rect2(hr.position, Vector2(hw * frac, 6)), Color(1, 1, 1, 0.25))
	_text(Vector2(hr.position.x, hr.position.y + 19), "HP %d / %d" % [ceili(game.php), int(game.max_hp())], 18, HORIZONTAL_ALIGNMENT_CENTER, hw)
	var lvs := "Lv.%d" % game.level
	_text(Vector2(14, 92), lvs, 28, HORIZONTAL_ALIGNMENT_LEFT, -1, Color("8fd3ff"))
	var lw := FONT.get_string_size(lvs, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
	_text(Vector2(14 + lw + 22, 92), "撃破 %d" % game.kills, 24)
	# タイマー
	var remain: float = game.WIN_TIME - game.t
	_text(Vector2(0, 66), fmt_time(game.t), 40, HORIZONTAL_ALIGNMENT_CENTER, w, Color("ffe08a") if remain < 60.0 else Color.WHITE)
	# 告知
	if game.announce_t > 0.0:
		var a := clampf(game.announce_t, 0.0, 1.0)
		var y := h * 0.3
		draw_rect(Rect2(0, y - 46, w, 66), Color(0.4, 0.05, 0.05, 0.45 * a))
		_text(Vector2(0, y), game.announce_text, 38, HORIZONTAL_ALIGNMENT_CENTER, w, Color(1, 0.85, 0.5, a))
