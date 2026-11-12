# ビデオポーカーの卓(追補 1 §6.2・§7.4)。札 5 枚と配当表を並べ、残す札の選択と 1 回の交換を受ける。
# 役と戻りは core/poker_rules.gd が決め、ここは決まった結果を順に見せるだけにする(INV-1)。
extends "res://ui/screens/casino_table.gd"

const Rules := preload("res://core/poker_rules.gd")

const HOLD_KEYS := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5]
const HOLD_LIFT := 12.0
# 役の番号 → 効果音
const SOUNDS := ["miss", "hit_1", "hit_1", "hit_2", "hit_2", "hit_2", "hit_3", "hit_3", "clear", "clear"]

var hand
var holds: Array[int] = []
var cards: Array = []
var hold_marks: Array = []
# 札の上に重ねる、見えない当たり
var hits: Array = []
var pay_mark: Panel
# 役の番号 → [名前, 倍率] のラベル。番号 0(役なし)の行は無い
var pay_rows: Array = [[]]
var marked := 0


func _game() -> String:
	return "pk"


func _game_title() -> String:
	return S.BTN_POKER


func _actions() -> Array:
	return [["draw", S.BTN_DRAW, DEAL_KEYS]]


func _action_enabled(_key: String) -> bool:
	return hand != null and not hand.done


func _build_table() -> void:
	pay_mark = Kit.panel(Color(T.BRASS, 0.18), 10, T.BRASS_HI, 2)
	pay_mark.visible = false
	add_child(pay_mark)
	for rank in range(1, S.POKER_HANDS.size()):
		var name_l := Kit.label(S.POKER_HANDS[rank], T.FS_SMALL, T.W_BODY, T.TEXT_DIM)
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		add_child(name_l)
		var pay_l := Kit.label(S.PAY_TIMES % B.POKER_PAYS[rank], T.FS_SMALL, T.W_NUM, T.TEXT_DIM)
		pay_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		add_child(pay_l)
		pay_rows.append([name_l, pay_l])
	for i in Rules.HAND_SIZE:
		var c := Card.new()
		c.visible = false
		add_child(c)
		cards.append(c)
		var m := Kit.label(S.HOLD, T.FS_SMALL, T.W_NUM, T.BRASS_HI)
		m.visible = false
		add_child(m)
		hold_marks.append(m)
	for i in Rules.HAND_SIZE:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		for s in ["normal", "hover", "pressed", "focus", "disabled"]:
			b.add_theme_stylebox_override(s, StyleBoxEmpty.new())
		b.pressed.connect(_toggle.bind(i))
		add_child(b)
		hits.append(b)


# 配当表は、上の行ほど良い役。
func _layout_table(r: Dictionary) -> void:
	Kit.place(message, r["pk_message"])
	var pays: Rect2 = r["pk_pays"]
	var rows := pay_rows.size() - 1
	var h := pays.size.y / rows
	for rank in range(1, pay_rows.size()):
		var row := Rect2(pays.position.x + 14, pays.position.y + (rows - rank) * h, pays.size.x - 28, h)
		for l in pay_rows[rank]:
			Kit.place(l, row)
	_place_cards()
	_mark(marked)


# §7.4: 残す札は 12 px 上にずらし、その上に「残す」の字を出す。
func _place_cards() -> void:
	var r := L.rects(landscape)
	for i in cards.size():
		var at := L.fan(r["pk_cards"], r["pk_card"], cards.size(), i)
		Kit.place(hits[i], at)
		Kit.place(hold_marks[i], Rect2(at.position.x, at.position.y - 50, at.size.x, 36))
		hold_marks[i].visible = i in holds
		if i in holds:
			at.position.y -= HOLD_LIFT
		Kit.place(cards[i], at)


# FR-A24: 今できている役の行を光らせる。役なし(0)では、どの行も光らせない。
func _mark(rank: int) -> void:
	marked = rank
	pay_mark.visible = rank > 0
	for i in range(1, pay_rows.size()):
		for l in pay_rows[i]:
			l.add_theme_color_override("font_color", T.BRASS_HI if i == rank else T.TEXT_DIM)
	if rank > 0:
		var row: Label = pay_rows[rank][0]
		Kit.place(pay_mark, Rect2(row.position, row.size).grow_individual(10, -2, 10, -2))


func _start(shuffled: PackedInt32Array) -> void:
	hand = Rules.new(shuffled, bet)
	holds.clear()
	_mark(0)
	for c in cards:
		c.visible = false
	_place_cards()
	for i in cards.size():
		tw.tween_interval(T.t(T.POKER_GAP))
		tw.tween_callback(_show.bind(i))
		if not T.lite:
			tw.tween_property(cards[i], "scale:x", 1.0, T.t(T.DEAL))
	tw.tween_callback(_after_deal)


# i 枚目に、今の手札の札を出す(配るときと、交換で入れ替えるとき)。
func _show(i: int) -> void:
	cards[i].show_card(hand.cards[i], true)
	cards[i].visible = true
	if not T.lite:
		cards[i].scale.x = 0.0
	app.sfx.play("flip")


func _after_deal() -> void:
	_mark(Rules.evaluate(hand.cards))
	_idle()


# FR-A21: 札を押すたびに、残す・外すを切り替える。
func _toggle(i: int) -> void:
	if phase != "play" or hand == null or hand.done or not _accept():
		return
	if i in holds:
		holds.erase(i)
	else:
		holds.append(i)
	_place_cards()


func _extra_key(keycode: int) -> bool:
	if phase != "play" or not keycode in HOLD_KEYS:
		return false
	_toggle(HOLD_KEYS.find(keycode))
	return true


# 「交換」。勝負の段階のボタンはこれだけ。
func _on_action(_key: String) -> void:
	var kept := holds.duplicate()
	hand.draw(kept)
	holds.clear()
	_place_cards()
	# 結果が決まった時点で保存する(動きの途中で閉じても、戻りは残る)。pk_best は、今までの最高との差を足して最高の値にする
	var rank: int = hand.hand_rank
	var best: int = save.data["casino"]["pk_best"]
	save.casino_settle(hand.returned, {"pk_hands": 1, "pk_paid": 1 if rank > 0 else 0, "pk_best": maxi(rank - best, 0)})
	for i in cards.size():
		if i in kept:
			continue
		tw.tween_interval(T.t(T.POKER_GAP))
		if not T.lite:
			tw.tween_property(cards[i], "scale:x", 0.0, T.t(T.FLIP) / 2)
		tw.tween_callback(_show.bind(i))
		if not T.lite:
			tw.tween_property(cards[i], "scale:x", 1.0, T.t(T.FLIP) / 2)
	tw.tween_interval(T.t(T.TABLE_GAP))
	tw.tween_callback(_finish)


func _finish() -> void:
	var rank: int = hand.hand_rank
	_mark(rank)
	_end(S.POKER_HANDS[rank], T.GOOD if rank > 0 else T.BAD, SOUNDS[rank], hand.returned)
