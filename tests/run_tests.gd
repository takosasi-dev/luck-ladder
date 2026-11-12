# 自前のテストランナー(D-19)。godot --headless --script res://tests/run_tests.gd で動かす。
# test_ で始まる関数を順に呼び、空文字なら成功、それ以外は失敗の理由。1 件でも失敗なら終了コード 1。
extends SceneTree

const B := preload("res://core/balance.gd")
const S := preload("res://core/strings.gd")
const Rng := preload("res://core/rng.gd")
const Deck := preload("res://core/deck.gd")
const RunState := preload("res://core/run_state.gd")
const RunStats := preload("res://core/run_stats.gd")
const Ach := preload("res://core/achievements.gd")
const Progress := preload("res://core/progress.gd")
const DayIndex := preload("res://core/day_index.gd")
const ShareText := preload("res://core/share_text.gd")
const Codec := preload("res://core/save_codec.gd")
const SaveStore := preload("res://save/save_store.gd")
const Fx := preload("res://tests/fixtures.gd")
const PlayLayout := preload("res://ui/layout/play_layout.gd")
const Tokens := preload("res://ui/theme/tokens.gd")
const Sfx := preload("res://audio/sfx.gd")
const Bgm := preload("res://audio/bgm.gd")
const PlayScreen := preload("res://ui/screens/play.gd")
const ResultScreen := preload("res://ui/screens/result.gd")
const SettingsScreen := preload("res://ui/screens/settings.gd")
const TitleScreen := preload("res://ui/screens/title.gd")
const AchievementsScreen := preload("res://ui/screens/achievements.gd")
const RecordsScreen := preload("res://ui/screens/records.gd")
const CollectionScreen := preload("res://ui/screens/collection.gd")
const SaveDataScreen := preload("res://ui/screens/save_data.gd")
const ToastPart := preload("res://ui/parts/toast.gd")
const BJ := preload("res://core/bj_rules.gd")
const CasinoTable := preload("res://ui/screens/casino_table.gd")
const BlackjackScreen := preload("res://ui/screens/blackjack.gd")
const Main := preload("res://ui/main.gd")
const Poker := preload("res://core/poker_rules.gd")
const PokerScreen := preload("res://ui/screens/poker.gd")
const Invite := preload("res://core/invite_codec.gd")
const BrowserBridge := preload("res://net/browser_bridge.gd")
const NetLab := preload("res://ui/screens/net_lab.gd")

const FONT_PATH := "res://assets/fonts/NotoSansJP-Variable.ttf"
const STRINGS_PATH := "res://core/strings.gd"
const TEST_SAVE := "user://ll_test_save.json"


# AC-28: 書けない保存先の代わり。
class FailStore extends SaveStore:
	func _write_to(_file_path: String, _text: String) -> bool:
		return false


# 追補 1: 決めた並びの山札で配る卓。
class FixedBlackjack extends BlackjackScreen:
	var fixed: PackedInt32Array

	func _new_deck() -> PackedInt32Array:
		return fixed


class FixedPoker extends PokerScreen:
	var fixed: PackedInt32Array

	func _new_deck() -> PackedInt32Array:
		return fixed


# 画面のテスト用の、main の代わり(保存・効果音・BGM と、設定を写した回数だけを持つ)。
class StubApp extends RefCounted:
	var save
	var sfx
	var bgm
	var overlay = null
	var applied := 0

	func _init(store, parent: Node) -> void:
		save = store
		sfx = Sfx.new()
		bgm = Bgm.new()
		parent.add_child(sfx)
		parent.add_child(bgm)

	func apply_settings() -> void:
		applied += 1

	func open_settings() -> void:
		pass

	func open_data() -> void:
		pass

	func free_nodes() -> void:
		sfx.free()
		bgm.free()


# 最初のフレームで始める。_initialize の時点ではツリーが動いておらず、足したノードの _ready が呼ばれない。
func _process(_delta: float) -> bool:
	_run_all()
	return true


func _run_all() -> void:
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


# ---- 共通の道具 ----

func _texts(v, out: Array) -> void:
	if v is String:
		out.append(v)
	elif v is Array:
		for e in v:
			_texts(e, out)
	elif v is Dictionary:
		for k in v:
			_texts(k, out)
			_texts(v[k], out)


# §9.4 の打ち方 P1・P2。
func _policy(name: String, st) -> String:
	var c: Array = st.counts()
	if st.pot >= 800:
		return "B"
	if name == "P2" and st.pot == 0 and st.lives >= 2 and c[2] >= 2:
		return "S"
	if c[0] >= c[1] and c[0] > 0:
		return "H"
	if c[1] > 0:
		return "L"
	return "S"


# 打ち方でランを最後まで進める。[state, stats]
func _play(policy: String, seed_text: String, mode: String = "run", first_daily: bool = false) -> Array:
	var st = RunState.new(seed_text)
	var stats = RunStats.new(mode, first_daily)
	while st.ended == "":
		var a := _policy(policy, st)
		stats.note_counter(true)
		if a == "B":
			stats.on_bank(st.bank(), st)
		else:
			stats.on_guess(st.guess(a), st)
	return [st, stats]


func _ordered_deck(head: Array = []) -> PackedInt32Array:
	var d := PackedInt32Array(head)
	for i in 52:
		if not i in head:
			d.append(i)
	return d


func _stats_with(fields: Dictionary):
	var s = RunStats.new()
	for k in fields:
		s.set(k, fields[k])
	return s


