# トライピークスの画面(追補 2 §8)。場 28 枚・表の札・山を並べ、押された札を core/tripeaks_rules.gd に渡して、結果を見せるだけ。
# 終わったら結果を重ねて出し、保存データの tripeaks を更新する(FR-P8)。途中でタイトルへ戻った回は記録しない(FR-P11)。
extends Control

signal back_pressed

const S := preload("res://core/strings.gd")
const T := preload("res://ui/theme/tokens.gd")
const Kit := preload("res://ui/kit.gd")
const Deck := preload("res://core/deck.gd")
const Rules := preload("res://core/tripeaks_rules.gd")
const ShareText := preload("res://core/share_text.gd")
const Card := preload("res://ui/parts/card.gd")

# 位置の数字(横長 1280×720 と縦長 720×1280)。tab は場の札の大きさ・列の間隔・段の間隔・左上
const LANDSCAPE := {
	"back": Rect2(14, 4, 150, 96), "name": Rect2(340, 4, 600, 56), "score_cap": Rect2(930, 4, 130, 56), "score": Rect2(1066, 4, 200, 56),
	"card": Vector2(100, 140), "step": 112.0, "row_dy": 62.0, "origin": Vector2(86, 110),
	"stock": Rect2(470, 480, 100, 140), "waste": Rect2(610, 480, 100, 140), "stock_label": Rect2(440, 624, 160, 34),
	"streak": Rect2(140, 520, 300, 56), "end": Rect2(290, 120, 700, 480),
}
const PORTRAIT := {
	"back": Rect2(14, 8, 150, 96), "name": Rect2(170, 8, 260, 96), "score_cap": Rect2(436, 8, 270, 36), "score": Rect2(436, 40, 270, 56),
	"card": Vector2(66, 92), "step": 70.0, "row_dy": 46.0, "origin": Vector2(12, 240),
	"stock": Rect2(170, 640, 140, 196), "waste": Rect2(410, 640, 140, 196), "stock_label": Rect2(150, 844, 180, 34),
	"streak": Rect2(0, 540, 720, 56), "end": Rect2(30, 300, 660, 600),
}
# 縦長でも、表になった札の当たりを縦に 96 以上にする(前提 B6。横幅は 66 のまま)
const HIT_MIN_H := 110.0

var app
var rules
var landscape := true
var cards: Array[Card] = []
var waste_card: Card
var stock_card: Card
var back: Button
var name_label: Label
var score_cap: Label
var score_num: Label
var stock_label: Label
var streak_label: Label
var end_layer: Control
var end_box: VBoxContainer
var last_input_frame := -1
var recorded := false


func setup(app_ref) -> void:
	app = app_ref


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	back = Kit.button(S.BTN_BACK, T.FS_SMALL + 2, "ghost")
	back.pressed.connect(func(): back_pressed.emit())
	add_child(back)
	name_label = Kit.label(S.BTN_TRIPEAKS, T.FS_HEAD, T.W_NUM)
	add_child(name_label)
	score_cap = Kit.label(S.TP_SCORE, T.FS_SMALL, T.W_BODY, T.TEXT_DIM)
	add_child(score_cap)
	score_num = Kit.num_label("0", T.FS_SCORE, T.BRASS_HI)
	add_child(score_num)
	for i in Rules.TABLEAU:
		var c := Card.new()
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(c)
		cards.append(c)
	stock_card = Card.new()
	stock_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stock_card)
	waste_card = Card.new()
	waste_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(waste_card)
	stock_label = Kit.label("", T.FS_SMALL, T.W_BODY, T.TEXT_DIM)
	add_child(stock_label)
	streak_label = Kit.label("", T.FS_BODY, T.W_NUM, T.BRASS_HI)
	add_child(streak_label)
	end_layer = Control.new()
	end_layer.visible = false
	add_child(end_layer)
	app.bgm.play("bgm_play")
	_new_game()


# テストは、決めた並びを返すように上書きする。
func _new_deck() -> PackedInt32Array:
	return Deck.shuffled("LLT:%d:%d" % [int(Time.get_unix_time_from_system()), Time.get_ticks_usec()])


func _new_game() -> void:
	rules = Rules.new(_new_deck())
	recorded = false
	end_layer.visible = false
	_refresh()


func relayout(is_landscape: bool, _view: Rect2) -> void:
	landscape = is_landscape
	size = Vector2(1280, 720) if landscape else Vector2(720, 1280)
	var r := _rects()
	name_label.add_theme_font_size_override("font_size", T.FS_HEAD if landscape else T.FS_BODY)
	for key in ["back", "name", "score_cap", "score", "stock_label", "streak"]:
		Kit.place({"back": back, "name": name_label, "score_cap": score_cap, "score": score_num, "stock_label": stock_label, "streak": streak_label}[key], r[key])
	for i in cards.size():
		Kit.place(cards[i], card_rect(i))
	Kit.place(stock_card, r["stock"])
	Kit.place(waste_card, r["waste"])
	if end_layer.visible:
		_show_end()
	_refresh()


func _rects() -> Dictionary:
	return LANDSCAPE if landscape else PORTRAIT


