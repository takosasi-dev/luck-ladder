# 対戦 1 回の進行(§9.15): 参加者の表、届いた状態の写し、終わりの判定、結果と順位。
# 相手から届いた値は、相手の行と順位にだけ使う。自分の行は、自分のランからだけ変える(INV-16)。
# 当たり外れと得点は、各自の run_state が決める(INV-18)。ここは届いた数を並べるだけ。
extends RefCounted

const B := preload("res://core/balance.gd")

var my_id := 0
var round_no := 0
var match_sec := 0
var seed_text := ""
# 席の番号 → 行 {id, name, score, pot, lives, streak, draws, ended, best_streak, final, gone}
var players := {}


static func _fresh(id: int, name: String) -> Dictionary:
	return {"id": id, "name": name, "score": 0, "pot": 0, "lives": B.LIVES_START, "streak": 0, "draws": 0,
		"ended": "", "best_streak": 0, "final": false, "gone": false}


# 参加者の一覧 [{id, name}] と、自分の席の番号を入れる。得点などは初めの値に戻る。
func set_lobby(list: Array, you: int) -> void:
	my_id = you
	players = {}
	for p in list:
		players[p["id"]] = _fresh(p["id"], p["name"])


# 対戦を始める(「もう一戦」でも呼ぶ)。切れた人は表から外し、残った人の値を初めに戻す。
func begin(seed_value: String, sec: int, round_value: int) -> void:
	seed_text = seed_value
	match_sec = sec
	round_no = round_value
	for id in players.keys():
		if players[id]["gone"]:
			players.erase(id)
		else:
			players[id] = _fresh(id, players[id]["name"])


func _write(row: Dictionary) -> void:
	var p: Dictionary = players[row["id"]]
	for key in ["score", "pot", "lives", "streak", "draws", "ended"]:
		p[key] = row[key]
	p["best_streak"] = maxi(p["best_streak"], maxi(row["streak"], row.get("best_streak", 0)))
	if row.has("best_streak"):
		p["final"] = true


# 相手の state / final(net_message.parse を通った物)を写す。自分の行、知らない席、もう final が届いた席は変えない。
func apply_row(row: Dictionary) -> bool:
	var id: int = row["id"]
	if id == my_id or not players.has(id) or players[id]["final"]:
		return false
	_write(row)
	return true


# 自分の行を、自分のランの値で変える(row は row_from_run の形)。
func set_own(row: Dictionary) -> void:
	if players.has(my_id) and row["id"] == my_id and not players[my_id]["final"]:
		_write(row)


# ランと集計値 → 送る行。last が真なら final(best_streak 付き)。
static func row_from_run(st, stats, id: int, round_value: int, last: bool) -> Dictionary:
	var row := {"id": id, "round": round_value, "score": st.score, "pot": st.pot, "lives": st.lives,
		"streak": st.streak, "draws": stats.draws, "ended": st.ended}
	if last:
		row["best_streak"] = stats.best_streak
	return row


# 切れた・抜けた人。最後に届いた得点のまま、順位に載る(FR-45)。
func drop(id: int) -> void:
	if players.has(id):
		players[id]["gone"] = true


# 全員が、終えた(final)か切れたか。
func all_done() -> bool:
	for p in players.values():
		if not p["final"] and not p["gone"]:
			return false
	return true


# 最後までつながっていた人数(自分を含む。A-34・A-35)。
func connected_count() -> int:
	var n := 0
	for p in players.values():
		if not p["gone"]:
			n += 1
	return n


# 残り時間(ミリ秒)。時間切れなしの部屋では -1。始めた時刻からの経過で数える(E-32)。
func remaining_ms(started_ms: int, now_ms: int) -> int:
	if match_sec == 0:
		return -1
	return maxi(match_sec * 1000 - (now_ms - started_ms), 0)


# 結果の一覧(席の番号の順)。得点は確保した分だけ(ポットは入らない。FR-42)。
# final が届いた人は "ok"。届いていない人は、最後の state の得点で、切れていれば "disconnected"、そうでなければ "timeout"。
func results() -> Array:
	var out := []
	var ids := players.keys()
	ids.sort()
	for id in ids:
		var p: Dictionary = players[id]
		out.append({"id": id, "name": p["name"], "score": p["score"], "cleared": p["ended"] == "clear" and p["final"],
			"draws": p["draws"], "best_streak": p["best_streak"],
			"status": "ok" if p["final"] else "disconnected" if p["gone"] else "timeout"})
	return out


# 順位: 得点の大きい順。同点は同じ順位で、次の順位は人数ぶん飛ばす(1 位・1 位・3 位)。結果と同じ並びで返す。
static func ranks(results_list: Array) -> Array:
	var out := []
	for r in results_list:
		var rank := 1
		for other in results_list:
			if other["score"] > r["score"]:
				rank += 1
		out.append(rank)
	return out


# id の人が単独の 1 位か(同点の 1 位は含めない。A-34・A-35)。
static func solo_first(results_list: Array, id: int) -> bool:
	var mine := -1
	var top := 0
	for r in results_list:
		if r["id"] == id:
			mine = r["score"]
	for r in results_list:
		if r["score"] >= mine:
			top += 1
	return mine >= 0 and top == 1
