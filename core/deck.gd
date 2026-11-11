# 札の番号(0〜51)から数字とマークを出し、種の文字列から山札を並べる(§9.3)。
# 並べ替えは core/rng.gd の整数の計算だけで行う(D-11・INV-3)。
extends RefCounted

const Rng := preload("res://core/rng.gd")

const SIZE := 52


# 1 = A、11 = J、12 = Q、13 = K
static func rank(card: int) -> int:
	return card % 13 + 1


# 0 = スペード、1 = ハート、2 = ダイヤ、3 = クラブ
@warning_ignore("integer_division")
static func suit(card: int) -> int:
	return card / 13


static func shuffled(seed_text: String) -> PackedInt32Array:
	var d := PackedInt32Array()
	d.resize(SIZE)
	for i in SIZE:
		d[i] = i
	var r := Rng.new(Rng.fnv1a(seed_text))
	for i in range(SIZE - 1, 0, -1):
		var j := r.next_int(i + 1)
		var t := d[i]
		d[i] = d[j]
		d[j] = t
	return d


# テストと診断表示で使う検査値: 位置 × 番号を 52 枚ぶん足した値(§9.3)。
static func checksum(d: PackedInt32Array) -> int:
	var s := 0
	for i in d.size():
		s += i * d[i]
	return s