# 場の札 i の位置(§9.4 の図): いちばん下の段は列の位置、上の段は重なる 2 枚の真ん中。
func card_rect(i: int) -> Rect2:
	var r := _rects()
	var row := Rules.row_of(i)
	var x := _col_x(i)
	return Rect2(r["origin"] + Vector2(x * r["step"], row * r["row_dy"]), r["card"])


# 列の位置(いちばん下の段の札の幅を 1 とした数。上の段は 0.5 ずつずれる)
func _col_x(i: int) -> float:
	var row := Rules.row_of(i)
	if row == 3:
		return float(i - Rules.ROW_START[3])
	var under: Array = Rules.covered_by(i)
	return (_col_x(under[0]) + _col_x(under[1])) / 2.0


# 表になった札の当たり。下の重なりはもう取られているので、縦に広げてよい。
func hit_rect(i: int) -> Rect2:
	var cr := card_rect(i)
	return Rect2(cr.position, Vector2(cr.size.x, maxf(cr.size.y, HIT_MIN_H)))


func _refresh() -> void:
	for i in cards.size():
		cards[i].visible = not rules.removed[i]
		cards[i].show_card(rules.tableau[i], rules.is_open(i))
	waste_card.show_card(rules.waste, true)
	stock_card.visible = rules.stock_left() > 0
	stock_card.show_card(-1, false)
	stock_label.text = S.TP_STOCK % rules.stock_left()
	streak_label.text = S.TP_STREAK % rules.streak if rules.streak > 0 else ""
	score_num.text = ShareText.group(rules.score)


# 同じフレームに届いた 2 つ目からの入力は捨てる(E-B7)。
func _accept() -> bool:
	var f := Engine.get_process_frames()
	if f == last_input_frame or rules.ended != "":
		return false
	last_input_frame = f
	return true


func take(i: int) -> void:
	if not rules.can_take(i) or not _accept():
		return
	var res: Dictionary = rules.take(i)
	app.sfx.play("hit_2" if res["peak"] else "hit_1")
	_after_move()


func draw_stock() -> void:
	if rules.stock_left() == 0 or not _accept():
		return
	rules.draw()
	app.sfx.play("flip")
	_after_move()


func _after_move() -> void:
	_refresh()
	if rules.ended != "":
		_finish()


# FR-P7・FR-P8: 終わったら記録して、結果を重ねて出す。
func _finish() -> void:
	if not recorded:
		recorded = true
		app.save.tripeaks_finish(rules.score, rules.ended == "clear")
	app.sfx.play("clear" if rules.ended == "clear" else "gameover")
	_show_end()


func _show_end() -> void:
	for c in end_layer.get_children():
		c.queue_free()
	end_layer.visible = true
	Kit.place(end_layer, Rect2(Vector2.ZERO, size))
	var er: Rect2 = _rects()["end"]
	var sheet := Kit.panel(Color(T.BG_DEEP, 0.94))
	end_layer.add_child(sheet)
	Kit.place(sheet, er)
	end_box = VBoxContainer.new()
	end_box.alignment = BoxContainer.ALIGNMENT_CENTER
	end_box.add_theme_constant_override("separation", 14)
	end_layer.add_child(end_box)
	end_box.add_child(Kit.label(S.TP_RESULTS[rules.ended], T.FS_BODY + 4, T.W_NUM, T.GOOD if rules.ended == "clear" else T.BRASS))
	end_box.add_child(Kit.num_label(ShareText.group(rules.score), 72, T.BRASS_HI))
	end_box.add_child(Kit.label(S.TP_TAKEN + "  " + str(rules.taken) + "   " + S.TP_BEST_STREAK + "  " + str(rules.best_streak), T.FS_SMALL, T.W_BODY, T.TEXT))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	end_box.add_child(row)
	var again := Kit.button(S.BTN_RETRY, T.FS_BODY, "brass")
	again.custom_minimum_size = Vector2(240, 96)
	again.pressed.connect(_new_game)
	row.add_child(again)
	var to_title := Kit.button(S.BTN_TO_TITLE, T.FS_BODY, "green")
	to_title.custom_minimum_size = Vector2(240, 96)
	to_title.pressed.connect(func(): back_pressed.emit())
	row.add_child(to_title)
	# 縦の枠は端の位置で置く(折り返しのある中身でも、幅が決まる前の背の高さで固まらないように)
	end_box.offset_left = er.position.x + 20
	end_box.offset_right = er.end.x - 20
	end_box.offset_top = er.position.y + 20
	end_box.offset_bottom = er.end.y - 20


func _unhandled_input(event: InputEvent) -> void:
	if end_layer.visible:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			back_pressed.emit()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			draw_stock()
		elif event.keycode == KEY_ESCAPE:
			back_pressed.emit()
		else:
			return
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var p: Vector2 = get_global_transform().affine_inverse() * event.position
		if _rects()["stock"].has_point(p):
			draw_stock()
			get_viewport().set_input_as_handled()
			return
		for i in Rules.TABLEAU:
			if rules.is_open(i) and hit_rect(i).has_point(p):
				take(i)
				get_viewport().set_input_as_handled()
				return
