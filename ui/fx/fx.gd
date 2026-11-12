# 演出の層(§9.12・D-16)。粒・紙吹雪・飛ぶ数字・呼びかけの字・ゆれを出す。core を呼ばない。
# 「演出: 控えめ」では粒・紙吹雪・ゆれを出さない(FR-29)。同時に出す粒は 200 個まで。
extends Control

const T := preload("res://ui/theme/tokens.gd")
const Kit := preload("res://ui/kit.gd")

var _live := 0
var _callout: Label
var _callout_queue: Array = []
var _callout_busy := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_callout = Kit.label("", T.FS_CALLOUT, T.W_BLACK, T.BRASS_HI)
	_callout.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	_callout.add_theme_constant_override("shadow_offset_y", 3)
	_callout.add_theme_constant_override("shadow_outline_size", 8)
	_callout.modulate.a = 0.0
	add_child(_callout)


func _emitter(count: int, life: float) -> CPUParticles2D:
	var n := mini(count, T.PARTICLE_MAX - _live)
	if T.lite or n <= 0:
		return null
	_live += n
	var p := CPUParticles2D.new()
	p.amount = n
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 1.0
	p.emitting = true
	p.finished.connect(func():
		_live -= n
		p.queue_free())
	add_child(p)
	return p


# 真鍮色の粒が pos から散る(大穴の当たり・確保)。
func burst(pos: Vector2, count: int, sec: float) -> void:
	var p := _emitter(count, sec)
	if p == null:
		return
	p.position = pos
	p.spread = 180.0
	p.initial_velocity_min = 140.0
	p.initial_velocity_max = 420.0
	p.damping_min = 200.0
	p.damping_max = 320.0
	p.gravity = Vector2(0, 260)
	p.scale_amount_min = 4.0
	p.scale_amount_max = 8.0
	p.color = T.BRASS_HI
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = g


# 紙吹雪が上から降る(完走)。
func confetti(width: float, height: float) -> void:
	var p := _emitter(T.CONFETTI_COUNT, T.CONFETTI_SEC)
	if p == null:
		return
	p.explosiveness = 0.7
	p.position = Vector2(width / 2, -20)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(width / 2, 10)
	p.direction = Vector2.DOWN
	p.spread = 25.0
	p.initial_velocity_min = height * 0.25
	p.initial_velocity_max = height * 0.6
	p.gravity = Vector2(0, height * 0.35)
	p.angular_velocity_min = -360.0
	p.angular_velocity_max = 360.0
	p.scale_amount_min = 8.0
	p.scale_amount_max = 13.0
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75, 1.0])
	g.colors = PackedColorArray(T.CONFETTI)
	p.color_initial_ramp = g


# 字が from から to へ飛んで消える(当たりの +356、確保のポット)。tw に動きを足す。
func fly_text(tw: Tween, text: String, from: Vector2, to: Vector2, sec: float, color: Color, size: int, arc: float = 0.0) -> void:
	var l := Kit.num_label(text, size, color, 800)
	l.size = Vector2(320, 60)
	l.pivot_offset = l.size / 2
	add_child(l)
	var half := l.size / 2
	var mid := (from + to) / 2 + Vector2(0, -arc)
	# 弧を描く(2 次のベジェ)。arc が 0 ならまっすぐ
	var step := func(k: float) -> void:
		l.position = from.lerp(mid, k).lerp(mid.lerp(to, k), k) - half
		l.scale = Vector2.ONE * lerpf(1.25, 0.8, k)
		l.modulate.a = 1.0 - k * k * k
	step.call(0.0)
	tw.parallel().tween_method(step, 0.0, 1.0, sec)
	tw.parallel().tween_callback(l.queue_free).set_delay(sec)


# 画面のゆれ(外れだけ。幅 6 px・0.18 秒)。
func shake(tw: Tween, target: Control, sec: float) -> void:
	if T.lite:
		return
	var x := target.position.x
	var sub := create_tween()
	sub.tween_property(target, "position:x", x - T.SHAKE_PX, sec * 0.25)
	sub.tween_property(target, "position:x", x + T.SHAKE_PX, sec * 0.5)
	sub.tween_property(target, "position:x", x, sec * 0.25)
	var settle := func() -> void:
		sub.kill()
		target.position.x = x
	tw.parallel().tween_callback(settle).set_delay(sec)


# 呼びかけの字(「大穴」「ぴたり」「完走」など)。同時に 1 つで、重なったら順に出す。
func callout(text: String, color: Color, at: Rect2) -> void:
	_callout_queue.append([text, color, at])
	if not _callout_busy:
		_next_callout()


func _next_callout() -> void:
	if _callout_queue.is_empty():
		_callout_busy = false
		return
	_callout_busy = true
	var c: Array = _callout_queue.pop_front()
	_callout.text = c[0]
	_callout.add_theme_color_override("font_color", c[1])
	Kit.place(_callout, c[2])
	_callout.pivot_offset = _callout.size / 2
	var sec := T.t(T.CALLOUT)
	var tw := create_tween()
	tw.tween_property(_callout, "modulate:a", 1.0, sec * 0.2)
	tw.parallel().tween_property(_callout, "scale", Vector2.ONE * 1.1, sec * 0.2).from(Vector2.ONE * 0.8)
	tw.tween_property(_callout, "scale", Vector2.ONE, sec * 0.1)
	tw.tween_interval(sec * 0.4)
	tw.tween_property(_callout, "modulate:a", 0.0, sec * 0.3)
	tw.tween_callback(_next_callout)
