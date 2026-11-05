extends Control
## レベルアップカードのアイコン。

const FONT := preload("res://fonts/NotoSansJP-Bold-subset.otf")
const GLYPH := {"speed": "速", "maxhp": "HP", "magnet": "磁", "might": "力", "haste": "連", "regen": "再", "heal": "癒"}
var col := Color.WHITE
var kind := ""

func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5 - 2.0
	draw_circle(c, r, col.darkened(0.6))
	draw_arc(c, r, 0, TAU, 48, col, 3.0, true)
	match kind:
		"bolt":
			draw_circle(c, r * 0.48, Color(col, 0.35))
			draw_circle(c, r * 0.28, Color("dff8ff"))
		"blade":
			var pts := PackedVector2Array()
			for i in 8:
				pts.append(c + Vector2.from_angle(0.3 + PI * i / 4.0) * (r * 0.62 if i % 2 == 0 else r * 0.24))
			draw_colored_polygon(pts, col)
		"aura":
			draw_circle(c, r * 0.6, Color(col, 0.25))
			draw_arc(c, r * 0.6, 0, TAU, 40, col, 3.0, true)
			draw_circle(c, r * 0.22, Color.WHITE)
		"knife":
			var d := Vector2(1, -1).normalized()
			var n := Vector2(-d.y, d.x)
			draw_colored_polygon(PackedVector2Array([c + d * r * 0.65, c + n * r * 0.18, c - d * r * 0.5, c - n * r * 0.18]), col)
		_:
			var g: String = GLYPH.get(kind, "?")
			var fs := int(r * (0.8 if g.length() > 1 else 1.0))
			draw_string(FONT, Vector2(0, c.y + fs * 0.36), g, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, Color.WHITE)