func _fresh_store(store_path: String = TEST_SAVE):
	for p in [store_path, store_path.get_basename() + ".broken.json"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	return SaveStore.new(store_path)


func _write_raw(store_path: String, text: String) -> void:
	var f := FileAccess.open(store_path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


# ---- Phase 0 ----

# AC-18: strings.gd の全文字と ASCII の印字可能文字を、同梱フォントが持つ。
func test_font_covers_strings_and_ascii() -> String:
	var font: Font = load(FONT_PATH)
	if font == null:
		return "cannot load font: " + FONT_PATH
	var codes := {}
	for c in range(0x20, 0x7F):
		codes[c] = true
	var texts := []
	_texts(load(STRINGS_PATH).get_script_constant_map().values(), texts)
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


# ---- Phase 1: ラン ----

# AC-6: §9.4 の quote の固定値。
func test_quote_fixed_values() -> String:
	for q in Fx.QUOTES:
		var got := RunState.quote_value(q[0], q[1], q[2])
		if got != q[3]:
			return "quote(n=%d, w=%d, streak=%d) = %d, want %d" % [q[0], q[1], q[2], got, q[3]]
	return ""


# AC-7: 通しのラン 5 行が、表の全項目で一致する。
func test_policy_runs() -> String:
	for r in Fx.RUNS:
		var res := _play(r[0], r[1])
		var st = res[0]
		var s = res[1]
		var got := [st.ended, st.score, s.draws, s.hits, s.misses, s.same_hits, s.banks, s.best_streak, st.lives]
		var want: Array = r.slice(2)
		if got != want:
			return "%s %s: got %s want %s" % [r[0], r[1], str(got), str(want)]
	return ""


# AC-8: 操作の列からの復元。
func test_replay() -> String:
	var r1 := RunState.replay("LL1:test:2", "LLLLLH")
	if not r1["ok"] or r1["state"].score != 0 or r1["state"].ended != "gameover":
		return "replay test:2"
	var r2 := RunState.replay("LL1:test:6", "SBSSSHLHHH")
	if not r2["ok"] or r2["state"].score != 5000 or r2["state"].ended != "gameover":
		return "replay test:6"
	var played = _play("P1", "LL1:test:1")[0]
	var r3 := RunState.replay("LL1:test:1", played.actions)
	if not r3["ok"] or r3["state"].score != 2720:
		return "replay of P1 test:1 actions: " + played.actions
	var r4 := RunState.replay("LL1:test:1", "H".repeat(60))
	if r4["ok"]:
		return "60 x H must fail"
	return ""


# AC-9: guess の境界。
func test_guess_boundaries() -> String:
	# 今の札が K: HIGH は当たりが 0 枚で invalid、状態を変えない
	var st = RunState.new("x", _ordered_deck([12, 0]))
	if st.guess("H")["result"] != "invalid" or st.pos != 1 or st.actions != "" or st.quote("H") != 0:
		return "K + HIGH must be invalid"
	# 同じ数字: HIGH は外れ、同じ は当たり
	st = RunState.new("x", _ordered_deck([0, 13]))
	if st.guess("H")["result"] != "miss":
		return "HIGH on same rank must miss"
	st = RunState.new("x", _ordered_deck([0, 13]))
	if st.guess("S")["result"] != "hit":
		return "SAME on same rank must hit"
	# 連続 3・6・9 でライフが戻り、4 のときは増えない
	st = RunState.new("x", _ordered_deck())
	st.lives = 1
	var want_lives := {3: 2, 6: 3, 9: 4, 12: 4}
	for i in range(1, 13):
		var res: Dictionary = st.guess("H")
		if res["result"] != "hit":
			return "ordered deck HIGH #%d not hit" % i
		if want_lives.has(i) and st.lives != want_lives[i]:
			return "after streak %d lives %d" % [i, st.lives]
	# ライフ 1 で外すと gameover、その後は invalid
	st = RunState.new("x", _ordered_deck([0, 13]))
	st.lives = 1
	if st.guess("H")["ended"] != "gameover":
		return "miss with 1 life must end"
	if st.guess("L")["result"] != "invalid" or st.bank()["result"] != "invalid":
		return "actions after gameover must be invalid"
	# 残り札の数の合計と hi + lo + sa が n に等しい
	st = RunState.new("LL1:test:2")
	for a in ["L", "L", "L"]:
		var c: Array = st.counts()
		var total := 0
		for v in st.rank_counts():
			total += v
		if c[0] + c[1] + c[2] != st.remaining() or total != st.remaining():
			return "counts do not add up to n"
		st.guess(a)
	st = RunState.new("LL1:test:2")
	if st.rank_counts()[11] != 3 or st.counts()[2] != 3:
		return "test:2 start: Q column %d sa %d" % [st.rank_counts()[11], st.counts()[2]]
	return ""


# AC-10: bank の境界。
func test_bank_boundaries() -> String:
	var st = RunState.new("x", _ordered_deck())
	if st.bank()["result"] != "invalid":
		return "bank with pot 0 must be invalid"
	st.guess("H")
	st.guess("H")
	if st.streak != 2 or st.pot == 0:
		return "setup failed"
	var pot: int = st.pot
	var res: Dictionary = st.bank()
	if res["result"] != "banked" or res["amount"] != pot or st.score != pot or st.pot != 0 or st.streak != 0:
		return "bank result " + str(res)
	if st.quote("H") != RunState.quote_value(st.remaining(), st.counts()[0], 0):
		return "multiplier after bank must be 1.0"
	return ""


# 完走の加点(FR-9・§9.4): 残り 0 枚で、ポット + 3,000 + ライフ × 1,000。
func test_clear_bonus() -> String:
	var res := _play("P1", "LL1:test:14")
	var st = res[0]
	if st.ended != "clear" or st.pot != 0 or st.remaining() != 0:
		return "test:14 must clear with empty pot"
	return ""


# AC-11: §9.5 の固定値と連続日数。
func test_day_index() -> String:
	for r in Fx.DAY_NOS:
		if DayIndex.day_no(r[0], r[1], r[2]) != r[3]:
			return "day_no %s = %d" % [str(r), DayIndex.day_no(r[0], r[1], r[2])]
	if DayIndex.daily_seed_text(DayIndex.date_string(2026, 11, 11)) != "LL1:daily:2026-11-11":
		return "daily seed text"
	var s := {"last": "2026-11-10", "count": 4}
	if DayIndex.next_streak(s, "2026-11-11") != {"last": "2026-11-11", "count": 5}:
		return "yesterday -> +1"
	if DayIndex.next_streak({"last": "2026-11-11", "count": 4}, "2026-11-11")["count"] != 4:
		return "today -> unchanged"
	if DayIndex.next_streak({"last": "2026-11-09", "count": 4}, "2026-11-11")["count"] != 1:
		return "2 days ago -> 1"
	if DayIndex.next_streak({"last": "2026-12-31", "count": 2}, "2027-01-01")["count"] != 3:
		return "year boundary"
	if DayIndex.next_streak({"last": "", "count": 0}, "2026-11-11")["count"] != 1:
		return "first time -> 1"
	return ""


# ---- Phase 1: 実績・称号・解放 ----

# AC-12: 実績 35 個を、ちょうど満たす値と 1 だけ足りない値で判定する。
# [ID, ラン終了時か, 満たす集計値, 足りない集計値, 満たす ctx, 足りない ctx, 足りない側のラン終了時]
func test_achievement_thresholds() -> String:
	var cleared := {"cleared": true}
	var vs := {"mode": "versus", "versus_done": true}
	var cases := [
		["A-01", true, {}, {}, {}, {}, false],
		["A-02", false, {"banks": 1}, {"banks": 0}],
		["A-03", false, {"best_streak": 3}, {"best_streak": 2}],
		["A-04", false, {"best_streak": 5}, {"best_streak": 4}],
		["A-05", false, {"best_streak": 8}, {"best_streak": 7}],
		["A-06", false, {"best_streak": 12}, {"best_streak": 11}],
		["A-07", false, {"longshot_hits": 1}, {"longshot_hits": 0}],
		["A-08", true, {}, {}, {"totals": {"longshot_hits": 25}}, {"totals": {"longshot_hits": 24}}],
		["A-09", false, {"max_gain": 3000}, {"max_gain": 2999}],
		["A-10", false, {"banks": 5}, {"banks": 4}],
		["A-11", false, {"max_bank": 3000}, {"max_bank": 2999}],
		["A-12", false, {"max_bank": 8000}, {"max_bank": 7999}],
		["A-13", true, cleared, {"cleared": false}],
		["A-14", true, {"cleared": true, "end_lives": 4}, {"cleared": true, "end_lives": 3}],
		["A-15", true, {"cleared": true, "misses": 6}, {"cleared": true, "misses": 7}],
		["A-16", true, {"score": 3000}, {"score": 2999}],
		["A-17", true, {"score": 10000}, {"score": 9999}],
		["A-18", true, {"score": 20000}, {"score": 19999}],
		["A-19", true, {"cleared": true, "counter_shown": false}, {"cleared": true, "counter_shown": true}],
		["A-20", false, {"comeback": true}, {"comeback": false}],
		["A-21", false, {"life_regains": 3}, {"life_regains": 2}],
		["A-22", false, {"same_hits": 1}, {"same_hits": 0}],
		["A-23", true, {"mode": "daily", "first_daily": true}, {"mode": "run"}],
		["A-24", true, {}, {}, {"daily_streak": 7}, {"daily_streak": 6}],
		["A-25", true, {}, {}, {"daily_days": 30}, {"daily_days": 29}],
		["A-26", true, {}, {}, {"totals": {"runs": 50}}, {"totals": {"runs": 49}}],
		["A-27", true, {}, {}, {"totals": {"runs": 200}}, {"totals": {"runs": 199}}],
		["A-28", true, {}, {}, {"totals": {"total_score": 100000}}, {"totals": {"total_score": 99999}}],
		["A-29", true, {}, {}, {"totals": {"total_score": 1000000}}, {"totals": {"total_score": 999999}}],
		["A-30", false, {"sure_misses": 1}, {"sure_misses": 0}],
		["A-31", false, {"max_pot_lost": 5000}, {"max_pot_lost": 4999}],
		["A-32", false, {"same_hits": 2}, {"same_hits": 1}],
		["A-33", true, vs, {"mode": "versus", "versus_done": false}],
		["A-34", true, {"mode": "versus", "versus_done": true, "versus_players": 2, "versus_solo_first": true}, {"mode": "versus", "versus_done": true, "versus_players": 2, "versus_solo_first": false}],
		["A-34", true, {"mode": "versus", "versus_done": true, "versus_players": 2, "versus_solo_first": true}, {"mode": "versus", "versus_done": true, "versus_players": 1, "versus_solo_first": true}],
		["A-35", true, {"mode": "versus", "versus_done": true, "versus_players": 4, "versus_solo_first": true}, {"mode": "versus", "versus_done": true, "versus_players": 3, "versus_solo_first": true}],
		# ラン終了時だけの条件は、1 手ごとの呼び出しでは満たさない
		["A-13", true, cleared, cleared, {}, {}, false],
		["A-16", true, {"score": 3000}, {"score": 3000}, {}, {}, false],
	]
	var seen := {}
	var checked := 0
	for c in cases:
		var ok_ctx: Dictionary = c[4] if c.size() > 4 else {}
		var ng_ctx: Dictionary = c[5] if c.size() > 5 else {}
		var ng_end: bool = c[6] if c.size() > 6 else c[1]
		if not c[0] in Ach.judge(_stats_with(c[2]), ok_ctx, c[1]):
			return "%s should be met with %s %s" % [c[0], str(c[2]), str(ok_ctx)]
		if c[0] in Ach.judge(_stats_with(c[3]), ng_ctx, ng_end):
			return "%s should not be met with %s %s" % [c[0], str(c[3]), str(ng_ctx)]
		seen[c[0]] = true
		checked += 2
	if seen.size() != 35 or checked < 70:
		return "covered %d ids, %d checks" % [seen.size(), checked]
	# 今日の山札の 2 回目からは、どの実績にも数えない(D-9)
	var second = _stats_with({"mode": "daily", "first_daily": false, "banks": 5, "best_streak": 12, "score": 30000})
	if not Ach.judge(second, {"totals": {"runs": 999}}, true).is_empty():
		return "second daily attempt must not count"
	return ""


func test_achievement_ids() -> String:
	var want := []
	for i in range(1, 36):
		want.append("A-%02d" % i)
	if Ach.ids() != want:
		return "ids " + str(Ach.ids())
	if S.ACHIEVEMENTS.keys() != want:
		return "strings.gd ACHIEVEMENTS keys differ"
	for id in want:
		if Ach.is_hidden(id) != (id in ["A-30", "A-31", "A-32"]):
			return "hidden flag " + id
	return ""


# AC-13: 称号と解放。
func test_titles_and_unlocks() -> String:
	var titles := [[0, 1], [4999, 1], [5000, 2], [1999999, 9], [2000000, 10]]
	for t in titles:
		if Progress.title_rank(t[0]) != t[1]:
			return "title_rank(%d) = %d" % [t[0], Progress.title_rank(t[0])]
	if S.TITLES.size() != 10:
		return "10 titles"
	var many := {}
	for i in range(1, 24):
		many["A-%02d" % i] = "2026-11-11"
	var many_plus := many.duplicate()
	many_plus["A-24"] = "2026-11-11"
	# [ID, 条件前の実績, 条件前の通算, 条件後の実績, 条件後の通算]
	var cases := [
		["B-01", {}, 0, {}, 0], ["B-02", {}, 0, {}, 0], ["T-01", {}, 0, {}, 0],
		["B-03", {}, 0, {"A-04": "d"}, 0], ["B-04", {}, 0, {"A-13": "d"}, 0],
		["B-05", {}, 19999, {}, 20000], ["B-06", {}, 0, {"A-24": "d"}, 0],
		["B-07", {}, 0, {"A-17": "d"}, 0], ["B-08", many, 0, many_plus, 0],
		["T-02", {}, 4999, {}, 5000], ["T-03", {}, 49999, {}, 50000],
		["T-04", {}, 199999, {}, 200000], ["T-05", {}, 0, {"A-14": "d"}, 0],
	]
	for c in cases:
		var start: bool = Progress.BACKS.get(c[0], Progress.TABLES.get(c[0]))[0] == "start"
		if not start and Progress.is_unlocked(c[0], c[1], c[2]):
			return c[0] + " unlocked too early"
		if not Progress.is_unlocked(c[0], c[3], c[4]):
			return c[0] + " not unlocked"
	if Progress.BACKS.size() != 8 or Progress.TABLES.size() != 5:
		return "8 backs and 5 tables"
	return ""


# ---- Phase 1: 共有テキスト ----

# AC-17: §9.11 の形。日本語の部分は strings.gd の定数から組む(AC-19)。
func test_share_text() -> String:
	if ShareText.group(0) != "0" or ShareText.group(999) != "999" or ShareText.group(1000) != "1,000" or ShareText.group(1234567) != "1,234,567":
		return "group"
	var d1 := ShareText.build("daily", 315, "2026-11-11", 1, 2720, false, 30, 4, "")
	var want1 := "LuckLadder %s No.315 (2026-11-11) %s\n%s" % [S.SHARE_DAILY, S.SHARE_FIRST, S.SHARE_LINE % ["2,720", 30, 4]]
	if d1 != want1:
		return "daily first: " + d1
	var d2 := ShareText.build("daily", 315, "2026-11-11", 2, 2720, false, 30, 4, "")
	if d2.split("\n")[0] != "LuckLadder %s No.315 (2026-11-11) %s" % [S.SHARE_DAILY, S.SHARE_NTH % 2]:
		return "daily second: " + d2
	var r := ShareText.build("run", 315, "2026-11-11", 1, 13225, true, 51, 6, "https://example.github.io/luck-ladder/")
	var want3 := "LuckLadder %s\n%s%s\nhttps://example.github.io/luck-ladder/" % [S.SHARE_RUN, S.SHARE_CLEAR, S.SHARE_LINE % ["13,225", 51, 6]]
	if r != want3:
		return "run clear: " + r
	if not S.SHARE_LINE.begins_with("%s") or not S.SHARE_NTH.begins_with("%d"):
		return "share format strings"
	if not B.SHARE_URL.begins_with("https://") or not B.SHARE_URL.ends_with("/"):
		return "SHARE_URL: " + B.SHARE_URL
	return ""


# ---- Phase 1: 保存 ----

# AC-14: 保存の流れ。
func test_save_store_flow() -> String:
	var store = _fresh_store()
	var s = _play("P1", "LL1:test:1")[1]
	store.save_current("run", "LL1:test:1", "2026-11-11", "LLH", true)
	store.finish_run(s, "2026-11-11", 315)
	store = SaveStore.new(TEST_SAVE)
	if store.data["totals"]["runs"] != 1 or store.data["current_run"] != null:
		return "after one run: " + str(store.data["totals"])
	store.save_current("run", "LLR:1:2", "2026-11-11", "HL", true)
	store.save_current("daily", "LL1:daily:2026-11-11", "2026-11-11", "S", false)
	store = SaveStore.new(TEST_SAVE)
	if store.current("run") == null or store.current("daily") == null:
		return "run and daily in progress at the same time"
	store.drop_stale_daily("2026-11-12")
	if store.current("daily") != null or store.current("run") == null:
		return "stale daily must be dropped"
	for i in range(1, 12):
		store.finish_run(_play("P1", "LL1:test:%d" % i)[1], "2026-11-11", 315)
	var tops: Array = store.data["top_runs"]
	if tops.size() != 10:
		return "top_runs size %d" % tops.size()
	for i in range(1, tops.size()):
		if tops[i - 1]["score"] < tops[i]["score"]:
			return "top_runs not sorted"
	# 今日の山札: 初回と 2 回目
	store = _fresh_store()
	var first = _play("P1", "LL1:daily:2026-11-11", "daily", true)[1]
	store.finish_run(first, "2026-11-11", 315)
	var e: Dictionary = store.data["daily"]["2026-11-11"]
	if e["attempts"] != 1 or e["score"] != first.score or store.data["daily_days"] != 1 or store.data["daily_streak"]["count"] != 1:
		return "first daily: " + str(e)
	var totals_before: Dictionary = store.data["totals"].duplicate()
	var ach_before: Dictionary = store.data["achievements"].duplicate()
	var tops_before: Array = store.data["top_runs"].duplicate(true)
	var second = _play("P2", "LL1:daily:2026-11-11", "daily", false)[1]
	var res: Dictionary = store.finish_run(second, "2026-11-11", 315)
	e = store.data["daily"]["2026-11-11"]
	if e["attempts"] != 2 or e["score"] != first.score or res["attempt"] != 2:
		return "second daily: " + str(e)
	if store.data["totals"] != totals_before or store.data["achievements"] != ach_before or store.data["top_runs"] != tops_before:
		return "second daily changed records"
	if store.data["daily_days"] != 1:
		return "daily_days counted twice"
	return ""


# 結果画面のための戻り値: 新しい実績と称号・解放。
func test_finish_run_result() -> String:
	var store = _fresh_store()
	var res: Dictionary = store.finish_run(_play("P1", "LL1:test:14")[1], "2026-11-11", 315)
	for id in ["A-01", "A-02", "A-13", "A-16", "A-17"]:
		if not id in res["new_achievements"]:
			return "missing %s in %s" % [id, str(res["new_achievements"])]
	if res["title_before"] != 1 or res["title_after"] != 2:
		return "title %d -> %d" % [res["title_before"], res["title_after"]]
	for id in ["B-03", "B-04", "B-07", "T-02"]:
		if not id in res["new_unlocks"]:
			return "missing unlock %s in %s" % [id, str(res["new_unlocks"])]
	var again: Dictionary = store.finish_run(_play("P1", "LL1:test:14")[1], "2026-11-11", 315)
	if "A-13" in again["new_achievements"]:
		return "achievement reported twice"
	var s = _stats_with({"best_streak": 5})
	if store.judge_move(s, "2026-11-12") != []:
		return "judge_move must skip achieved ones"
	return ""


# AC-15: 壊れた値は、その項目だけ既定値に戻る。
func test_save_sanitize() -> String:
	_fresh_store()
	_write_raw(TEST_SAVE, "{broken")
	var store = SaveStore.new(TEST_SAVE)
	if store.data["totals"]["runs"] != 0 or not FileAccess.file_exists(TEST_SAVE.get_basename() + ".broken.json"):
		return "broken json must reset and keep a copy"
	if Codec.sanitize({"version": 2, "totals": {"runs": 5}})["broken"] != true:
		return "version 2 must reset"
	var good: Dictionary = Codec.defaults("Alice")
	good["totals"]["runs"] = 3
	var cases := [
		["settings", "sfx_volume", 99, 7],
		["settings", "bgm_volume", -1, 5],
		["settings", "name", "ABCDEFGHI", null],
		["settings", "name", "AB\nC", null],
		["settings", "name", "", null],
		["settings", "card_back", "B-99", "B-01"],
		["settings", "card_back", "B-03", "B-01"],
		["settings", "table", "B-01", "T-01"],
		["settings", "fx", "max", "full"],
	]
	for c in cases:
		var raw: Dictionary = good.duplicate(true)
		raw[c[0]][c[1]] = c[2]
		var res := Codec.sanitize(raw)
		var got = res["data"][c[0]][c[1]]
		if res["broken"] or res["data"]["totals"]["runs"] != 3:
			return "%s.%s must only reset that field" % [c[0], c[1]]
		if c[3] == null:
			if got == c[2] or not Codec.is_valid_name(got):
				return "name %s accepted" % str(c[2]).c_escape()
		elif got != c[3]:
			return "%s.%s = %s" % [c[0], c[1], str(got)]
	var raw2: Dictionary = good.duplicate(true)
	raw2["current_run"] = {"mode": "run", "seed_text": "LLR:1:2", "date": "2026-11-11", "actions": "HXL", "counter_shown": true}
	raw2["achievements"] = {"A-99": "2026-11-11", "A-01": "2026-11-11", "A-02": 5}
	raw2["top_runs"] = [{"score": -1, "cleared": false, "draws": 3, "date": "2026-11-11", "mode": "run"}, {"score": 10.0, "cleared": true, "draws": 51, "date": "2026-11-11", "mode": "run"}]
	raw2["daily"] = {"bad": {}, "2026-11-11": {"no": 315, "attempts": 1, "score": 5, "cleared": false, "draws": 4, "best_streak": 1}}
	var d: Dictionary = Codec.sanitize(raw2)["data"]
	if d["current_run"] != null:
		return "actions HXL must drop current_run"
	if d["achievements"] != {"A-01": "2026-11-11"}:
		return "achievements " + str(d["achievements"])
	if d["top_runs"].size() != 1 or not d["top_runs"][0]["score"] is int:
		return "top_runs " + str(d["top_runs"])
	if d["daily"].keys() != ["2026-11-11"]:
		return "daily " + str(d["daily"])
	# 解放済みの裏面は残る
	var raw3: Dictionary = good.duplicate(true)
	raw3["achievements"] = {"A-04": "2026-11-11"}
	raw3["settings"]["card_back"] = "B-03"
	if Codec.sanitize(raw3)["data"]["settings"]["card_back"] != "B-03":
		return "unlocked card back must stay"
	# 型の違う値で落ちない
	for junk in [null, 5, "x", [], {"version": "1"}, {"version": 1, "settings": [], "totals": "x", "top_runs": {}, "daily": [], "daily_streak": 3}]:
		Codec.sanitize(junk)
	return ""


# AC-16: 書き出しと読み込み。
func test_export_import() -> String:
	var store = _fresh_store()
	store.finish_run(_play("P1", "LL1:test:14")[1], "2026-11-11", 315)
	store.save_current("run", "LLR:1:2", "2026-11-11", "HL", true)
	var text: String = store.export_text()
	if not text.begins_with("LL1."):
		return "prefix"
	var res := Codec.from_export(text)
	var want: Dictionary = store.data.duplicate(true)
	want["current_run"] = null
	if not res["ok"] or res["data"] != want:
		return "round trip differs"
	var before: Dictionary = store.data.duplicate(true)
	for bad in ["abc", "LL1.###", "", "LL1." + Marshalls.utf8_to_base64("[1,2]"), "LL1." + Marshalls.utf8_to_base64("{\"version\":2}")]:
		if store.import_text(bad):
			return "accepted bad import: " + bad
	if store.data != before:
		return "failed import changed data"
	if not store.import_text("  " + text + "\n") or store.data["current_run"] != null:
		return "good import"
	return ""


# AC-20: 途中のランの保存は 5 つのキーだけで、めくっていない札の番号を持たない。
func test_current_run_keys() -> String:
	var store = _fresh_store()
	var st = RunState.new("LL1:test:1")
	st.guess("L")
	st.guess("L")
	store.save_current("run", st.seed_text, "2026-11-11", st.actions, true)
	var raw = JSON.parse_string(FileAccess.get_file_as_string(TEST_SAVE))
	var keys: Array = raw["current_run"].keys()
	keys.sort()
	var want := Codec.RUN_KEYS.duplicate()
	want.sort()
	if keys != want:
		return "current_run keys " + str(keys)
	var restored := RunState.replay(raw["current_run"]["seed_text"], raw["current_run"]["actions"])
	if not restored["ok"] or restored["state"].pos != st.pos or restored["state"].pot != st.pot:
		return "restore from save"
	return ""


# AC-28 の一部: 保存先に書けなくてもランを終えられる。
func test_unwritable_store() -> String:
	var store = FailStore.new("user://ll_never_written.json")
	if store.writable:
		return "writable must be false"
	store.save_current("run", "LLR:1:2", "2026-11-11", "H", true)
	var res: Dictionary = store.finish_run(_play("P1", "LL1:test:1")[1], "2026-11-11", 315)
	if store.data["totals"]["runs"] != 1 or not "A-01" in res["new_achievements"]:
		return "records must stay in memory"
	return ""


# ---- Phase 2 ----

# AC-22 の一部: FR-4 の要素がすべて画面の中にあり、重ならない。ボタンの大きさ(§9.1・INV-11)。
func test_play_layout() -> String:
	var need := ["pause", "score", "lives", "ladder", "deck", "deck_label", "card", "pot", "counter", "high", "same", "bank", "low"]
	for landscape in [true, false]:
		var r: Dictionary = PlayLayout.rects(landscape)
		var screen := Rect2(Vector2.ZERO, PlayLayout.size(landscape))
		var tag := "landscape" if landscape else "portrait"
		for k in need:
			if not r.has(k):
				return "%s: missing %s" % [tag, k]
		var keys: Array = r.keys()
		for i in keys.size():
			if not screen.encloses(r[keys[i]]):
				return "%s: %s is outside the screen" % [tag, keys[i]]
			for j in range(i + 1, keys.size()):
				if r[keys[i]].intersects(r[keys[j]]):
					return "%s: %s overlaps %s" % [tag, keys[i], keys[j]]
		for k in ["high", "low", "same", "bank"]:
			if r[k].size.x < 96 or r[k].size.y < 96:
				return "%s: %s smaller than 96x96" % [tag, k]
		var hl := Vector2(280, 120) if landscape else Vector2(660, 110)
		var sb := Vector2(136, 120) if landscape else Vector2(320, 110)
		for k in ["high", "low"]:
			if r[k].size.x < hl.x or r[k].size.y < hl.y:
				return "%s: %s size %s" % [tag, k, str(r[k].size)]
		for k in ["same", "bank"]:
			if r[k].size.x < sb.x or r[k].size.y < sb.y:
				return "%s: %s size %s" % [tag, k, str(r[k].size)]
		if not (r["high"].position.y < r["same"].position.y and r["same"].position.y < r["low"].position.y and r["same"].position.x < r["bank"].position.x):
			return "%s: order must be HIGH / SAME BANK / LOW" % tag
		if not landscape:
			for k in ["high", "low", "same", "bank"]:
				if r[k].position.y < 768:
					return "portrait: %s above y 768" % k
		# 重ねて出す物(手ほどき・呼びかけ・一時停止の当たり)も画面の中に収まる
		var o: Dictionary = PlayLayout.over(landscape)
		for k in ["pause_hit", "callout", "tut1", "tut2", "tut3", "toast"]:
			if not o.has(k) or not screen.encloses(o[k]):
				return "%s: over %s missing or outside" % [tag, k]
		if o["pause_hit"].size.x < 96 or o["pause_hit"].size.y < 96 or not o["pause_hit"].encloses(r["pause"]):
			return "%s: pause hit area" % tag
	return ""


# ---- Phase 3 ----

# INV-6: Playfair Display は ASCII の印字可能文字と × を持つ(直立とイタリックの両方)。
func test_number_font_coverage() -> String:
	for path in ["res://assets/fonts/PlayfairDisplay-Variable.ttf", "res://assets/fonts/PlayfairDisplay-Italic-Variable.ttf"]:
		var font: Font = load(path)
		if font == null:
			return "cannot load " + path
		var codes := range(0x20, 0x7F)
		codes.append(0xD7)
		for c in codes:
			if not font.has_char(c):
				return "%s lacks U+%04X" % [path, c]
	return ""


# AC-29: 音量の段 → dB。段 0 で無音、段 1 で -27、段 10 で 0。
func test_volume_steps() -> String:
	if Sfx.step_to_db(0) > -79.0:
		return "step 0 must be silent"
	if Sfx.step_to_db(1) != -27.0 or Sfx.step_to_db(10) != 0.0 or Sfx.step_to_db(5) != -15.0:
		return "step table: %s %s %s" % [Sfx.step_to_db(1), Sfx.step_to_db(5), Sfx.step_to_db(10)]
	return ""


# §9.13: 効果音 12 種は 44.1 kHz・モノラル・16 ビットで 1.5 秒以下(clear だけ 3 秒以下)。BGM 3 曲は 1 曲 600 KB 以下。
func test_audio_assets() -> String:
	if Sfx.NAMES.size() != 12:
		return "12 sfx names"
	for n in Sfx.NAMES:
		var bytes := FileAccess.get_file_as_bytes("res://assets/sfx/%s.wav" % n)
		if bytes.size() < 44:
			return "missing sfx " + n
		var channels := bytes.decode_u16(22)
		var rate := bytes.decode_u32(24)
		var bits := bytes.decode_u16(34)
		var sec := float(bytes.decode_u32(40)) / (rate * channels * bits / 8)
		if channels != 1 or rate != 44100 or bits != 16 or sec > (3.0 if n == "clear" else 1.5):
			return "%s: ch %d rate %d bits %d sec %s" % [n, channels, rate, bits, sec]
	for n in Bgm.NAMES:
		var size := FileAccess.get_file_as_bytes("res://assets/bgm/%s.ogg" % n).size()
		if size == 0 or size > 600 * 1024:
			return "%s: %d bytes" % [n, size]
	return ""


# AC-28・E-16・E-36: 知らない名前の音を鳴らしても落ちない。音量 0 では鳴らさない。
func test_audio_missing_is_silent() -> String:
	var sfx = Sfx.new()
	root.add_child(sfx)
	sfx.play("no_such_sound")
	sfx.set_volume(0)
	sfx.play("tap")
	var bgm = Bgm.new()
	root.add_child(bgm)
	bgm.play("no_such_track")
	bgm.unlock()
	bgm.set_volume(0)
	bgm.set_paused(true)
	sfx.queue_free()
	bgm.queue_free()
	return ""


# 設定の写し: 速さ「速い」は 0.6 倍、演出「控えめ」は lite。
func test_tokens_settings() -> String:
	Tokens.apply_settings({"speed": "fast", "fx": "lite"})
	if not is_equal_approx(Tokens.t(1.0), 0.6) or not Tokens.lite:
		return "fast + lite"
	Tokens.apply_settings({"speed": "normal", "fx": "full"})
	if Tokens.t(1.0) != 1.0 or Tokens.lite:
		return "normal + full"
	# INV-13: 当たり外れが分かるまで(滑り + めくり)が 0.5 秒以内
	if Tokens.DEAL + Tokens.FLIP > 0.5:
		return "reveal takes longer than 0.5 s"
	return ""


# FR-16: 途中のランを、状態と集計値ごと復元する。
func test_rebuild_with_stats() -> String:
	var played := _play("P1", "LL1:test:14")
	var st = played[0]
	var s = played[1]
	var r := RunStats.rebuild("LL1:test:14", st.actions, "run", false, true)
	if not r["ok"]:
		return "rebuild failed"
	var a = r["stats"]
	for k in ["draws", "hits", "misses", "banks", "best_streak", "max_gain", "max_bank", "longshot_hits", "score", "cleared", "end_lives"]:
		if a.get(k) != s.get(k):
			return "%s: %s vs %s" % [k, str(a.get(k)), str(s.get(k))]
	if RunStats.rebuild("LL1:test:14", "BHL", "run", false, true)["ok"]:
		return "bank with empty pot must fail"
	var part := RunStats.rebuild("LL1:test:14", st.actions.substr(0, 10), "run", false, true)
	if not part["ok"] or part["state"].actions != st.actions.substr(0, 10):
		return "partial rebuild"
	return ""


# 画面を実際に組み立てて動かす。演出は Tween を手で最後まで進める(FR-11 の飛ばしと同じ道)。
# [最後の 1 手の前までの操作, 最後の 1 手, 終わり方] を、横長と縦長、標準と控えめで通す。
func test_play_screen_runs_to_the_end() -> String:
	var clear_actions: String = _play("P1", "LL1:test:14")[0].actions
	var cases := [
		["LL1:test:14", clear_actions.left(-1), clear_actions.right(1), "clear"],
		["LL1:test:2", "LLLLL", "H", "gameover"],
	]
	for lite in [false, true]:
		Tokens.apply_settings({"speed": "normal", "fx": "lite" if lite else "full"})
		for c in cases:
			for landscape in [true, false]:
				var app := StubApp.new(_fresh_store(), root)
				var r := RunStats.rebuild(c[0], c[1], "run", false, true)
				var play = PlayScreen.new()
				play.setup(app, r["state"], r["stats"], "run", "2026-11-11", false)
				var got := []
				play.finished.connect(func(info: Dictionary): got.append(info))
				root.add_child(play)
				play.relayout(landscape, Rect2(Vector2.ZERO, PlayLayout.size(landscape)))
				play._act(c[2], true)
				if not play.busy:
					return "%s: flip did not start" % c[3]
				play._skip_flip()
				if play.busy:
					return "%s: flip did not finish" % c[3]
				play._finish_post()
				var err := ""
				if got.size() != 1 or got[0]["state"].ended != c[3]:
					err = "%s (lite %s, landscape %s): finished %d times" % [c[3], lite, landscape, got.size()]
				elif not "A-01" in got[0]["new_achievements"]:
					err = "%s: A-01 missing in %s" % [c[3], str(got[0]["new_achievements"])]
				elif app.save.data["totals"]["runs"] != 1 or app.save.current("run") != null:
					err = "%s: run not recorded" % c[3]
				if err == "":
					# 結果画面も、同じ結果で両方の配置に組めること
					var res = ResultScreen.new()
					res.setup(app, got[0], 0)
					root.add_child(res)
					for l2 in [true, false]:
						res.relayout(l2, Rect2(Vector2.ZERO, PlayLayout.size(l2)))
					res.free()
				play.free()
				app.free_nodes()
				if err != "":
					return err
	Tokens.apply_settings({})
	return ""


# 確保・無効な手・演出中の連打(E-3・E-5)と、手ほどきの進み方(FR-12)。
func test_play_screen_moves() -> String:
	Tokens.apply_settings({})
	var app := StubApp.new(_fresh_store(), root)
	var st = RunState.new("x", _ordered_deck())
	var play = PlayScreen.new()
	play.setup(app, st, RunStats.new("run", false), "run", "2026-11-11", true)
	root.add_child(play)
	play.relayout(true, Rect2(0, 0, 1280, 720))
	var err := ""
	if play.tut_step != 1 or not play.tut.visible:
		err = "tutorial 1 must show at the start"
	play._act("B", true)
	if err == "" and (st.actions != "" or play.busy):
		err = "bank with empty pot must do nothing"
	# 同じフレームの 2 つ目は捨てる(E-4)
	play._act("H", true)
	if err == "" and st.actions != "":
		err = "second input in the same frame must be dropped"
	# フレームを進められないので、印を戻して次の手として打つ
	play.last_input_frame = -1
	play._act("H", true)
	play.last_input_frame = -1
	play._act("H", true)
	if err == "" and (st.actions != "H" or play.busy):
		err = "second press during the flip must only skip it: actions %s busy %s" % [st.actions, play.busy]
	if err == "" and play.tut_step != 2:
		err = "tutorial 2 after the first move"
	play.last_input_frame = -1
	play._act("H", true)
	play._skip_flip()
	if err == "" and play.tut_step != 3:
		err = "tutorial 3 once the pot is positive, got %d" % play.tut_step
	play.last_input_frame = -1
	play._act("B", true)
	play._finish_post()
	if err == "" and (st.actions != "HHB" or st.score == 0 or play.shown["score"] != float(st.score) or play.shown["pot"] != 0.0):
		err = "bank: actions %s score %d shown %s" % [st.actions, st.score, str(play.shown)]
	if err == "" and (play.tut_step != -1 or not app.save.data["tutorial_done"]):
		err = "tutorial must be done after 3 tips"
	if err == "" and app.save.current("run")["actions"] != "HHB":
		err = "progress must be saved after each move"
	# 一時停止・設定・タイトルも、両方の配置に組めること
	play.last_input_frame = -1
	play._toggle_pause()
	if err == "" and play.pause_layer == null:
		err = "pause did not open"
	play.relayout(false, Rect2(0, -100, 720, 1480))
	play._act("H", true)
	if err == "" and st.actions != "HHB":
		err = "moves must be ignored while paused"
	play.free()
	var settings = SettingsScreen.new()
	settings.setup(app)
	root.add_child(settings)
	var title = TitleScreen.new()
	title.setup({"has_continue": true, "daily_no": 315, "daily_first": 2720, "ach_done": 3, "ach_total": 35, "title_rank": 2})
	root.add_child(title)
	for l in [true, false]:
		settings.relayout(l, Rect2(Vector2.ZERO, PlayLayout.size(l)))
		title.relayout(l, Rect2(Vector2.ZERO, PlayLayout.size(l)))
	if err == "" and not title.versus.disabled:
		err = "versus must stay disabled until Phase 7"
	# 追補 1 §7.1: ブラックジャックとポーカーのボタンは押せて、main が知っている画面へ行く
	var pages := []
	title.page_pressed.connect(func(p: String): pages.append(p))
	for b in title.menu.find_children("*", "Button", true, false):
		if b.text in [S.BTN_BJ, S.BTN_POKER] and not b.disabled:
			b.pressed.emit()
	if err == "" and (pages != ["blackjack", "poker"] or not Main.PAGES.has_all(pages)):
		err = "title must open blackjack and poker: " + str(pages)
	settings._store("fx", "lite")
	if err == "" and (app.save.data["settings"]["fx"] != "lite" or app.applied != 1):
		err = "settings must save and apply at once"
	settings.free()
	title.free()
	app.free_nodes()
	Tokens.apply_settings({})
	return err


# ---- Phase 4 ----

# FR-20: 選べるのは解放済みの物だけ。種類の違う ID・知らない ID は選べない。
func test_collection_select() -> String:
	var store = _fresh_store()
	if store.select("card_back", "B-03") or store.select("table", "T-02") or store.select("card_back", "T-01") or store.select("table", "B-01") or store.select("card_back", "B-99") or store.select("name", "B-01"):
		return "locked or wrong items must not be selectable"
	if not store.select("card_back", "B-02") or store.data["settings"]["card_back"] != "B-02":
		return "B-02 is unlocked from the start"
	store.finish_run(_play("P1", "LL1:test:14")[1], "2026-11-11", 315)
	if not store.select("card_back", "B-04") or not store.select("table", "T-02"):
		return "B-04 (A-13) and T-02 (title 2) must unlock after a clear run"
	store = SaveStore.new(TEST_SAVE)
	if store.data["settings"]["card_back"] != "B-04" or store.data["settings"]["table"] != "T-02":
		return "selection must persist"
	return ""


# テーブルの着せ替え: 色が差し替わり、T-01 に戻すと元の値に戻る。裏面とテーブルの定義が core と合っている。
func test_table_palettes() -> String:
	Tokens.apply_settings({"table": "T-02", "card_back": "B-07"})
	if Tokens.BG_DEEP != Color("#1E0F14") or Tokens.BRASS != Color("#D9B36A") or Tokens.card_back != "B-07":
		return "T-02 not applied"
	Tokens.apply_settings({"table": "T-99", "card_back": "B-99"})
	if Tokens.table != "T-01" or Tokens.card_back != "B-01":
		return "unknown ids must fall back"
	if Tokens.BG_DEEP != Color("#0E1F1C") or Tokens.BRASS_HI != Color("#F0D28A") or Tokens.BET_TOP != Color("#27594E"):
		return "T-01 must restore the exact colors"
	if Tokens.TABLES.keys() != Progress.TABLES.keys() or Tokens.BACKS.keys() != Progress.BACKS.keys():
		return "ids differ between tokens and progress"
	if S.TABLES.keys() != Progress.TABLES.keys() or S.CARD_BACKS.keys() != Progress.BACKS.keys():
		return "ids differ between strings and progress"
	return ""


# FR-14・D-9: 今日の山札をプレイ画面で 2 回終える。1 回目だけが記録に数えられ、2 回目の結果画面は初回を並べて出す。
func test_daily_through_play_screen() -> String:
	Tokens.apply_settings({})
	var app := StubApp.new(_fresh_store(), root)
	var date := "2026-11-11"
	var seed_text := DayIndex.daily_seed_text(date)
	var all: String = _play("P1", seed_text)[0].actions
	var err := ""
	for attempt in [1, 2]:
		var first: bool = app.save.is_first_daily(date)
		if first != (attempt == 1):
			err = "attempt %d: first_daily %s" % [attempt, first]
		var r := RunStats.rebuild(seed_text, all.left(-1), "daily", first, true)
		var play = PlayScreen.new()
		play.setup(app, r["state"], r["stats"], "daily", date, false)
		var got := []
		play.finished.connect(func(info: Dictionary): got.append(info))
		root.add_child(play)
		play.relayout(true, Rect2(0, 0, 1280, 720))
		if err == "" and not play.mode_label.text.contains("315"):
			err = "mode label must show the daily number: " + play.mode_label.text
		play._act(all.right(1), true)
		play._skip_flip()
		play._finish_post()
		if err == "" and (got.size() != 1 or got[0]["result"]["attempt"] != attempt):
			err = "attempt %d did not finish as expected" % attempt
		if err == "":
			var res = ResultScreen.new()
			res.setup(app, got[0], 0)
			root.add_child(res)
			res.relayout(false, Rect2(0, 0, 720, 1280))
			# 「結果をコピー」は、スクロールする中身ではなく下の固定の段にある(中身が長い回に隠れないように)
			if res.buttons.size() != 3 or res.buttons[2].text != S.BTN_COPY_RESULT or res.buttons[2].get_parent() != res.btn_box:
				err = "the copy button must sit in the fixed row"
			res.free()
		play.free()
	var d: Dictionary = app.save.data
	if err == "" and (d["totals"]["runs"] != 1 or d["daily"][date]["attempts"] != 2 or d["top_runs"].size() != 1 or d["current_daily"] != null):
		err = "only the first attempt counts: runs %d attempts %d" % [d["totals"]["runs"], d["daily"][date]["attempts"]]
	if err == "" and not "A-23" in d["achievements"]:
		err = "A-23 after the first daily"
	app.free_nodes()
	return err


# FR-18〜FR-20・FR-25・FR-26: 一覧の画面と保存データの画面が、空の記録でも遊んだ後でも、両方の配置に組める。
func test_pages_build() -> String:
	Tokens.apply_settings({})
	var app := StubApp.new(_fresh_store(), root)
	var err := ""
	for played in [false, true]:
		if played:
			app.save.finish_run(_play("P1", "LL1:test:14")[1], "2026-11-11", 315)
		for script in [AchievementsScreen, RecordsScreen, CollectionScreen, SaveDataScreen]:
			var page = script.new()
			page.setup(app)
			root.add_child(page)
			for l in [true, false]:
				page.relayout(l, Rect2(Vector2.ZERO, PlayLayout.size(l)))
			if script == AchievementsScreen and err == "" and page.side.text != S.ACH_COUNT % [app.save.data["achievements"].size(), 35]:
				err = "achievement count: " + page.side.text
			# 通算の表・見出し・「まだ記録がありません」の 3 つと、追補 1 の見出しと表が 3 組
			if script == RecordsScreen and err == "" and not played and page.body.get_child_count() != 9:
				err = "empty records must show the empty line and the wallet sections"
			if script == SaveDataScreen and err == "":
				page.import_box.text = "abc"
				page._check_import()
				if page.import_confirm.visible or page.note.text != S.IMPORT_FAILED:
					err = "bad import text must be refused"
				page.import_box.text = app.save.export_text()
				page._check_import()
				if err == "" and not page.import_confirm.visible:
					err = "good import text must ask before overwriting"
				if err == "" and page.erase_confirm.visible:
					err = "erase needs a first press"
			page.free()
	app.free_nodes()
	return err


# E-19: 通知の待ちは 4 つまで。超えた分は出さない。
func test_toast_queue() -> String:
	var toast = ToastPart.new()
	root.add_child(toast)
	toast.size = Vector2(370, 76)
	for i in 8:
		toast.push("name %d" % i)
	# 1 つ目は表示中、待ちは 4 つまで(2 つ目から 5 つ目)
	var err := "" if toast.busy and toast.queue.size() == 4 else "queue size %d" % toast.queue.size()
	toast.free()
	return err


# 画面を含む全部のスクリプトが、構文エラーなしで読み込める(画面のコードはほかのテストが触らないため)。
func test_all_scripts_load() -> String:
	for dir in ["res://core", "res://ui", "res://save", "res://audio", "res://net"]:
		for file in _gd_files(dir):
			var script = load(file)
			if script == null or not script.can_instantiate():
				return "cannot load " + file
	return ""


# ---- 追補 1(ブラックジャックとポーカー) ----

# 数字(1 = A … 13 = K)とマークから札の番号を作る。
func _c(rank: int, suit: int = 0) -> int:
	return suit * 13 + rank - 1


# 配る順(プレイヤー、ディーラー、プレイヤー、ディーラー、その後に引く札)に数字を並べた山札で、勝負を 1 つ作る。
func _bj(ranks: Array, bet: int = 100):
	var cards := PackedInt32Array()
	for i in ranks.size():
		cards.append(_c(ranks[i], i % 4))
	return BJ.new(cards, bet)


# AC-A1: 合計の計算と、11 と数えている A が残っているか。
func test_bj_totals() -> String:
	for c in [[[1, 13], 21, true], [[1, 1, 9], 21, true], [[1, 6, 13], 17, false], [[13, 12, 2], 22, false], [[1, 6], 17, true], [[11, 12], 20, false], [[1, 1], 12, true]]:
		var v := BJ.value(c[0].map(func(r): return _c(r)))
		if v["total"] != c[1] or v["soft"] != c[2]:
			return "%s -> %s" % [str(c[0]), str(v)]
	return ""


# AC-A2: 最初の 2 枚で 21。
func test_bj_naturals() -> String:
	for c in [[[1, 9, 13, 7], 100, "natural", 250], [[1, 9, 13, 7], 10, "natural", 25], [[1, 1, 13, 13], 100, "push", 100], [[9, 1, 7, 13], 100, "lose", 0]]:
		var h = _bj(c[0], c[1])
		if not h.done or h.result != c[2] or h.returned != c[3]:
			return "%s -> %s %d" % [str(c[0]), h.result, h.returned]
	return ""


# AC-A3・AC-A4: ディーラーの引き方と、勝ち・負け・引き分け・バーストの戻り。
func test_bj_stand_and_hit() -> String:
	# [山札, ヒットの回数, 結果, 戻り, ディーラーの枚数]
	for c in [
		[[10, 10, 9, 6, 5], 0, "lose", 0, 3],
		[[10, 1, 9, 6, 5], 0, "win", 200, 2],
		[[10, 10, 9, 7, 5], 0, "win", 200, 2],
		[[10, 10, 7, 9], 0, "lose", 0, 2],
		[[10, 10, 8, 8], 0, "push", 100, 2],
		[[10, 10, 7, 6, 13], 0, "win", 200, 3],
		[[10, 10, 6, 6, 13], 1, "bust", 0, 2],
		[[5, 10, 6, 7, 13], 1, "win", 200, 2],
		[[2, 10, 3, 6, 4, 5, 2], 2, "", 0, 2],
	]:
		var h = _bj(c[0])
		if h.done:
			return "%s must not end on the deal" % str(c[0])
		for i in c[1]:
			h.hit()
		if c[2] == "":
			if h.done:
				return "%s must still be open after %d hits" % [str(c[0]), c[1]]
			continue
		# ヒットで 21 か 22 以上になったら、スタンドを待たずに勝負が付く(FR-A12)
		if c[1] > 0 and not h.done:
			return "%s must end by itself" % str(c[0])
		h.stand()
		if h.result != c[2] or h.returned != c[3] or h.dealer.size() != c[4]:
			return "%s -> %s %d dealer %d" % [str(c[0]), h.result, h.returned, h.dealer.size()]
		h.hit()
		h.stand()
		h.double_down()
		if h.returned != c[3] or h.player.size() != 2 + c[1]:
			return "%s changed after the end" % str(c[0])
	return ""


# AC-A5: ダブル。
func test_bj_double() -> String:
	var h = _bj([5, 10, 6, 7, 13])
	if not h.can_double(100) or h.can_double(99):
		return "can_double must compare the wallet with the bet"
	h.double_down()
	if not h.done or h.bet != 200 or h.player.size() != 3 or h.result != "win" or h.returned != 400:
		return "double win: %s bet %d returned %d" % [h.result, h.bet, h.returned]
	h = _bj([10, 10, 6, 6, 13])
	h.double_down()
	if h.result != "bust" or h.returned != 0 or h.bet != 200 or h.dealer.size() != 2:
		return "double bust: " + h.result
	h = _bj([2, 10, 3, 6, 4, 5, 2])
	h.hit()
	if h.done or h.can_double(1000):
		return "no double after the third card"
	h.double_down()
	if h.bet != 100 or h.player.size() != 3:
		return "double_down after a hit must do nothing"
	return ""


# AC-A8・AC-A9・E-A10: 持ち点の出し入れと補充。どれも保存される。
func test_casino_wallet() -> String:
	var store = _fresh_store()
	if store.data["casino"]["wallet"] != B.WALLET_START or store.casino_refill():
		return "a new save starts at WALLET_START without a refill"
	if store.casino_pay(0) or store.casino_pay(B.WALLET_START + 1) or store.data["casino"]["wallet"] != B.WALLET_START:
		return "pay must refuse 0 and more than the wallet"
	if not store.casino_pay(100) or SaveStore.new(TEST_SAVE).data["casino"]["wallet"] != 900:
		return "pay must take the bet and save"
	store.casino_settle(250, {"bj_hands": 1, "bj_wins": 1, "bj_naturals": 1})
	var c: Dictionary = SaveStore.new(TEST_SAVE).data["casino"]
	if c["wallet"] != 1150 or c["wallet_peak"] != 1150 or c["bj_hands"] != 1 or c["bj_wins"] != 1 or c["bj_naturals"] != 1:
		return "settle: " + str(c)
	store.casino_settle(0, {"bj_hands": 1})
	if store.data["casino"]["wallet"] != 1150 or store.data["casino"]["bj_hands"] != 2 or store.data["casino"]["bj_wins"] != 1:
		return "a loss must only count the hand"
	store.data["casino"]["wallet"] = B.WALLET_MAX - 10
	store.casino_settle(100, {})
	if store.data["casino"]["wallet"] != B.WALLET_MAX or store.data["casino"]["wallet_peak"] != B.WALLET_MAX:
		return "the wallet must stop at WALLET_MAX"
	store.data["casino"]["wallet"] = B.BET_CHOICES[0]
	if store.casino_refill() or store.data["casino"]["refills"] != 0:
		return "no refill while the smallest bet is affordable"
	store.data["casino"]["wallet"] = B.BET_CHOICES[0] - 1
	if not store.casino_refill():
		return "refill below the smallest bet"
	c = SaveStore.new(TEST_SAVE).data["casino"]
	if c["wallet"] != B.WALLET_START or c["refills"] != 1:
		return "refill: " + str(c)
	return ""


# AC-A10: 保存データの casino。古いデータには既定値が入り、壊れた値はその項目だけ戻り、書き出しと消去にも乗る。
func test_casino_save() -> String:
	var want: Dictionary = Codec.defaults()["casino"]
	if want["wallet"] != B.WALLET_START or want["wallet_peak"] != B.WALLET_START or want["pk_best"] != 0 or want.size() != 9:
		return "defaults: " + str(want)
	var old: Dictionary = Codec.defaults("Alice")
	old.erase("casino")
	old["totals"]["runs"] = 3
	var res := Codec.sanitize(old)
	if res["broken"] or res["data"]["casino"] != want or res["data"]["totals"]["runs"] != 3 or res["data"]["settings"]["name"] != "Alice":
		return "a save without casino must get the defaults and keep the rest"
	old["casino"] = {"wallet": -5, "wallet_peak": "x", "refills": 2.5, "bj_hands": 7.0, "bj_wins": B.WALLET_MAX, "pk_best": 10, "junk": 1}
	var got: Dictionary = Codec.sanitize(old)["data"]["casino"]
	if got["wallet"] != B.WALLET_START or got["wallet_peak"] != B.WALLET_START or got["refills"] != 0 or got["pk_best"] != 0:
		return "bad values must fall back: " + str(got)
	if got["bj_hands"] != 7 or not got["bj_hands"] is int or got["bj_wins"] != B.WALLET_MAX or got.has("junk"):
		return "good values must stay: " + str(got)
	old["casino"]["wallet"] = B.WALLET_MAX + 1
	for junk in ["x", 5, [], null]:
		var raw: Dictionary = old.duplicate(true)
		raw["casino"] = junk
		if Codec.sanitize(raw)["data"]["casino"] != want:
			return "casino of a wrong type must reset"
	if Codec.sanitize(old)["data"]["casino"]["wallet"] != B.WALLET_START:
		return "a wallet above WALLET_MAX must reset"
	var store = _fresh_store()
	store.casino_pay(100)
	store.casino_settle(250, {"bj_hands": 1, "bj_wins": 1})
	var back := Codec.from_export(store.export_text())
	if not back["ok"] or back["data"]["casino"] != store.data["casino"] or back["data"]["casino"]["wallet"] != 1150:
		return "export and import must carry casino"
	store.erase_all()
	if store.data["casino"] != want:
		return "erase must reset casino"
	return ""


# AC-A11: ブラックジャックの卓を両方の配置に組み、勝負を最後まで進める。動きの間と同じフレームの入力は捨てる。
func test_blackjack_screen() -> String:
	Tokens.apply_settings({})
	CasinoTable.last_bets.clear()
	var app := StubApp.new(_fresh_store(), root)
	# 鳴らしたまま終了すると、再生中の音が「残った物」として終了時に報告されることがあるので、鳴らさない
	app.sfx.set_volume(0)
	var t = FixedBlackjack.new()
	t.setup(app)
	var backs := []
	t.back_pressed.connect(func(): backs.append(1))
	root.add_child(t)
	t.relayout(true, Rect2(0, 0, 1280, 720))
	var w: Dictionary = app.save.data["casino"]
	var err := ""
	if t.phase != "bet" or t.bet != B.BET_DEFAULT or t.bet_buttons.size() != 4 or t.back.disabled or not t.deal.visible or t.actions["hit"].visible:
		err = "must open in the betting phase with the default bet"
	# プレイヤー 10・7、ディーラー 10・6、ディーラーが K を引いてバースト
	t.fixed = PackedInt32Array([_c(10), _c(10, 1), _c(7), _c(6, 1), _c(13)])
	t._deal()
	if err == "" and (t.phase != "play" or not t.busy or SaveStore.new(TEST_SAVE).data["casino"]["wallet"] != 900 or t.wallet_num.text != "900"):
		err = "deal must take the bet and save it at once"
	t._back()
	if err == "" and not backs.is_empty():
		err = "back must not work during a hand"
	t._finish_tween()
	if err == "" and (t.busy or t.totals["player"].text != "17" or t.totals["dealer"].text != "10" or not t.back.disabled or t.deal.visible or not t.actions["hit"].visible):
		err = "after the deal: player %s dealer %s" % [t.totals["player"].text, t.totals["dealer"].text]
	# 「配る」と同じフレームなので、印を戻さない 1 回目は捨てる(E-A4)
	t._act("stand")
	if err == "" and t.hand.done:
		err = "second input in the same frame must be dropped"
	t.last_input_frame = -1
	t._act("stand")
	if err == "" and (w["wallet"] != 1100 or w["bj_hands"] != 1 or t.wallet_num.text != "900"):
		err = "the result must be saved at once and shown after the motion"
	t.relayout(false, Rect2(0, 0, 720, 1280))
	if err == "" and (t.phase != "bet" or t.busy or t.message.text != S.BJ_RESULTS["win"] or t.totals["dealer"].text != "26" or t.wallet_num.text != "1,100" or w["bj_wins"] != 1 or t.back.disabled):
		err = "win by dealer bust: %s dealer %s wallet %s" % [t.message.text, t.totals["dealer"].text, t.wallet_num.text]
	# ダブル: 5・6 に K を引いて 21、ディーラーは 10・7
	t._pick_bet(500)
	t.fixed = PackedInt32Array([_c(5), _c(10, 1), _c(6), _c(7, 1), _c(13)])
	t.last_input_frame = -1
	t._deal()
	# 配る動きの間の入力は捨てる(E-A4)
	t.last_input_frame = -1
	t._act("double")
	if err == "" and (t.hand.bet != 500 or t.rows["player"].size() != 2):
		err = "input during the deal must be dropped"
	t._finish_tween()
	t.last_input_frame = -1
	t._act("double")
	t._finish_tween()
	if err == "" and (w["wallet"] != 2100 or w["wallet_peak"] != 2100 or w["bj_wins"] != 2 or t.rows["player"].size() != 3 or t.stake != 1000 or t.bet != 500 or CasinoTable.last_bets["bj"] != 500):
		err = "double: wallet %d stake %d" % [w["wallet"], t.stake]
	# ダブルに足りない(E-A3)。バーストでは、ディーラーの裏の札を開けない
	w["wallet"] = 150
	t._pick_bet(100)
	t.fixed = PackedInt32Array([_c(10), _c(10, 1), _c(6), _c(6, 1), _c(13)])
	t.last_input_frame = -1
	t._deal()
	t._finish_tween()
	t.last_input_frame = -1
	t._act("double")
	if err == "" and (t.hand.bet != 100 or t.busy or not t.actions["double"].disabled or t.actions["hit"].disabled):
		err = "double must be refused when the wallet is short"
	t._act("hit")
	t._finish_tween()
	if err == "" and (t.message.text != S.BJ_RESULTS["bust"] or w["wallet"] != 50 or t.totals["dealer"].text != "10" or t.rows["dealer"][1].face_up):
		err = "bust: %s wallet %d" % [t.message.text, w["wallet"]]
	# E-A2: 払えない点を選んでいたら下げる。払えない選択肢は押せない
	if err == "" and (t.bet != 50 or not t.bet_buttons[2].disabled or t.bet_buttons[1].disabled):
		err = "the bet must drop to what the wallet can pay, got %d" % t.bet
	t._pick_bet(500)
	if err == "" and t.bet != 50:
		err = "a bet above the wallet must not be picked"
	# FR-A2: 賭けられないほど減ったら補充して、1 行知らせる
	w["wallet"] = 5
	t._enter_bet()
	if err == "" and (w["wallet"] != B.WALLET_START or w["refills"] != 1 or t.notice.text == "" or t.wallet_num.text != "1,000"):
		err = "refill on entering the betting phase"
	t._back()
	if err == "" and backs.size() != 1:
		err = "back must work in the betting phase"
	# 最初の 2 枚で 21: すぐ勝負が付き、戻りは 2.5 倍
	t.fixed = PackedInt32Array([_c(1), _c(9, 1), _c(13), _c(7, 1)])
	t.last_input_frame = -1
	t._deal()
	t._finish_tween()
	if err == "" and (t.phase != "bet" or t.message.text != S.BJ_RESULTS["natural"] or w["wallet"] != 1075 or w["bj_naturals"] != 1 or t.totals["dealer"].text != "16"):
		err = "natural: %s wallet %d" % [t.message.text, w["wallet"]]
	t.free()
	app.free_nodes()
	return err


# AC-A6: §6.3 の役。[数字 5 つ, 同じマークか, 役の番号]
func test_poker_hands() -> String:
	if B.POKER_PAYS != [0, 1, 2, 3, 4, 6, 9, 25, 50, 250] or S.POKER_HANDS.size() != B.POKER_PAYS.size():
		return "pays and hand names must have the 10 rows of the table"
	for c in [
		[[10, 11, 12, 13, 1], true, 9],
		[[13, 1, 10, 12, 11], true, 9],
		[[5, 6, 7, 8, 9], true, 8],
		[[1, 2, 3, 4, 5], true, 8],
		[[9, 9, 9, 9, 13], false, 7],
		[[3, 3, 3, 11, 11], false, 6],
		[[2, 5, 9, 11, 13], true, 5],
		[[12, 13, 1, 2, 3], true, 5],
		[[5, 6, 7, 8, 9], false, 4],
		[[1, 2, 3, 4, 5], false, 4],
		[[10, 11, 12, 13, 1], false, 4],
		[[7, 7, 7, 2, 13], false, 3],
		[[4, 4, 9, 9, 13], false, 2],
		[[11, 11, 2, 5, 9], false, 1],
		[[1, 1, 2, 5, 9], false, 1],
		[[10, 10, 2, 5, 9], false, 0],
		[[12, 13, 1, 2, 3], false, 0],
		[[2, 5, 9, 11, 13], false, 0],
	]:
		var hand := []
		for i in 5:
			hand.append(_c(c[0][i], 0 if c[1] else i % 4))
		if Poker.evaluate(hand) != c[2]:
			return "%s flush %s -> %d, want %d" % [str(c[0]), c[1], Poker.evaluate(hand), c[2]]
	return ""


# AC-A7: 交換。残さない札だけが、山札の 6 枚目から順に、左から入れ替わる。交換は 1 回だけ。
func test_poker_draw() -> String:
	# 0〜51 の順の山札: 最初の 5 枚はスペードの A〜5、続きは 6〜
	for c in [[[0, 2], [0, 5, 2, 6, 7], 5], [[0, 1, 2, 3, 4], [0, 1, 2, 3, 4], 8], [[], [5, 6, 7, 8, 9], 8], [[4], [5, 6, 7, 8, 4], 8]]:
		var h = Poker.new(_ordered_deck(), 100)
		if str(h.cards) != str([0, 1, 2, 3, 4]) or h.done:
			return "the deal must be the first 5 cards"
		h.draw(c[0])
		if str(h.cards) != str(c[1]) or not h.done or h.hand_rank != c[2] or h.returned != 100 * B.POKER_PAYS[c[2]]:
			return "hold %s -> %s rank %d returned %d" % [str(c[0]), str(h.cards), h.hand_rank, h.returned]
		h.draw([])
		if str(h.cards) != str(c[1]):
			return "a second draw must do nothing"
	return ""


# AC-A11: ポーカーの卓を両方の配置に組み、勝負を最後まで進める。動きの間と同じフレームの入力は捨てる。
func test_poker_screen() -> String:
	Tokens.apply_settings({})
	CasinoTable.last_bets.clear()
	var app := StubApp.new(_fresh_store(), root)
	app.sfx.set_volume(0)
	var t = FixedPoker.new()
	t.setup(app)
	root.add_child(t)
	t.relayout(true, Rect2(0, 0, 1280, 720))
	var w: Dictionary = app.save.data["casino"]
	var err := ""
	if t.phase != "bet" or t.cards[0].visible or t.pay_mark.visible or t._extra_key(KEY_1):
		err = "must open in the betting phase with no cards"
	# J のペアが配られ、3〜5 枚目を替えると J がもう 1 枚来てスリーカード
	t.fixed = _ordered_deck([_c(11), _c(11, 1), _c(2), _c(5, 1), _c(9, 2), _c(11, 2), _c(3, 3), _c(4, 3)])
	t._deal()
	t.last_input_frame = -1
	t._toggle(0)
	if err == "" and (not t.busy or not t.holds.is_empty() or SaveStore.new(TEST_SAVE).data["casino"]["wallet"] != 900):
		err = "deal must take the bet, and input during the deal must be dropped"
	t._finish_tween()
	if err == "" and (t.busy or t.phase != "play" or t.marked != 1 or not t.pay_mark.visible or not t.cards[4].visible or t.actions["draw"].disabled or not t.back.disabled):
		err = "after the deal the pair of jacks must be marked, got %d" % t.marked
	t.last_input_frame = -1
	t._toggle(0)
	# 同じフレームの 2 つ目は捨てる(E-A4)
	t._toggle(1)
	if err == "" and str(t.holds) != str([0]):
		err = "second input in the same frame must be dropped: " + str(t.holds)
	for i in [1, 1, 1]:
		t.last_input_frame = -1
		t._toggle(i)
	if err == "" and (str(t.holds) != str([0, 1]) or not t.hold_marks[1].visible or t.hold_marks[2].visible or t.cards[0].position.y != t.hits[0].position.y - t.HOLD_LIFT or t.cards[2].position.y != t.hits[2].position.y):
		err = "held cards must be marked and lifted: " + str(t.holds)
	# キーの 3 で 3 枚目を残し、もう一度で外す(§7.5)
	t.last_input_frame = -1
	if err == "" and (not t._extra_key(KEY_3) or str(t.holds) != str([0, 1, 2]) or t._extra_key(KEY_SPACE)):
		err = "key 3 must hold the third card"
	t.last_input_frame = -1
	t._extra_key(KEY_3)
	t.last_input_frame = -1
	t._act("draw")
	if err == "" and (w["wallet"] != 1200 or w["pk_hands"] != 1 or w["pk_paid"] != 1 or w["pk_best"] != 3 or t.wallet_num.text != "900"):
		err = "the result must be saved at once and shown after the motion: " + str(w)
	t.relayout(false, Rect2(0, 0, 720, 1280))
	if err == "" and (t.phase != "bet" or t.message.text != S.POKER_HANDS[3] or t.marked != 3 or t.wallet_num.text != "1,200" or not t.holds.is_empty() or t.cards[2].card != _c(11, 2) or t.cards[0].card != _c(11)):
		err = "three of a kind: %s marked %d" % [t.message.text, t.marked]
	# 役なしを全部残す。いちばん良い役は下がらない
	t.fixed = _ordered_deck([_c(2), _c(5, 1), _c(9, 2), _c(11, 3), _c(13)])
	t.last_input_frame = -1
	t._deal()
	t._finish_tween()
	if err == "" and (t.marked != 0 or t.pay_mark.visible):
		err = "no row may be marked without a hand"
	for i in 5:
		t.last_input_frame = -1
		t._toggle(i)
	t.last_input_frame = -1
	t._act("draw")
	t._finish_tween()
	if err == "" and (t.message.text != S.POKER_HANDS[0] or w["wallet"] != 1100 or w["pk_hands"] != 2 or w["pk_paid"] != 1 or w["pk_best"] != 3 or t.cards[4].card != _c(13)):
		err = "no hand: %s %s" % [t.message.text, str(w)]
	t.free()
	app.free_nodes()
	return err


# AC-A13・D-A9: 画面に出す文言に、チップ・コイン・お金・円・$ の字が無い。
func test_no_money_words() -> String:
	var texts := []
	_texts(load(STRINGS_PATH).get_script_constant_map().values(), texts)
	# このファイルには日本語の文字列を書けないので、文字の番号から言葉を作る
	for codes in [[0x30C1, 0x30C3, 0x30D7], [0x30B3, 0x30A4, 0x30F3], [0x304A, 0x91D1], [0x5186], [0x24]]:
		var word := ""
		for code in codes:
			word += String.chr(code)
		for t in texts:
			if t.contains(word):
				return "strings.gd has a money word: " + t
	return ""


# ---- Phase 6(対戦の接続実験) ----

# 招待か返事の項目を 1 つ作る。候補は、外向き 1 つと、自分の機械 0〜2 つ。
func _invite_items(kind: int, cand_count: int, derived: bool) -> Dictionary:
	var fp := PackedByteArray()
	for i in Invite.FP_SIZE:
		fp.append((i * 37 + cand_count * 11 + kind) % 256)
	var cands := []
	for i in cand_count:
		cands.append({"type": Invite.CAND_SRFLX if i == 0 else Invite.CAND_HOST, "ip": [203, 0, 113, 5 + i], "port": 50000 + i})
	return {
		"kind": kind, "fp": fp, "derived": derived, "ufrag": "" if derived else "Ab+/", "pwd": "" if derived else "abcdefghijklmnopqrstuv+/",
		"cands": cands, "reply_to": 0x1234 if kind == Invite.KIND_ANSWER else 0,
	}


# コードの中身(検査値の 2 バイトを除いたバイト列)。形の崩れたコードを作るのに使う。
func _code_body(code: String) -> PackedByteArray:
	var bytes := Marshalls.base64_to_raw(code.replace("-", "+").replace("_", "/") + "=".repeat((4 - code.length() % 4) % 4))
	return bytes.slice(0, bytes.size() - 2)


# AC-30: 項目 → コード → 項目が元に戻る。1 文字でも違えば落ちる。形の崩れた物で落ち、例外を出さない。
func test_invite_codec() -> String:
	if Invite.crc16("123456789".to_ascii_buffer()) != 0x29B1:
		return "crc16 of 123456789 must be 0x29B1"
	for kind in [Invite.KIND_INVITE, Invite.KIND_ANSWER]:
		for n in [1, 2, 3]:
			for derived in [false, true]:
				var items := _invite_items(kind, n, derived)
				var code := Invite.encode(items)
				var res := Invite.decode(code, kind)
				if code == "" or res["error"] != "" or res["items"] != items or Invite.encode(res["items"]) != code:
					return "round trip kind %d cands %d derived %s: %s" % [kind, n, derived, res["error"]]
				if res["check"] != Invite.crc16(_code_body(code)):
					return "check must be the crc of the body"
				var other: int = Invite.KIND_ANSWER if kind == Invite.KIND_INVITE else Invite.KIND_INVITE
				if Invite.decode(code, other)["error"] != "kind":
					return "a code of the other kind must be told apart"
	var code := Invite.encode(_invite_items(Invite.KIND_INVITE, 1, false))
	for i in code.length():
		var changed := code.substr(0, i) + ("B" if code[i] == "A" else "A") + code.substr(i + 1)
		if Invite.decode(changed, Invite.KIND_INVITE)["error"] == "":
			return "a code with character %d changed must fail" % i
	# 形の崩れた物。中身の位置: 0 = 版と種類、40 = 合言葉 pwd の 1 文字目、64 = 候補の数、66〜69 = IP、70・71 = ポート
	var body := _code_body(code)
	var cases := {"": "bad", "A".repeat(39): "bad", code.substr(0, 20) + "!" + code.substr(21): "bad", code + "=": "bad", code.left(-3): "bad"}
	for change in [[0, 0x21, "version"], [0, 0x13, "bad"], [1, 2, "bad"], [40, 10, "bad"], [40, 0, "bad"], [64, 0, "bad"], [64, 4, "bad"], [65, 3, "bad"]]:
		var b := body.duplicate()
		b[change[0]] = change[1]
		cases[Invite.pack(b)] = change[2]
	for zeroed in [[66, 67, 68, 69], [70, 71]]:
		var b := body.duplicate()
		for i in zeroed:
			b[i] = 0
		cases[Invite.pack(b)] = "bad"
	var no_cands := body.slice(0, 64)
	no_cands.append(0)
	cases[Invite.pack(no_cands)] = "bad"
	for text in cases:
		if Invite.decode(text, Invite.KIND_INVITE)["error"] != cases[text]:
			return "decode of a broken code (%d chars) gave %s, want %s" % [text.length(), Invite.decode(text, Invite.KIND_INVITE)["error"], cases[text]]
	# 検査を通らない項目からは、コードを作らない
	for change in [["ufrag", "a\nb"], ["pwd", ""], ["fp", PackedByteArray([1, 2, 3])], ["cands", []], ["reply_to", 5], ["kind", 3],
			["cands", [{"type": 1, "ip": [0, 0, 0, 0], "port": 5}]], ["cands", [{"type": 1, "ip": [10, 0, 0, 1], "port": 70000}]], ["cands", [{"type": 3, "ip": [10, 0, 0, 1], "port": 5}]]]:
		var items := _invite_items(Invite.KIND_INVITE, 1, false)
		items[change[0]] = change[1]
		if Invite.encode(items) != "":
			return "encode must refuse a bad %s" % change[0]
	for junk in [null, 5, "x", [], {}]:
		if Invite.encode(junk) != "" or Invite.to_sdp(junk) != "":
			return "encode and to_sdp must refuse junk"
	return ""


# AC-31: 貼られた文字からコードを取り出す。招待の欄に返事を渡すと、取り違えと分かる。
func test_invite_extract() -> String:
	var code := Invite.encode(_invite_items(Invite.KIND_INVITE, 2, false))
	var url := "https://example.github.io/luck-ladder/?j=" + code
	for text in [url, "hello\n" + url + "\nbye", code, "  " + code + "\r\n", url + "&lab=log", "?lab=log&j=" + code, "see " + code + " ok"]:
		if Invite.extract(text) != code:
			return "extract from: " + text.c_escape().left(60)
	if Invite.extract("no code in this text") != "" or Invite.extract("") != "":
		return "extract must return nothing when there is no code"
	var answer := Invite.encode(_invite_items(Invite.KIND_ANSWER, 1, true))
	var got := Invite.extract("https://example.github.io/luck-ladder/?a=" + answer)
	if got != answer or Invite.decode(got, Invite.KIND_INVITE)["error"] != "kind":
		return "an answer in the invite slot must be reported as the wrong kind"
	return ""


# AC-32 と §9.16 の行き来: 復元した接続情報に仕込んだ改行が入らない。自分の接続情報から項目を取り出せる。
func test_invite_sdp() -> String:
	var items := _invite_items(Invite.KIND_INVITE, 2, false)
	var sdp := Invite.to_sdp(items)
	var lines := sdp.split("\r\n")
	if lines.size() != 16 or lines[15] != "" or not "a=ice-ufrag:Ab+/" in lines or not "a=ice-pwd:abcdefghijklmnopqrstuv+/" in lines or not "a=setup:actpass" in lines:
		return "offer text: " + sdp.c_escape()
	for line in lines:
		if line.contains("\r") or line.contains("\n"):
			return "a line holds a line break"
	if not "a=setup:active" in Invite.to_sdp(_invite_items(Invite.KIND_ANSWER, 1, false)).split("\r\n"):
		return "an answer must be written as active"
	for bad in ["ab\r\na=evil:1", "ab cd", "a\tb", ""]:
		for key in ["ufrag", "pwd"]:
			var broken := items.duplicate(true)
			broken[key] = bad
			if Invite.to_sdp(broken) != "" or not Invite.candidate_lines(broken).is_empty():
				return "to_sdp must refuse %s %s" % [key, bad.c_escape()]
	# 復元した文と候補の行から、同じ項目が取り出せる
	var back := Invite.from_sdp(sdp, Array(Invite.candidate_lines(items)), false)
	for key in ["fp", "ufrag", "pwd", "cands", "derived"]:
		if back.get(key) != items[key]:
			return "from_sdp(to_sdp) lost " + key
	# 候補の選び方: UDP の IPv4 だけ、外向きを先に、3 つまで
	var cand_lines := [
		"candidate:1 1 udp 2113937151 0a1b2c3d-4e5f-6789-abcd-ef0123456789.local 54400 typ host generation 0",
		"candidate:2 1 udp 2122260223 192.168.1.5 54400 typ host generation 0",
		"candidate:3 1 tcp 1518280447 192.168.1.5 9 typ host tcptype active",
		"a=candidate:4 1 UDP 1686052607 203.0.113.9 61000 typ srflx raddr 192.168.1.5 rport 54400",
		"candidate:5 1 udp 2122197247 2001:db8::1 54401 typ host",
		"candidate:6 1 udp 41885695 198.51.100.7 3478 typ relay raddr 0.0.0.0 rport 0",
		"candidate:7 1 udp 2122260223 192.168.1.5 54400 typ host",
		"candidate:8 1 udp 2122260223 300.1.1.1 54400 typ host",
		"candidate:9 1 udp 2122260223 10.0.0.2 0 typ host",
		"junk", "", "candidate:10 1 udp 2113937151 not-a-uuid.local 54400 typ host",
	]
	var picked := Invite.pick_candidates(cand_lines)
	var want := [{"type": Invite.CAND_SRFLX, "ip": [203, 0, 113, 9], "port": 61000}, {"type": Invite.CAND_HOST, "ip": [192, 168, 1, 5], "port": 54400}]
	if picked != want:
		return "picked candidates: " + str(picked)
	# 実験用の足し: .local の名前の候補は、頼んだときだけ載る。コードと候補の行を行き来しても同じ名前に戻る
	var mdns := {"type": Invite.CAND_MDNS, "name": "0a1b2c3d4e5f6789abcdef0123456789".hex_decode(), "port": 54400}
	picked = Invite.pick_candidates(cand_lines, true)
	if picked != [want[0], mdns, want[1]]:
		return "picked candidates with names: " + str(picked)
	var named := _invite_items(Invite.KIND_ANSWER, 1, false)
	named["cands"] = picked
	var named_back := Invite.decode(Invite.encode(named), Invite.KIND_ANSWER)
	if named_back["error"] != "" or named_back["items"] != named or Invite.pick_candidates(Array(Invite.candidate_lines(named)), true) != picked:
		return "a name candidate must survive the code and the candidate line"
	if not Invite.candidate_lines(named)[1].contains(" 0a1b2c3d-4e5f-6789-abcd-ef0123456789.local 54400 typ host"):
		return "name candidate line: " + Invite.candidate_lines(named)[1]
	# 合言葉を省く手: 書き換えた自分の文と、相手が復元する文とで、合言葉が同じになる
	var munged := Invite.munge(sdp)
	var made := Invite.derive(items["fp"])
	var derived_items := _invite_items(Invite.KIND_INVITE, 2, true)
	derived_items["fp"] = items["fp"]
	if not Invite.is_ice_text(made[0]) or not Invite.is_ice_text(made[1]) or made[0].length() != 4 or made[1].length() != 24:
		return "derived credentials: " + str(made)
	for line in ["a=ice-ufrag:" + made[0], "a=ice-pwd:" + made[1]]:
		if not line in munged.split("\r\n") or not line in Invite.to_sdp(derived_items).split("\r\n"):
			return "both sides must use the derived credentials"
	if munged.split("\r\n").size() != lines.size() or Invite.from_sdp(munged, [], true)["fp"] != items["fp"]:
		return "munge must only rewrite the two credential lines"
	return ""


# AC-37: JavaScriptBridge は net/browser_bridge.gd にだけあり、JavaScript の文を文字列で実行していない。
func test_js_bridge_only_in_bridge() -> String:
	var word := "JavaScript" + "Bridge"
	for dir in ["res://core", "res://ui", "res://save", "res://audio", "res://net"]:
		for file in _gd_files(dir):
			var code := _code_only(file)
			if file == "res://net/browser_bridge.gd":
				if code.contains(word + ".eval") or not code.contains(word):
					return "browser_bridge.gd must use the bridge without eval"
			elif code.contains(word):
				return file + " uses " + word
	return ""


# 実験の画面が、ブラウザの外でも両方の配置に組めて、読めない文字を貼られても落ちない。
func test_net_lab_builds() -> String:
	Tokens.apply_settings({})
	var app := StubApp.new(_fresh_store(), root)
	var bridge = BrowserBridge.new()
	if bridge.url_query() != "" or bridge.can_read_clipboard() or bridge.can_share() or bridge.can_broadcast() or bridge.send_answer("x"):
		return "outside a browser the bridge must report that nothing is available"
	var lab = NetLab.new()
	lab.setup(app, bridge, "?lab=1")
	root.add_child(lab)
	for l in [true, false]:
		lab.relayout(l, Rect2(Vector2.ZERO, PlayLayout.size(l)))
	var err := ""
	lab._take_text("not a code", "box")
	if lab.status.text != S.NET_UNREADABLE or lab.rtc != null:
		err = "junk text must be refused without starting a connection"
	var v2 := _code_body(Invite.encode(_invite_items(Invite.KIND_INVITE, 1, false)))
	v2[0] = 0x21
	lab._take_text("https://example.github.io/luck-ladder/?j=" + Invite.pack(v2), "box")
	if err == "" and lab.status.text != S.NET_VERSION:
		err = "a code of another version must say so"
	# 招待を作っていないのに返事が来た(E-25)
	lab._take_text(Invite.encode(_invite_items(Invite.KIND_ANSWER, 1, false)), "box")
	if err == "" and (lab.status.text != S.NET_UNREADABLE or lab.rtc != null):
		err = "an answer without an invite must be refused"
	bridge.read_clipboard()
	if err == "" and lab.status.text != S.NET_PASTE_FAILED:
		err = "a refused clipboard must show the fallback line"
	if err == "" and lab._mask("candidate:1 1 udp 1 203.0.113.9 61000 typ srflx raddr 192.168.1.5 rport 54400").contains("203") :
		err = "the record must hide addresses"
	lab.free()
	app.free_nodes()
	return err


# ---- ソースの決まり ----

# AC-19(INV-1〜INV-3・INV-6・INV-15)。
func test_source_rules() -> String:
	var banned := RegEx.create_from_string("\\b(randi|randf|randomize|RandomNumberGenerator|shuffle|pick_random)\\b|\\bfloat\\(|\\b\\d+\\.\\d+\\b")
	for file in _gd_files("res://core"):
		var m := banned.search(_code_only(file))
		if m:
			return file + " contains " + m.get_string()
	var rule_names := RegEx.create_from_string("\\b(BASE|GAIN_CAP)\\b")
	for file in _gd_files("res://ui"):
		if rule_names.search(_code_only(file)):
			return file + " uses BASE or GAIN_CAP"
	var jp := RegEx.create_from_string("\"[^\"\\n]*[\\x{3040}-\\x{30FF}\\x{4E00}-\\x{9FFF}][^\"\\n]*\"")
	for dir in ["res://core", "res://ui", "res://save", "res://audio", "res://net", "res://tests", "res://tools"]:
		for file in _gd_files(dir):
			if file == STRINGS_PATH:
				continue
			var m := jp.search(_code_only(file))
			if m:
				return file + " has a Japanese literal " + m.get_string()
	var shaders := DirAccess.get_files_at("res://shaders")
	var n := 0
	for f in shaders:
		if f.ends_with(".gdshader"):
			n += 1
	if n != 2:
		return "shaders/ must hold exactly 2 shaders, found %d" % n
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
