# 1 ランの集計値(§9.6)。run_state の guess・bank の結果を受けて更新する。
# 実績(achievements.gd)は、この値と通算の値だけを見る。
extends RefCounted

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
		if w * 4 <= n:
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


# 実績と通算に数えるラン(D-9: 今日の山札の 2 回目からは数えない)。
func counts_for_records() -> bool:
	return mode != "daily" or first_daily
