# 進行に関わる乱数(§9.2・INV-3)。xorshift32 と FNV-1a(32 ビット)だけを持つ。
# 端末や版で結果が変わらないよう、Godot の乱数関数は使わない。
extends RefCounted

const MASK := 0xFFFFFFFF

var state: int = 1


func _init(seed_value: int = 1) -> void:
	state = seed_value & MASK
	if state == 0:
		state = 1


func next() -> int:
	var x := state
	x = x ^ ((x << 13) & MASK)
	x = x ^ (x >> 17)
	x = x ^ ((x << 5) & MASK)
	state = x
	return x


func next_int(n: int) -> int:
	return next() % n


static func fnv1a(text: String) -> int:
	var h := 2166136261
	for b in text.to_utf8_buffer():
		h = h ^ b
		h = (h * 16777619) & MASK
	return h
