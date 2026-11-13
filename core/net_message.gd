# 対戦のメッセージの組み立てと検査(§9.15)。データチャンネルに流す UTF-8 の JSON、1 通 NET_MSG_MAX バイトまで。
# 相手から届いた文字は、parse を通った物だけを使う(INV-16)。parse は、型と範囲を確かめた項目だけを写して返す。
# JSON の数は小数として読まれるので、整数かどうかと範囲を見てから int にする。
extends RefCounted

const B := preload("res://core/balance.gd")
const SaveCodec := preload("res://core/save_codec.gd")

# 通信の版(hello の v)。メッセージの形を変えたら上げる
const VERSION := 1
const SCORE_MAX := 99999999
const DRAWS_MAX := 51
const ROUND_MAX := 9999
const PING_MAX := 1000000000
const SEED_MAX := 64
const ENDED := ["", "gameover", "clear"]
const BYE_REASONS := ["leave", "version", "full", "closed"]
# end の results の status: 最後まで届いた / 時間切れまでに final が届かなかった / 切れた
const STATUSES := ["ok", "timeout", "disconnected"]
const SEED_CHARS := "0123456789LV:"


# ---- 組み立て ----

static func _text(m: Dictionary) -> String:
	return JSON.stringify(m)


static func hello(name: String) -> String:
	return _text({"t": "hello", "v": VERSION, "name": name})


# you は、受け取る人の席の番号(§9.15 の表に足した項目。これが無いと、ゲストが自分の行を見分けられない)。
static func lobby(players: Array, you: int) -> String:
	return _text({"t": "lobby", "players": players, "you": you})


static func start(seed_text: String, match_sec: int, round_no: int) -> String:
	return _text({"t": "start", "seed_text": seed_text, "match_sec": match_sec, "round": round_no})


# row は {id, round, score, pot, lives, streak, draws, ended}。best_streak があれば final、無ければ state。
static func state(row: Dictionary) -> String:
	var m := {"t": "final" if row.has("best_streak") else "state"}
	for key in ["id", "round", "score", "pot", "lives", "streak", "draws", "ended", "best_streak"]:
		if row.has(key):
			m[key] = row[key]
	return _text(m)


static func end(results: Array) -> String:
	return _text({"t": "end", "results": results})


static func ping(n: int) -> String:
	return _text({"t": "ping", "n": n})


static func pong(n: int) -> String:
	return _text({"t": "pong", "n": n})


static func bye(reason: String) -> String:
	return _text({"t": "bye", "reason": reason})


# 山札の種(ホストが作る)。
static func make_seed(unix_sec: int, usec: int, round_no: int) -> String:
	return "LLV:%d:%d:%d" % [unix_sec, usec, round_no]


# ---- 検査 ----

# 整数として読める数で、lo〜hi に入っていれば真。
static func _is_int(v, lo: int, hi: int) -> bool:
	return (v is int or v is float) and v >= lo and v <= hi and v == int(v)


static func _only(text: String, allowed: String) -> bool:
	for i in text.length():
		if not text[i] in allowed:
			return false
	return true


# 項目を型ごとに確かめて out に写す。1 つでも落ちたら偽。
static func _take(m: Dictionary, out: Dictionary, ints: Dictionary) -> bool:
	for key in ints:
		if not _is_int(m.get(key), ints[key][0], ints[key][1]):
			return false
		out[key] = int(m[key])
	return true


static func _row_ints() -> Dictionary:
	return {"id": [0, B.VERSUS_MAX - 1], "score": [0, SCORE_MAX], "draws": [0, DRAWS_MAX]}


# 届いた文字 → 検査を通った項目の辞書。落ちたら空の辞書。例外を出さない。
# round_now は今の対戦の番号(state と final は、これと同じ物だけを通す。対戦の外では 0 を渡す)。
static func parse(text: String, round_now: int) -> Dictionary:
	if text.to_utf8_buffer().size() > B.NET_MSG_MAX:
		return {}
	var json := JSON.new()
	if json.parse(text) != OK or not json.data is Dictionary:
		return {}
	var m: Dictionary = json.data
	var t = m.get("t")
	var out := {"t": t}
	match t:
		"hello":
			if not _take(m, out, {"v": [0, ROUND_MAX]}) or not SaveCodec.is_valid_name(m.get("name")):
				return {}
			out["name"] = m["name"]
		"lobby":
			var players = m.get("players")
			if not players is Array or players.size() < 1 or players.size() > B.VERSUS_MAX or not _take(m, out, {"you": [0, B.VERSUS_MAX - 1]}):
				return {}
			out["players"] = []
			for p in players:
				var row := {}
				if not p is Dictionary or not _take(p, row, {"id": [0, B.VERSUS_MAX - 1]}) or not SaveCodec.is_valid_name(p.get("name")):
					return {}
				row["name"] = p["name"]
				out["players"].append(row)
		"start":
			var seed_value = m.get("seed_text")
			if not seed_value is String or seed_value.length() > SEED_MAX or not seed_value.begins_with("LLV:") or not _only(seed_value, SEED_CHARS):
				return {}
			if not _take(m, out, {"round": [1, ROUND_MAX], "match_sec": [0, SCORE_MAX]}) or not out["match_sec"] in B.MATCH_SEC_CHOICES:
				return {}
			out["seed_text"] = seed_value
		"state", "final":
			var ints := _row_ints()
			ints.merge({"round": [round_now, round_now], "pot": [0, SCORE_MAX], "lives": [0, B.LIVES_MAX], "streak": [0, DRAWS_MAX]})
			if t == "final":
				ints["best_streak"] = [0, DRAWS_MAX]
			if round_now < 1 or not _take(m, out, ints) or not m.get("ended") in ENDED:
				return {}
			out["ended"] = m["ended"]
		"end":
			var results = m.get("results")
			if not results is Array or results.size() < 1 or results.size() > B.VERSUS_MAX:
				return {}
			out["results"] = []
			for r in results:
				var row := {}
				var ints := _row_ints()
				ints["best_streak"] = [0, DRAWS_MAX]
				if not r is Dictionary or not _take(r, row, ints) or not SaveCodec.is_valid_name(r.get("name")):
					return {}
				if not r.get("cleared") is bool or not r.get("status") in STATUSES:
					return {}
				row["name"] = r["name"]
				row["cleared"] = r["cleared"]
				row["status"] = r["status"]
				out["results"].append(row)
		"ping", "pong":
			if not _take(m, out, {"n": [0, PING_MAX]}):
				return {}
		"bye":
			if not m.get("reason") in BYE_REASONS:
				return {}
			out["reason"] = m["reason"]
		_:
			return {}
	return out
