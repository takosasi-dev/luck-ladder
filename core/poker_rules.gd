# ビデオポーカー 1 回の勝負(追補 1 §6.2・§6.3)。5 枚の配り、残す札を選んだ後の交換、役の判定、戻りを決める。
# 画面と保存は持たない。山札の並びは呼ぶ側が渡す(本番は core/deck.gd の shuffled、テストは決めた並び)。
extends RefCounted

const B := preload("res://core/balance.gd")
const Deck := preload("res://core/deck.gd")

const HAND_SIZE := 5
# 役の番号(§8 の pk_best と同じ): 0 = 役なし、1 = J 以上のペア、2 = ツーペア、3 = スリーカード、4 = ストレート、
# 5 = フラッシュ、6 = フルハウス、7 = フォーカード、8 = ストレートフラッシュ、9 = ロイヤルフラッシュ
const ROYAL_RANKS := [1, 10, 11, 12, 13]

var deck: PackedInt32Array
var bet := 0
var cards: Array[int] = []
var done := false
var hand_rank := 0
var returned := 0


# 5 枚の役の番号。§6.3 の表を上の行から調べる。
static func evaluate(hand: Array) -> int:
	var counts := {}
	var ranks := []
	var flush := true
	for c in hand:
		var r := Deck.rank(c)
		counts[r] = counts.get(r, 0) + 1
		ranks.append(r)
		flush = flush and Deck.suit(c) == Deck.suit(hand[0])
	ranks.sort()
	# 同じ数字の枚数を小さい順に並べた形: フォーカードは [1, 4]、フルハウスは [2, 3]
	var groups: Array = counts.values()
	groups.sort()
	var royal: bool = ranks == ROYAL_RANKS
	# A は 1 として(A-2-3-4-5)か、K の次として(10-J-Q-K-A)だけ続く。K と A をまたぐ並びは続かない
	var straight: bool = groups.size() == HAND_SIZE and (ranks[4] - ranks[0] == 4 or royal)
	if straight and flush:
		return 9 if royal else 8
	if groups == [1, 4]:
		return 7
	if groups == [2, 3]:
		return 6
	if flush:
		return 5
	if straight:
		return 4
	if groups == [1, 1, 3]:
		return 3
	if groups == [1, 2, 2]:
		return 2
	for r in counts:
		if counts[r] == 2 and (r == 1 or r >= 11):
			return 1
	return 0


func _init(shuffled: PackedInt32Array, bet_points: int) -> void:
	deck = shuffled
	bet = bet_points
	for i in HAND_SIZE:
		cards.append(deck[i])


# FR-A22: holds(残す札の位置 0〜4)に無い札を、山札の 6 枚目から順に、左の札から入れ替える。交換は 1 回だけ。
func draw(holds: Array) -> void:
	if done:
		return
	var next := HAND_SIZE
	for i in HAND_SIZE:
		if not i in holds:
			cards[i] = deck[next]
			next += 1
	done = true
	hand_rank = evaluate(cards)
	returned = bet * B.POKER_PAYS[hand_rank]
