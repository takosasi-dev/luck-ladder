# 山札(画面設計書 §2.4)。裏向きの札を 3 枚、左上へ 3 px ずつずらして重ねる。
# 残り 2 枚で 2 枚重ね、1 枚で 1 枚、0 枚で枠だけにする。
extends Control

const T := preload("res://ui/theme/tokens.gd")
const Kit := preload("res://ui/kit.gd")
const Card := preload("res://ui/parts/card.gd")

var left := 51


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_left(n: int) -> void:
	if n != left:
		left = n
		queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var layers := mini(3, left)
	if layers == 0:
		Kit.draw_outline(self, r, T.R_CARD, Color(T.IVORY, 0.3), 2)
		return
	draw_style_box(Kit.box(T.IVORY, T.R_CARD, Color(0, 0, 0, 0), 0, true), r)
	# 下の札から描く。いちばん上の札がずれ 0
	for k in range(layers - 1, -1, -1):
		Card.draw_back(self, Rect2(Vector2(-3, -3) * k, size))
