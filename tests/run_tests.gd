# 自前のテストランナー(D-19)。godot --headless --script res://tests/run_tests.gd で動かす。
# test_ で始まる関数を順に呼び、空文字なら成功、それ以外は失敗の理由。1 件でも失敗なら終了コード 1。
extends SceneTree

const Rng := preload("res://core/rng.gd")
const Deck := preload("res://core/deck.gd")
const Fx := preload("res://tests/fixtures.gd")

const FONT_PATH := "res://assets/fonts/NotoSansJP-Variable.ttf"
const STRINGS_PATH := "res://core/strings.gd"


func _initialize() -> void:
	var failed := 0
	var total := 0
	for m in get_method_list():
		var name: String = m["name"]
		if not name.begins_with("test_"):
			continue
		total += 1
		var t0 := Time.get_ticks_msec()
		var err: String = call(name)
		var ms := Time.get_ticks_msec() - t0
		if err == "":
			print("PASS %s (%d ms)" % [name, ms])
		else:
			failed += 1
			printerr("FAIL ", name, ": ", err)
	print("%d passed, %d failed" % [total - failed, failed])
	quit(1 if failed > 0 or total == 0 else 0)


# AC-18: strings.gd の全文字と ASCII の印字可能文字を、同梱フォントが持つ。
func test_font_covers_strings_and_ascii() -> String:
	var font: Font = load(FONT_PATH)
	if font == null:
		return "cannot load font: " + FONT_PATH
	var codes := {}
	for c in range(0x20, 0x7F):
		codes[c] = true
	var texts := []
	for v in load(STRINGS_PATH).get_script_constant_map().values():
		if v is String:
			texts.append(v)
		elif v is Array:
			texts.append_array(v.filter(func(e): return e is String))
	for t in texts:
		for i in t.length():
			codes[t.unicode_at(i)] = true
	var missing := PackedStringArray()
	for c in codes:
		if not font.has_char(c):
			missing.append("U+%04X" % c)
	return "" if missing.is_empty() else "missing glyphs: " + ", ".join(missing)


# AC-5: §9.2 の固定値 5 行。
func test_rng_fixed_values() -> String:
	for k in Fx.FNV:
		if Rng.fnv1a(k) != Fx.FNV[k]:
			return "FNV-1a(%s) = %d" % [k, Rng.fnv1a(k)]
	var r := Rng.new(1)
	var got := []
	for i in 5:
		got.append(r.next())
	if got != Fx.XORSHIFT_SEED1:
		return "xorshift32 seed 1: " + str(got)
	if Rng.new(0).state != 1:
		return "seed 0 must become 1"
	return ""


# AC-5: §9.3 の固定値 4 行(先頭 10 枚の番号と数字、検査値)と、0〜51 を 1 つずつ含むこと。
func test_deck_fixed_values() -> String:
	for row in Fx.DECKS:
		var d := Deck.shuffled(row[0])
		var ids := []
		var ranks := []
		for i in 10:
			ids.append(d[i])
			ranks.append(Deck.rank(d[i]))
		if ids != row[1]:
			return "%s ids %s" % [row[0], str(ids)]
		if ranks != row[2]:
			return "%s ranks %s" % [row[0], str(ranks)]
		if Deck.checksum(d) != row[3]:
			return "%s checksum %d" % [row[0], Deck.checksum(d)]
		var sorted := Array(d)
		sorted.sort()
		if sorted != range(52):
			return "%s is not a permutation of 0..51" % row[0]
	return ""


func test_card_rank_and_suit() -> String:
	var cases := [[0, 1, 0], [12, 13, 0], [13, 1, 1], [25, 13, 1], [26, 1, 2], [51, 13, 3]]
	for c in cases:
		if Deck.rank(c[0]) != c[1] or Deck.suit(c[0]) != c[2]:
			return "card %d -> rank %d suit %d" % [c[0], Deck.rank(c[0]), Deck.suit(c[0])]
	return ""


# AC-19 の一部(INV-2・INV-3・INV-6): core/ に乱数関数と小数が無い。strings.gd 以外の .gd に日本語の文字列リテラルが無い。
func test_source_rules() -> String:
	var banned := RegEx.create_from_string("\\b(randi|randf|randomize|RandomNumberGenerator|shuffle|pick_random)\\b|\\bfloat\\(|\\b\\d+\\.\\d+\\b")
	for file in _gd_files("res://core"):
		var m := banned.search(_code_only(file))
		if m:
			return file + " contains " + m.get_string()
	var jp := RegEx.create_from_string("\"[^\"\\n]*[\\x{3040}-\\x{30FF}\\x{4E00}-\\x{9FFF}][^\"\\n]*\"")
	for dir in ["res://core", "res://ui", "res://save", "res://audio", "res://net", "res://tests", "res://tools"]:
		for file in _gd_files(dir):
			if file == STRINGS_PATH:
				continue
			var m := jp.search(_code_only(file))
			if m:
				return file + " has a Japanese literal " + m.get_string()
	return ""


# コメントを除いた本文(行の # から後を落とす。文字列の中の # は使わない前提)。
func _code_only(file: String) -> String:
	var out := PackedStringArray()
	for line in FileAccess.get_file_as_string(file).split("\n"):
		var i := line.find("#")
		out.append(line if i < 0 else line.substr(0, i))
	return "\n".join(out)


func _gd_files(dir: String) -> Array:
	var out := []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for sub in d.get_directories():
		out.append_array(_gd_files(dir.path_join(sub)))
	return out
