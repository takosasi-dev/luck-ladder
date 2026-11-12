# ライフの丸 4 個(§9.1・画面設計書 §2.4)。失うと中が抜けて小さくなり、戻ると満ちて輪が 1 つ広がる。
# 残り 1 個のとき、残った丸が 1.2 秒周期で明滅する。色だけに頼らず、形(塗りと大きさ)で残りが分かる。
extends Control

const B := preload("res://core/balance.gd")
const T := preload("res://ui/theme/tokens.gd")

var lives := B.LIVES_MAX
var _fill: Array[float] = []
var _ring_at := -1
var _ring_t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in B.LIVES_MAX:
		_fill.append(1.0)


# tw を渡すと動きを足す(渡さなければ、その場で最後の状態にする)。
func set_lives(n: int, tw: Tween = null) -> void:
	var gained := n > lives
	lives = n
	for i in B.LIVES_MAX:
		var target := 1.0 if i < n else 0.0
		if tw == null:
			_fill[i] = target
		elif _fill[i] != target:
			tw.parallel().tween_method(_set_fill.bind(i), _fill[i], target, T.t(T.LIFE_GAIN if gained else T.LIFE_LOSE))
	if tw != null and gained:
		_ring_at = n - 1
		tw.parallel().tween_method(_set_ring, 0.0, 1.0, T.t(T.LIFE_GAIN))
	set_process(n == 1)
	queue_redraw()


func _set_fill(v: float, i: int) -> void:
	_fill[i] = v
	queue_redraw()


func _set_ring(v: float) -> void:
	_ring_t = v
	if v >= 1.0:
		_ring_at = -1
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


func center_of(i: int) -> Vector2:
	var d := clampf(size.y * 0.32, 18.0, 26.0)
	var gap := d * 0.4
	var total := B.LIVES_MAX * d + (B.LIVES_MAX - 1) * gap
	return Vector2(size.x - total + d / 2 + i * (d + gap), size.y / 2)


func _draw() -> void:
	var d := clampf(size.y * 0.32, 18.0, 26.0)
	var blink := 1.0
	if lives == 1:
		blink = 0.72 + 0.28 * cos(Time.get_ticks_msec() / 1200.0 * TAU)
	for i in B.LIVES_MAX:
		var f := _fill[i]
		var c := center_of(i)
		var rad := d / 2 * lerpf(0.8, 1.0, f)
		var a := lerpf(0.45, 1.0, f) * (blink if f > 0.5 else 1.0)
		if f > 0.02:
			draw_circle(c, rad + 4, Color(T.BRASS_HI, 0.22 * f * a), true, -1.0, true)
			draw_circle(c, rad, Color(T.BRASS_HI, f * a), true, -1.0, true)
		draw_circle(c, rad, Color(T.BRASS, a), false, 2.0, true)
	if _ring_at >= 0:
		draw_circle(center_of(_ring_at), d / 2 + 22 * _ring_t, Color(T.BRASS_HI, 1.0 - _ring_t), false, 2.5, true)
