# 一覧の画面(実績・記録・コレクション)の共通の骨組み。戻るボタン・見出し・右上の数字・スクロールする中身を持つ。
# それぞれの画面は _title と _fill を上書きして、body に中身を足す。
extends Control

signal back_pressed

const S := preload("res://core/strings.gd")
const T := preload("res://ui/theme/tokens.gd")
const Kit := preload("res://ui/kit.gd")

var app
var back: Button
var head: Label
var side: Label
var scroll: ScrollContainer
var body: VBoxContainer
var landscape := true


func setup(app_ref) -> void:
	app = app_ref


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	back = Kit.button(S.BTN_BACK, T.FS_SMALL + 2, "ghost")
	back.pressed.connect(func(): back_pressed.emit())
	add_child(back)
	head = Kit.label(_title(), T.FS_HEAD, T.W_NUM)
	add_child(head)
	side = Kit.num_label("", T.FS_BODY + 4, T.BRASS_HI)
	side.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(side)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	scroll.add_child(body)


func _title() -> String:
	return ""


func _fill() -> void:
	pass


# 中身の幅(スクロールバーのぶんを引いた値)。
func inner_width() -> float:
	return size.x - 28 - 14


func refill() -> void:
	for c in body.get_children():
		body.remove_child(c)
		c.queue_free()
	_fill()


func section(text: String) -> void:
	var l := Kit.label(text, T.FS_SMALL, T.W_BODY, T.TEXT_DIM)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	body.add_child(l)


func grid(columns: int) -> GridContainer:
	var g := GridContainer.new()
	g.columns = columns
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 10)
	body.add_child(g)
	return g


func relayout(is_landscape: bool, _view: Rect2) -> void:
	landscape = is_landscape
	size = Vector2(1280, 720) if landscape else Vector2(720, 1280)
	Kit.place(back, Rect2(14, 8, 150, 96))
	Kit.place(head, Rect2(170, 8, size.x - 340, 96))
	Kit.place(side, Rect2(size.x - 184, 8, 170, 96))
	Kit.place(scroll, Rect2(14, 112, size.x - 28, size.y - 126))
	refill()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		back_pressed.emit()
