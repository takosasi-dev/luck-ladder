# 1 ランの集計値(§9.6)。run_state の guess・bank の結果を受けて更新する。
# 実績(achievements.gd)は、この値と通算の値だけを見る。
extends RefCounted

const RunState := preload("res://core/run_state.gd")

var mode := "run"
var first_daily := false
var counter_shown := false
var draws := 0
var hits := 0
var misses := 0
var banks := 0
var same_tries := 0
var same_hits := 0
var best_streak := 0
var max_gain := 0
var max_bank := 0
var max_pot_lost := 0
var longshot_hits := 0
var sure_misses := 0
var life_regains := 0
var comeback := false
var cleared := false
var end_lives := 0
var score := 0
# 対戦(Phase 7 で入れる): 最後まで居たか、最後まで接続していた人数(自分を含む)、単独の 1 位か
var versus_done := false
var versus_players := 0
var versus_solo_first := false

var _was_one := false


func _init(mode_value: String = "run", first_daily_value: bool = false) -> void:
	mode = mode_value
	first_daily = first_daily_value


# 大穴: 当たりになる残り札が、残りの 4 分の 1 以下の側(§9.6)。演出の出し分けにも使う。
static func is_longshot(n: int, w: int) -> bool:
	return w * 4 <= n


# 残り札の表示が「入」のまま手を打ったら呼ぶ。
func note_counter(shown: bool) -> void:
	if shown:
		counter_shown = true


func on_guess(res: Dictionary, st) -> void:
	if res.get("result", "invalid") == "invalid":
		return
	var n: int = res["n"]
	var w: int = res["w"]
	draws += 1
	if res["side"] == "S":
		same_tries += 1
	if res["result"] == "hit":
		hits += 1
		if res["side"] == "S":
			same_hits += 1
		max_gain = maxi(max_gain, res["gain"])
		if is_longshot(n, w):
			longshot_hits += 1
		if res["life_up"]:
			life_regains += 1
	else:
		misses += 1
		max_pot_lost = maxi(max_pot_lost, res["pot_lost"])
		if w * 10 >= n * 9:
			sure_misses += 1
	best_streak = maxi(best_streak, st.streak)
	_track_lives(st.lives)
	_sync_end(st)


func on_bank(res: Dictionary, st) -> void:
	if res.get("result", "invalid") != "banked":
		return
	banks += 1
	max_bank = maxi(max_bank, res["amount"])
	_sync_end(st)


func _track_lives(lives: int) -> void:
	if lives == 1:
		_was_one = true
	elif _was_one and lives >= 3:
		comeback = true


func _sync_end(st) -> void:
	score = st.score
	end_lives = st.lives
	cleared = st.ended == "clear"


# 途中のランの復元(FR-16・D-10): 種と操作の列を流し直し、ランの状態と集計値を一緒に作る。
# 結果: {ok, state, stats}。途中で invalid が出たら ok は偽(E-9)。
static func rebuild(seed_text: String, action_text: String, mode_value: String, first_daily_value: bool, shown: bool) -> Dictionary:
	var st = RunState.new(seed_text)
	var s = new(mode_value, first_daily_value)
	s.counter_shown = shown
	for i in action_text.length():
		var a := action_text[i]
		var res: Dictionary = st.apply(a)
		if res["result"] == "invalid":
			return {"ok": false, "state": null, "stats": null}
		if a == "B":
			s.on_bank(res, st)
		else:
			s.on_guess(res, st)
	return {"ok": true, "state": st, "stats": s}


# 実績と通算に数えるラン(D-9: 今日の山札の 2 回目からは数えない)。
func counts_for_records() -> bool:
	return mode != "daily" or first_daily
