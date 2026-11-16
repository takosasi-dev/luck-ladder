# ダブルアップ(追補 2 §7・§9.5)。表の札 1 枚に対して、次の札が大きいか小さいかを 1 回当てる。
# 戻り = 賭けた点 × (残り 51 枚 − 表と同じ数字の枚数) ÷ 当たる枚数(切り捨て)。同じ数字なら賭けた点が戻る。平均の戻りは賭けた点と釣り合う。
extends RefCounted

const Deck := preload("res://core/deck.gd")

var deck := PackedInt32Array()
var stake := 0
var shown_rank := 0
# "" / "hit" / "same" / "miss"
var result := ""
var returned := 0


func _init(cards: PackedInt32Array, stake_points: int) -> void:
	deck = cards
	stake = stake_points
	shown_rank = Deck.rank(deck[0])


func shown_card() -> int:
	return deck[0]


# 残り 51 枚のうち、表より大きい(H)・小さい(L)札の枚数。
func winners(side: String) -> int:
	var n := 0
	for i in range(1, Deck.SIZE):
		var r := Deck.rank(deck[i])
		if (side == "H" and r > shown_rank) or (side == "L" and r < shown_rank):
			n += 1
	return n


func same_count() -> int:
	var n := 0
	for i in range(1, Deck.SIZE):
		if Deck.rank(deck[i]) == shown_rank:
			n += 1
	return n


# 当たったときの戻り。当たる札が無い側は 0(押せない)。
@warning_ignore("integer_division")
func quote(side: String) -> int:
	var w := winners(side)
	if w == 0:
		return 0
	return stake * (Deck.SIZE - 1 - same_count()) / w


# 結果: {result: "hit"/"same"/"miss"/"invalid", card, returned}
func play(side: String) -> Dictionary:
	if result != "" or not side in ["H", "L"] or quote(side) == 0:
		return {"result": "invalid", "card": -1, "returned": 0}
	var q := quote(side)
	var nx := Deck.rank(deck[1])
	if nx == shown_rank:
		result = "same"
		returned = stake
	elif (side == "H" and nx > shown_rank) or (side == "L" and nx < shown_rank):
		result = "hit"
		returned = q
	else:
		result = "miss"
		returned = 0
	return {"result": result, "card": deck[1], "returned": returned}
