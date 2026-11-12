# ブラックジャック 1 回の勝負(追補 1 §6.1)。札の合計、配り、ヒット・スタンド・ダブル、ディーラーの引き、戻りを決める。
# 画面と保存は持たない。山札の並びは呼ぶ側が渡す(本番は core/deck.gd の shuffled、テストは決めた並び)。
extends RefCounted

const B := preload("res://core/balance.gd")
const Deck := preload("res://core/deck.gd")

var deck: PackedInt32Array
var pos := 0
# 賭けた点(ダブルの後は 2 倍)
var bet := 0
var player: Array[int] = []
var dealer: Array[int] = []
var done := false
# "natural" "win" "push" "lose" "bust"(勝負の途中は空)
var result := ""
var returned := 0


# {total, soft}。soft は、11 と数えている A が残っているとき真。
static func value(cards: Array) -> Dictionary:
	var sum := 0
	var aces := 0
	for c in cards:
		var r := Deck.rank(c)
		if r == 1:
			aces += 1
			sum += 11
		else:
			sum += mini(r, 10)
	while sum > 21 and aces > 0:
		sum -= 10
		aces -= 1
	return {"total": sum, "soft": aces > 0}


static func total(cards: Array) -> int:
	return value(cards)["total"]


# 配る順は、プレイヤー、ディーラー、プレイヤー、ディーラー(FR-A10)。どちらかが 21 ならすぐ勝負が付く(FR-A11)。
func _init(cards: PackedInt32Array, bet_points: int) -> void:
	deck = cards
	bet = bet_points
	for i in 2:
		player.append(_next())
		dealer.append(_next())
	var p := total(player) == 21
	var d := total(dealer) == 21
	if p or d:
		_settle("push" if p and d else "natural" if p else "lose")


func _next() -> int:
	pos += 1
	return deck[pos - 1]


# wallet は、最初の賭けを引いた後の持ち点(FR-A13)。
func can_double(wallet: int) -> bool:
	return not done and player.size() == 2 and wallet >= bet


func hit() -> void:
	if done:
		return
	player.append(_next())
	var t := total(player)
	if t > 21:
		_settle("bust")
	elif t == 21:
		stand()


func stand() -> void:
	if done:
		return
	while total(dealer) < B.BJ_DEALER_STAND:
		dealer.append(_next())
	var p := total(player)
	var d := total(dealer)
	_settle("win" if d > 21 or p > d else "push" if p == d else "lose")


# 呼ぶ側が can_double を確かめ、賭けた点をもう 1 回引いてから呼ぶ。
func double_down() -> void:
	if done or player.size() != 2:
		return
	bet *= 2
	player.append(_next())
	if total(player) > 21:
		_settle("bust")
	else:
		stand()


@warning_ignore("integer_division")
func _settle(r: String) -> void:
	done = true
	result = r
	if r == "natural":
		returned = bet * B.BJ_NATURAL_NUM / B.BJ_NATURAL_DEN
	elif r == "win":
		returned = bet * 2
	elif r == "push":
		returned = bet
