# 保存データの重ね表示(FR-25・FR-26)。書き出し(選択できる欄とコピー)、読み込み(検査を通った物だけ、確かめてから上書き)、
# 消去(「消す」を 2 回。2 回目は別の位置のボタン)。確かめていない成功は出さない(INV-10)。
extends Control

signal closed
# データを丸ごと入れ替えた(読み込み・消去)。引数はタイトルに出す 1 行
signal replaced(message: String)

const S := preload("res://core/strings.gd")
const T := preload("res://ui/theme/tokens.gd")
const Kit := preload("res://ui/kit.gd")
const Codec := preload("res://core/save_codec.gd")

var app
var scrim: ColorRect
var sheet: Panel
var head: Label
var scroll: ScrollContainer
var rows: VBoxContainer
var note: Label
var import_box: TextEdit
var import_confirm: Button
var back: Button
var erase_confirm: Button


func setup(app_ref) -> void:
	app = app_ref


func _ready() -> void:
	scrim = ColorRect.new()
	scrim.color = T.SCRIM
	add_child(scrim)
	sheet = Kit.panel(Color(T.BG_DEEP, 0.92))
	add_child(sheet)
	head = Kit.label(S.SET_DATA, T.FS_HEAD, T.W_NUM)
	add_child(head)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	rows = VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 10)
	scroll.add_child(rows)
	note = Kit.label("", T.FS_SMALL, T.W_BODY, T.BRASS_HI)
	note.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	back = Kit.button(S.BTN_BACK, T.FS_BODY, "brass")
	back.pressed.connect(func(): closed.emit())
	add_child(back)
	# 消去の 2 回目は、1 回目とは別の位置(画面の下)に出す
	erase_confirm = Kit.button(S.BTN_ERASE_CONFIRM, T.FS_BODY, "ghost")
	erase_confirm.add_theme_color_override("font_color", T.BAD)
	erase_confirm.visible = false
	erase_confirm.pressed.connect(func():
		app.save.erase_all()
		replaced.emit(S.ERASE_DONE if app.save.writable else S.SAVE_UNAVAILABLE))
	add_child(erase_confirm)
	_fill()


func _section(text: String) -> void:
	var l := Kit.label(text, T.FS_SMALL, T.W_BODY, T.TEXT_DIM)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	rows.add_child(l)


func _action(text: String, kind: String, cb: Callable) -> Button:
	var b := Kit.button(text, T.FS_SMALL + 2, kind)
	b.custom_minimum_size = Vector2(300, 96)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(cb)
	rows.add_child(b)
	return b


func _fill() -> void:
	rows.add_child(note)
	_section(S.EXPORT_HEAD)
	var text: String = app.save.export_text()
	var out := Kit.text_box(text, false)
	out.custom_minimum_size = Vector2(0, 150)
	rows.add_child(out)
	_action(S.BTN_COPY, "green", func():
		DisplayServer.clipboard_set(text)
		note.text = S.COPY_TRIED)
	var hint := Kit.label(S.EXPORT_NOTE, T.FS_SMALL, T.W_BODY, T.TEXT_DIM)
	hint.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	rows.add_child(hint)
	_section(S.IMPORT_HEAD)
	import_box = Kit.text_box("", true, S.IMPORT_HINT)
	import_box.custom_minimum_size = Vector2(0, 150)
	rows.add_child(import_box)
	_action(S.BTN_IMPORT, "green", _check_import)
	import_confirm = _action(S.BTN_OVERWRITE, "ghost", _do_import)
	import_confirm.visible = false
	_section(S.ERASE_HEAD)
	var erase := _action(S.BTN_ERASE, "ghost", func(): erase_confirm.visible = true)
	erase.add_theme_color_override("font_color", T.BAD)


# 貼られた文字を検査する。通った場合だけ「今のデータを上書きします」と確かめる(E-8)。
func _check_import() -> void:
	var ok: bool = Codec.from_export(import_box.text)["ok"]
	import_confirm.visible = ok
	note.text = S.IMPORT_CONFIRM if ok else S.IMPORT_FAILED


func _do_import() -> void:
	if app.save.import_text(import_box.text):
		replaced.emit(S.IMPORT_DONE if app.save.writable else S.SAVE_UNAVAILABLE)
	else:
		import_confirm.visible = false
		note.text = S.IMPORT_FAILED


func relayout(landscape: bool, view: Rect2) -> void:
	var base := Vector2(1280, 720) if landscape else Vector2(720, 1280)
	Kit.place(self, Rect2(Vector2.ZERO, base))
	Kit.place(scrim, view)
	var w := 760.0 if landscape else 680.0
	var r := Rect2((base.x - w) / 2, 16, w, base.y - 32)
	if not landscape:
		r = Rect2((base.x - w) / 2, 150, w, 980)
	Kit.place(sheet, r)
	Kit.place(head, Rect2(r.position.x, r.position.y + 8, w, 56))
	Kit.place(scroll, Rect2(r.position.x + 28, r.position.y + 70, w - 56, r.size.y - 70 - 124))
	Kit.place(back, Rect2(r.position.x + 28, r.end.y - 112, 300, 96))
	Kit.place(erase_confirm, Rect2(r.end.x - 328, r.end.y - 112, 300, 96))
