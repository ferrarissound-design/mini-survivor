extends Control
## フローティング仮想ジョイスティック: 画面のどこでも触れた場所に出現し、ドラッグで移動。

const R := 80.0
const KNOB := 34.0
var enabled := false
var touch_idx := -1
var origin := Vector2.ZERO
var knob := Vector2.ZERO
var block_controls: Array = []
var sim := false
var hint_t := 0.0
var hint_text := ""
const FONT := preload("res://fonts/NotoSansJP-Bold-subset.otf")

func get_vector() -> Vector2:
	if touch_idx == -1 and not sim:
		return Vector2.ZERO
	var v := (knob - origin) / R
	if v.length() < 0.15:
		return Vector2.ZERO
	return v.limit_length(1.0)

func is_active() -> bool:
	return touch_idx != -1

func release() -> void:
	touch_idx = -1
	sim = false
	queue_redraw()

func set_enabled(on: bool) -> void:
	enabled = on
	if not on:
		release()

func simulate(v: Vector2) -> void:
	sim = true
	origin = Vector2(size.x * 0.22, size.y * 0.78)
	knob = origin + v.limit_length(1.0) * R * 0.9
	queue_redraw()

func show_hint(text: String, dur := 5.0) -> void:
	hint_text = text
	hint_t = dur

func _blocked(pos: Vector2) -> bool:
	for c in block_controls:
		if c.is_visible_in_tree() and c.get_global_rect().grow(10.0).has_point(pos):
			return true
	return false

func _input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if touch_idx == -1 and not _blocked(event.position):
				touch_idx = event.index
				origin = event.position
				knob = origin
				hint_t = minf(hint_t, 0.5)
		elif event.index == touch_idx:
			touch_idx = -1
		queue_redraw()
	elif event is InputEventScreenDrag and event.index == touch_idx:
		var d: Vector2 = event.position - origin
		if d.length() > R:
			origin = event.position - d.normalized() * R
		knob = event.position
		queue_redraw()

func _process(delta: float) -> void:
	if hint_t > 0.0:
		hint_t -= delta
		queue_redraw()

func _draw() -> void:
	if touch_idx != -1 or sim:
		var k := origin + (knob - origin).limit_length(R)
		draw_circle(origin, R, Color(1, 1, 1, 0.10))
		draw_arc(origin, R, 0, TAU, 56, Color(1, 1, 1, 0.45), 3.0, true)
		draw_circle(k, KNOB, Color(0.75, 0.85, 1.0, 0.5))
		draw_arc(k, KNOB, 0, TAU, 40, Color(1, 1, 1, 0.85), 2.5, true)
	if hint_t > 0.0 and hint_text != "":
		var a := clampf(hint_t, 0.0, 1.0)
		var y := size.y - 60.0
		draw_string_outline(FONT, Vector2(0, y), hint_text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 26, 8, Color(0, 0, 0, 0.8 * a))
		draw_string(FONT, Vector2(0, y), hint_text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 26, Color(1, 1, 1, a))
