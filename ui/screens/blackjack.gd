# ブラックジャックの卓(追補 1 §6.1・§7.3)。上にディーラー、下にプレイヤーの札と合計を並べ、ヒット・スタンド・ダブルを受ける。
# 勝ち負けと戻りは core/bj_rules.gd が決め、ここは決まった結果を順に見せるだけにする(INV-1)。
extends "res://ui/screens/casino_table.gd"

const Rules := preload("res://core/bj_rules.gd")

const SOUNDS := {"natural": "bank", "win": "hit_2", "push": "tap", "lose": "miss", "bust": "miss"}

var hand
# 札の部品。配る順に入れ、順番が来るまで見せない
var rows := {"dealer": [], "player": []}
var caps := {}
var totals := {}


func _game() -> String:
	return "bj"


func _game_title() -> String:
	return S.BTN_BJ


func _actions() -> Array:
	return [["hit", S.BTN_HIT, [KEY_H]], ["stand", S.BTN_STAND, [KEY_S]], ["double", S.BTN_DOUBLE, [KEY_D]]]


# E-A3: ダブルに足りなければ押せない。
func _action_enabled(key: String) -> bool:
	return hand != null and not hand.done and (key != "double" or hand.can_double(save.data["casino"]["wallet"]))


func _build_table() -> void:
	for who in rows:
		caps[who] = Kit.label(S.DEALER if who == "dealer" else S.PLAYER, T.FS_SMALL, T.W_BODY, T.TEXT_DIM)
		add_child(caps[who])
		totals[who] = Kit.num_label("", T.FS_SCORE, T.TEXT)
		add_child(totals[who])


func _layout_table(r: Dictionary) -> void:
	for who in rows:
		Kit.place(caps[who], r["bj_%s_cap" % who])
		Kit.place(totals[who], r["bj_%s_total" % who])
		# 縦長は札のすぐ上に置くので、字を一回り小さくして札に掛からないようにする
		totals[who].add_theme_font_size_override("font_size", T.FS_SCORE if landscape else T.FS_HEAD)
		_fan(who)


# 見えている札を、帯の中央に並べ直す。
func _fan(who: String) -> void:
	var r := L.rects(landscape)
	var shown: Array = rows[who].filter(func(c): return c.visible)
	for i in shown.size():
		Kit.place(shown[i], L.fan(r["bj_" + who], r["bj_card"], shown.size(), i))


# FR-A16: 表になっている札だけを数える(ディーラーの裏の札は、開けるまで合計に入れない)。
func _update_totals() -> void:
	for who in rows:
		var up: Array = rows[who].filter(func(c): return c.visible and c.face_up).map(func(c): return c.card)
		totals[who].text = "" if up.is_empty() else str(Rules.total(up))


func _start(cards: PackedInt32Array) -> void:
	for who in rows:
		for c in rows[who]:
			c.queue_free()
		rows[who].clear()
	_update_totals()
	hand = Rules.new(cards, bet)
	for i in 2:
		_queue("player", hand.player[i], true)
		_queue("dealer", hand.dealer[i], i == 0)
	_continue()


func _on_action(key: String) -> void:
	var before: int = hand.player.size()
	match key:
		"hit":
			hand.hit()
		"stand":
			hand.stand()
		"double":
			# FR-A13: 同じ点をもう 1 回引いて保存してから、1 枚だけ引く
			save.casino_pay(hand.bet)
			_show_wallet()
			_show_delta(-hand.bet)
			hand.double_down()
			stake = hand.bet
	for i in range(before, hand.player.size()):
		_queue("player", hand.player[i], true)
	_continue()


# 札を 1 枚、動きの列に足す。
func _queue(who: String, card: int, up: bool, gap: float = T.TABLE_GAP) -> void:
	var c := Card.new()
	c.visible = false
	c.show_card(card, up)
	add_child(c)
	rows[who].append(c)
	tw.tween_interval(T.t(gap))
	tw.tween_callback(_show.bind(c, who))
	if not T.lite:
		tw.tween_property(c, "scale:x", 1.0, T.t(T.DEAL))


func _show(c: Control, who: String) -> void:
	c.visible = true
	if not T.lite:
		c.scale.x = 0.0
	_fan(who)
	_update_totals()
	app.sfx.play("flip")


# 勝負が付いていれば結果までを、付いていなければ次の操作を待つ所までを、動きの列に足す。
func _continue() -> void:
	if not hand.done:
		tw.tween_callback(_idle)
		return
	# 結果が決まった時点で保存する(動きの途中で閉じても、戻りは残る)
	var won := 1 if hand.result in ["natural", "win"] else 0
	save.casino_settle(hand.returned, {"bj_hands": 1, "bj_wins": won, "bj_naturals": 1 if hand.result == "natural" else 0})
	# FR-A12: バーストでは、ディーラーは裏の札を開けず、引かない
	if hand.result != "bust":
		var hole: Control = rows["dealer"][1]
		tw.tween_interval(T.t(T.DEALER_GAP))
		if not T.lite:
			tw.tween_property(hole, "scale:x", 0.0, T.t(T.FLIP) / 2)
		tw.tween_callback(_open_hole)
		if not T.lite:
			tw.tween_property(hole, "scale:x", 1.0, T.t(T.FLIP) / 2)
		for i in range(2, hand.dealer.size()):
			_queue("dealer", hand.dealer[i], true, T.DEALER_GAP)
	tw.tween_interval(T.t(T.TABLE_GAP))
	tw.tween_callback(_finish)


func _open_hole() -> void:
	rows["dealer"][1].show_card(hand.dealer[1], true)
	_update_totals()
	app.sfx.play("flip")


func _finish() -> void:
	var r: String = hand.result
	_end(S.BJ_RESULTS[r], T.GOOD if r in ["natural", "win"] else T.TEXT if r == "push" else T.BAD, SOUNDS[r], hand.returned)
