# 実績の通知(FR-17・§9.1・画面設計書 §2.4)。真鍮色の枠に「実績を達成」と実績の名前を出す。
# 同時に 1 つだけ出し、重なったら順に出す。待ちが 4 つを超えた分は出さない(結果画面の一覧には出る。E-19)。
extends Control

signal shown

const S := preload("res://core/strings.gd")
const T := preload("res://ui/theme/tokens.gd")
const Kit := preload("res://ui/kit.gd")

const QUEUE_MAX := 4

var queue: Array[String] = []
var busy := false
var _panel: Panel
var _name: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_panel = Kit.panel(Color(T.BG_DEEP, 0.95), 14, T.BRASS, 2)
	_panel.visible = false
	add_child(_panel)
	var head := Kit.label(S.TOAST_HEAD, T.FS_SMALL, T.W_BODY, T.BRASS_HI)
	head.name = "head"
	_panel.add_child(head)
	_name = Kit.label("", T.FS_SMALL + 2, T.W_NUM, T.TEXT)
	_panel.add_child(_name)
	resized.connect(_on_resized)
	_on_resized()


func _on_resized() -> void:
	_panel.size = size
	_panel.get_node("head").position = Vector2(0, 4)
	_panel.get_node("head").size = Vector2(size.x, size.y * 0.45)
	_name.position = Vector2(0, size.y * 0.42)
	_name.size = Vector2(size.x, size.y * 0.5)


func push(achievement_name: String) -> void:
	if queue.size() >= QUEUE_MAX:
		return
	queue.append(achievement_name)
	if not busy:
		_next()


func _next() -> void:
	if queue.is_empty():
		busy = false
		_panel.visible = false
		return
	busy = true
	_name.text = queue.pop_front()
	_panel.visible = true
	_panel.position.y = -size.y
	_panel.modulate.a = 1.0
	shown.emit()
	var tw := create_tween()
	tw.tween_property(_panel, "position:y", 0.0, T.TOAST_IN).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(T.TOAST_STAY)
	tw.tween_property(_panel, "position:y", -size.y, T.TOAST_OUT)
	tw.parallel().tween_property(_panel, "modulate:a", 0.0, T.TOAST_OUT)
	tw.tween_callback(_next)
