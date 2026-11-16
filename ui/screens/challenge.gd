# 挑戦状の画面(追補 2 FR-C4)。?c= の URL で開かれたとき、送った人の名前と得点を見せ、「はじめる」か「タイトルへ」を選ばせる。
# コードの検査は core/challenge_codec.gd が済ませてある。読めなかったときは断りと「タイトルへ」だけ。
extends Control

signal start_pressed
signal title_pressed

const S := preload("res://core/strings.gd")
const T := preload("res://ui/theme/tokens.gd")
const Kit := preload("res://ui/kit.gd")
const ShareText := preload("res://core/share_text.gd")

var app
var info := {}
var sheet: Panel
var box: VBoxContainer
var used := false


# challenge は ChallengeCodec.decode の結果。
func setup(app_ref, challenge: Dictionary) -> void:
	app = app_ref
	info = challenge


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet = Kit.panel(Color(T.BG_DEEP, 0.8))
	add_child(sheet)
	box = VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	add_child(box)
	box.add_child(Kit.label(S.CHALLENGE_HEAD, T.FS_HEAD, T.W_NUM, T.BRASS))
	if info.get("error", "bad") == "":
		_wrap(S.CHALLENGE_VS % [info["name"], ShareText.group(info["state"].score)], T.FS_BODY + 4, T.BRASS_HI)
		_wrap(S.CHALLENGE_NOTE, T.FS_SMALL, T.TEXT_DIM)
		_button(S.BTN_START, "brass", start_pressed)
	else:
		_wrap(S.CHALLENGE_BAD, T.FS_BODY, T.TEXT)
	_button(S.BTN_TO_TITLE, "green", title_pressed)


func _wrap(text: String, font_size: int, color: Color) -> void:
	var l := Kit.label(text, font_size, T.W_BODY, color)
	l.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	box.add_child(l)


func _button(text: String, kind: String, sig: Signal) -> void:
	var b := Kit.button(text, T.FS_BODY + 4, kind)
	b.custom_minimum_size = Vector2(0, 100)
	b.pressed.connect(func():
		# 二度押しで 2 回始めない
		if not used:
			used = true
			sig.emit())
	box.add_child(b)


func relayout(landscape: bool, _view: Rect2) -> void:
	size = Vector2(1280, 720) if landscape else Vector2(720, 1280)
	var w := 700.0 if landscape else 660.0
	var h := 520.0
	var r := Rect2((size.x - w) / 2, (size.y - h) / 2, w, h)
	Kit.place(sheet, r)
	# 折り返すラベルを入れた縦の枠は、size でなく端の位置で置く(幅が決まる前の背の高さで固まらないように)
	box.offset_left = r.position.x + 40
	box.offset_right = r.end.x - 40
	box.offset_top = r.position.y + 30
	box.offset_bottom = r.end.y - 30
