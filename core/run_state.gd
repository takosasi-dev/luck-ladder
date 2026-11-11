# 1 ランの進行(§9.4)。予想・確保・ポット・連続・ライフ・終了を、整数の計算だけで決める(INV-1・INV-2)。
# 画面はここの結果を受け取って見せるだけにする。次にめくる札を外に出さない(INV-4)。
extends RefCounted

const B := preload("res://core/balance.gd")
const Deck := preload("res://core/deck.gd")

const SIDES := ["H", "L", "S"]

var seed_text := ""
var score := 0
var pot := 0
var streak := 0
var lives := B.LIVES_START
var pos := 1
var cur := 0
var ended := ""
var actions := ""
var _deck := PackedInt32Array()


func _init(seed_value: String = "", deck: PackedInt32Array = PackedInt32Array()) -> void:
	seed_text = seed_value
	_deck = deck if deck.size() == Deck.SIZE else Deck.shuffled(seed_value)
	cur = Deck.rank(_deck[0])


# 今の札(表になっている札)の番号。めくった札だけを返す。
func current_card() -> int:
	return _deck[pos - 1]


func remaining() -> int:
	return Deck.SIZE - pos


# [hi, lo, sa]: 残りのうち今の札より大きい・小さい・同じ数字の枚数。
func counts() -> Array:
	var hi := 0
	var lo := 0
	var sa := 0
	for i in range(pos, Deck.SIZE):
		var r := Deck.rank(_deck[i])
		if r > cur:
			hi += 1
		elif r < cur:
			lo += 1
		else:
			sa += 1
	return [hi, lo, sa]


# 残り札の表示(FR-10): 数字 A〜K ごとの残り枚数。添字 0 が A。
func rank_counts() -> Array:
	var out := []
	out.resize(13)
	out.fill(0)
	for i in range(pos, Deck.SIZE):
		out[Deck.rank(_deck[i]) - 1] += 1
	return out


func winners(side: String) -> int:
	var c := counts()
	match side:
		"H":
			return c[0]
		"L":
			return c[1]
		"S":
			return c[2]
	return 0


@warning_ignore("integer_division")
static func quote_value(n: int, w: int, streak_now: int) -> int:
	if w <= 0:
		return 0
	var base := B.BASE * n * n / (w * w)
	if base > B.GAIN_CAP:
		base = B.GAIN_CAP
	return base * (10 + mini(streak_now, B.STREAK_CAP)) / 10


# ボタンに出す点(FR-5)。押せない側は 0。
func quote(side: String) -> int:
	if ended != "" or not side in SIDES:
		return 0
	return quote_value(remaining(), winners(side), streak)


# 結果: {result: "hit"/"miss"/"invalid", side, n, w, gain, card, pot_lost, life_up, ended}
func guess(side: String) -> Dictionary:
	var gain := quote(side)
	if gain == 0:
		return {"result": "invalid"}
	var n := remaining()
	var w := winners(side)
	var card := _deck[pos]
	var nx := Deck.rank(card)
	pos += 1
	actions += side
	var hit := (side == "H" and nx > cur) or (side == "L" and nx < cur) or (side == "S" and nx == cur)
	var res := {"result": "hit" if hit else "miss", "side": side, "n": n, "w": w, "gain": 0, "card": card, "pot_lost": 0, "life_up": false}
	if hit:
		pot += gain
		streak += 1
		res["gain"] = gain
		if streak % B.LIFE_EVERY == 0 and lives < B.LIVES_MAX:
			lives += 1
			res["life_up"] = true
	else:
		res["pot_lost"] = pot
		pot = 0
		streak = 0
		lives -= 1
	cur = nx
	if lives == 0:
		ended = "gameover"
	elif remaining() == 0:
		score += pot + B.CLEAR_BONUS + B.LIFE_BONUS * lives
		pot = 0
		ended = "clear"
	res["ended"] = ended
	return res


# 結果: {result: "banked"/"invalid", amount}
func bank() -> Dictionary:
	if ended != "" or pot == 0:
		return {"result": "invalid"}
	var amount := pot
	score += pot
	pot = 0
	streak = 0
	actions += "B"
	return {"result": "banked", "amount": amount}


# 1 文字の操作を流す。H・L・S は guess、B は bank。
func apply(action: String) -> Dictionary:
	return bank() if action == "B" else guess(action)


# 種と操作の列から復元する(D-10)。{ok, state}。途中で invalid が出たら ok は偽(E-9)。
static func replay(seed_value: String, action_text: String) -> Dictionary:
	var st = new(seed_value)
	for i in action_text.length():
		if st.apply(action_text[i])["result"] == "invalid":
			return {"ok": false, "state": null}
	return {"ok": true, "state": st}
