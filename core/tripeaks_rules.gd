# トライピークスの決まり(追補 2 §8・§9.4)。場 28 枚(上から 3・6・9・10 枚の 4 段)、表の札 1 枚、山 23 枚。
# 表になっている場の札のうち、数字が表の札の ±1(K と A はつながる)の札を取る。点の計算もここだけで行う(INV-1・INV-2)。
extends RefCounted

const B := preload("res://core/balance.gd")
const Deck := preload("res://core/deck.gd")

const TABLEAU := 28
# 段ごとの始まりの番号と枚数
const ROW_START := [0, 3, 9, 18]
const ROW_SIZE := [3, 6, 9, 10]

var tableau := PackedInt32Array()
var removed: Array[bool] = []
var stock := PackedInt32Array()
var waste := 0
var score := 0
var streak := 0
var best_streak := 0
var taken := 0
# "" / "clear"(全部取った)/ "stuck"(手詰まり)
var ended := ""


func _init(cards: PackedInt32Array) -> void:
	tableau = cards.slice(0, TABLEAU)
	waste = cards[TABLEAU]
	stock = cards.slice(TABLEAU + 1)
	for i in TABLEAU:
		removed.append(false)


static func row_of(i: int) -> int:
	for r in range(3, -1, -1):
		if i >= ROW_START[r]:
			return r
	return 0


# 札 i に重なっている、1 つ下の段の札(いちばん下の段は無し)。§9.4 の図のとおり。
@warning_ignore("integer_division")
static func covered_by(i: int) -> Array:
	var r := row_of(i)
	var k: int = i - ROW_START[r]
	if r == 3:
		return []
	var first: int = 2 * k if r == 0 else k + k / 2 if r == 1 else k
	return [ROW_START[r + 1] + first, ROW_START[r + 1] + first + 1]


func is_open(i: int) -> bool:
	if removed[i]:
		return false
	for c in covered_by(i):
		if not removed[c]:
			return false
	return true


static func adjacent(a: int, b: int) -> bool:
	var d := absi(Deck.rank(a) - Deck.rank(b))
	return d == 1 or d == 12


func can_take(i: int) -> bool:
	return ended == "" and i >= 0 and i < TABLEAU and is_open(i) and adjacent(tableau[i], waste)


func stock_left() -> int:
	return stock.size()


# 結果: {result: "taken"/"invalid", gain, peak}
func take(i: int) -> Dictionary:
	if not can_take(i):
		return {"result": "invalid", "gain": 0, "peak": false}
	removed[i] = true
	waste = tableau[i]
	taken += 1
	streak += 1
	best_streak = maxi(best_streak, streak)
	var gain := B.TP_CARD * streak
	var peak := row_of(i) == 0
	if peak:
		gain += B.TP_PEAK
	score += gain
	if not false in removed:
		score += B.TP_CLEAR + B.TP_STOCK_LEFT * stock.size()
		ended = "clear"
	else:
		_check_stuck()
	return {"result": "taken", "gain": gain, "peak": peak}


# 山の 1 枚を新しい表の札にする。続けて取った枚数は 0 に戻る。
func draw() -> Dictionary:
	if ended != "" or stock.is_empty():
		return {"result": "invalid"}
	waste = stock[0]
	stock = stock.slice(1)
	streak = 0
	_check_stuck()
	return {"result": "drawn"}


func _check_stuck() -> void:
	if not stock.is_empty():
		return
	for i in TABLEAU:
		if can_take(i):
			return
	ended = "stuck"
