# 対戦の部屋 1 つの進行(§9.15)。通信の口(transport.gd)と versus_state をつなぐ:
# 招待と返事のやり取り、hello → lobby → start、手ごとの state の中継ぎ、ping と切断、end。
# 時刻は tick(now_ms) で外からもらう(テストで時計を進められるように)。招待と返事のコードは、シグナルで画面へ渡すだけで、どこにも書かない(INV-17)。
extends RefCounted

# ホスト: 席の状態が変わった(seats[link] を見る)
signal seat_changed(link: int)
# ゲスト: 返事のコードができた
signal answer_ready(code: String)
# ゲスト: 参加できなかった。reason は "no_route" / "no_rtc" / "expired" / "version" / "full" / "closed"
signal join_failed(reason: String)
signal lobby_changed
signal started(seed_text: String, match_sec: int, round_no: int)
signal rivals_changed
signal ended(results: Array)
# ゲスト: ホストとの接続が切れた(自分のランは続けられる。FR-45)
signal host_lost

const B := preload("res://core/balance.gd")
const Codec := preload("res://core/invite_codec.gd")
const Msg := preload("res://core/net_message.gd")
const VersusState := preload("res://core/versus_state.gd")

const PING_MS := 3000
# E-26: 返事を渡してから、つながらないまま過ぎたら失敗にする時間
const CONNECT_WAIT_MS := 20000
# 検査に落ちたメッセージが続いたら切る数(§9.15)
const BAD_MAX := 10
# ホストが、時間切れの後に final を待つ時間(§9.15)
const FINAL_GRACE_MS := 3000

var transport
var vs := VersusState.new()
var is_host := false
var my_name := ""
# "lobby"(待ち合わせ)/ "playing"(秒読みと対戦中)/ "ended"(結果)
var phase := "lobby"
var now := 0
var round_no := 0
# 秒読みが終わった時刻。0 は、まだ始まっていない
var started_ms := 0
var host_gone := false
# ゲスト: ホストの hello と lobby が届いた
var joined := false
# ホスト: 席(link 1〜3)→ {state, name, code, check, made_ms, answered_ms, reason, fails}
# state: "empty" / "making" / "inviting" / "answered" / "connected" / "failed" / "expired"
var seats := {}
# 開いている接続: link → {last_rx, times, bad}
var links := {}
var _invite_check := 0
var _answer_ms := 0
var _next_ping := 0
var _ping_n := 0


func _init(transport_value, host: bool, name: String) -> void:
	transport = transport_value
	is_host = host
	my_name = name
	transport.described.connect(_on_described)
	transport.opened.connect(_on_opened)
	transport.received.connect(_on_received)
	transport.closed.connect(_on_closed)
	if is_host:
		for link in range(1, B.VERSUS_MAX):
			seats[link] = _empty_seat(0)
		vs.set_lobby([{"id": 0, "name": my_name}], 0)


static func _empty_seat(fails: int) -> Dictionary:
	return {"state": "empty", "name": "", "code": "", "check": -1, "made_ms": 0, "answered_ms": 0, "reason": "", "fails": fails}


# ---- ホスト: 席 ----

# 席の招待を作り始める(作り直しも同じ)。できたら seats[link]["code"] に入り、seat_changed が出る。
func open_seat(link: int) -> bool:
	if not is_host or phase != "lobby" or not seats.has(link) or seats[link]["state"] == "connected":
		return false
	transport.drop(link)
	links.erase(link)
	seats[link] = _empty_seat(seats[link]["fails"])
	seats[link]["state"] = "making"
	if not transport.make_invite(link):
		_fail_seat(link, "no_rtc")
		return false
	seat_changed.emit(link)
	return true


func _fail_seat(link: int, reason: String) -> void:
	transport.drop(link)
	links.erase(link)
	var fails: int = seats[link]["fails"] + 1
	seats[link] = _empty_seat(fails)
	seats[link]["state"] = "expired" if reason == "expired" else "failed"
	seats[link]["reason"] = reason
	seat_changed.emit(link)


# 返事の文字(URL でもコードだけでも)を、対応する席に渡す。
# 結果: ""(渡した)/ "bad"(読めない・対応する席が無い。E-25)/ "version" / "kind"(招待を貼った。E-24)/ "started"(席が無い。E-29)
func take_answer_text(text: String) -> String:
	var res := Codec.decode(Codec.extract(text), Codec.KIND_ANSWER)
	if res["error"] != "":
		return res["error"]
	if phase != "lobby":
		return "started"
	for link in seats:
		var seat: Dictionary = seats[link]
		if seat["state"] == "inviting" and seat["check"] == res["items"]["reply_to"]:
			if not transport.take_answer(link, res["items"]):
				return "bad"
			seat["state"] = "answered"
			seat["answered_ms"] = now
			seat_changed.emit(link)
			return ""
	return "bad"


func connected_links() -> Array:
	var out := []
	for link in seats:
		if seats[link]["state"] == "connected":
			out.append(link)
	return out


func _send_lobby() -> void:
	var players := [{"id": 0, "name": my_name}]
	for link in connected_links():
		players.append({"id": link, "name": seats[link]["name"]})
	vs.set_lobby(players, 0)
	for link in connected_links():
		transport.send(link, Msg.lobby(players, link))
	lobby_changed.emit()


# 自分の名前を変えた(部屋の画面。FR-46)。ホストは一覧を配り直し、ゲストは hello を送り直す。
func rename(name: String) -> void:
	my_name = name
	if phase == "playing":
		return
	if is_host:
		_send_lobby()
	elif links.has(0):
		transport.send(0, Msg.hello(my_name))


# ホスト: 対戦を始める(「もう一戦」も同じ)。接続済みのゲストが 1 人以上いるときだけ(FR-40)。押し直しは受けない(E-37)。
func start(match_sec: int, unix_sec: int, usec: int) -> bool:
	if not is_host or phase == "playing" or connected_links().is_empty() or not match_sec in B.MATCH_SEC_CHOICES:
		return false
	# つながっていない席の招待は捨てる(E-29: 始まった後の返事は渡さない)
	for link in seats:
		if seats[link]["state"] != "connected":
			transport.drop(link)
			links.erase(link)
			seats[link] = _empty_seat(0)
			seat_changed.emit(link)
	_send_lobby()
	round_no += 1
	var seed_value := Msg.make_seed(unix_sec, usec, round_no)
	for link in connected_links():
		transport.send(link, Msg.start(seed_value, match_sec, round_no))
	_begin(seed_value, match_sec)
	return true


func _begin(seed_value: String, match_sec: int) -> void:
	vs.begin(seed_value, match_sec, round_no)
	phase = "playing"
	started_ms = 0
	started.emit(seed_value, match_sec, round_no)


# ---- ゲスト: 参加 ----

# 招待の文字から、返事を作り始める。結果: "" / "bad" / "version" / "kind"(返事を貼った。E-24)/ "no_rtc"
func join(text: String) -> String:
	if is_host:
		return "bad"
	var res := Codec.decode(Codec.extract(text), Codec.KIND_INVITE)
	if res["error"] != "":
		return res["error"]
	_invite_check = res["check"]
	transport.drop(0)
	links.erase(0)
	joined = false
	host_gone = false
	return "" if transport.make_answer(0, res["items"]) else "no_rtc"


# ---- 両方: 対戦中 ----

# 秒読みが終わった。ここから自分の時計で数える。
func begin_play() -> void:
	started_ms = maxi(now, 1)


func remaining_ms() -> int:
	return vs.remaining_ms(started_ms, now) if started_ms > 0 else vs.match_sec * 1000 if vs.match_sec > 0 else -1


# 自分の手のたびに、自分の行(versus_state.row_from_run の形)を送る。final も同じ。
func report(row: Dictionary) -> void:
	if phase != "playing":
		return
	row["id"] = vs.my_id
	vs.set_own(row)
	var text := Msg.state(row)
	if is_host:
		for link in connected_links():
			transport.send(link, text)
	elif not host_gone:
		transport.send(0, text)


# 部屋を出る・閉じる。
func leave() -> void:
	for link in links.keys():
		transport.send(link, Msg.bye("closed" if is_host else "leave"))
		transport.drop(link)
	links.clear()
	phase = "ended"


# ---- 毎フレーム ----

func tick(now_ms: int) -> void:
	now = now_ms
	transport.poll()
	if now >= _next_ping:
		_next_ping = now + PING_MS
		_ping_n += 1
		for link in links:
			transport.send(link, Msg.ping(_ping_n))
	for link in links.keys():
		if now - links[link]["last_rx"] > B.NET_SILENT_SEC * 1000:
			_cut(link, "")
	if is_host:
		for link in seats:
			var seat: Dictionary = seats[link]
			if seat["state"] in ["making", "inviting"] and seat["made_ms"] > 0 and now - seat["made_ms"] > B.INVITE_TTL_SEC * 1000:
				_fail_seat(link, "expired")
			elif seat["state"] == "answered" and now - seat["answered_ms"] > CONNECT_WAIT_MS:
				_fail_seat(link, "timeout")
		if phase == "playing" and started_ms > 0:
			var late := vs.match_sec > 0 and now - started_ms >= vs.match_sec * 1000 + FINAL_GRACE_MS
			if vs.all_done() or late:
				var results := vs.results()
				for link in connected_links():
					transport.send(link, Msg.end(results))
				_finish(results)
	else:
		if _answer_ms > 0 and not links.has(0) and now - _answer_ms > B.INVITE_TTL_SEC * 1000:
			_answer_ms = 0
			join_failed.emit("expired")
		# E-31: ホストが切れた後は、自分のランが終わった時点で、手元の値だけで結果を出す
		if host_gone and phase == "playing" and vs.players.has(vs.my_id) and vs.players[vs.my_id]["final"]:
			_finish(vs.results())


func _finish(results: Array) -> void:
	phase = "ended"
	ended.emit(results)


# ---- 通信からの知らせ ----

func _on_described(link: int, items: Dictionary) -> void:
	if is_host:
		if not seats.has(link) or seats[link]["state"] != "making":
			return
		var code := ""
		if not items.is_empty():
			items["kind"] = Codec.KIND_INVITE
			items["reply_to"] = 0
			code = Codec.encode(items)
		if code == "":
			_fail_seat(link, "no_route")
			return
		var seat: Dictionary = seats[link]
		seat["state"] = "inviting"
		seat["code"] = code
		seat["check"] = Codec.decode(code, Codec.KIND_INVITE)["check"]
		seat["made_ms"] = maxi(now, 1)
		seat_changed.emit(link)
	else:
		var code := ""
		if not items.is_empty():
			items["kind"] = Codec.KIND_ANSWER
			items["reply_to"] = _invite_check
			code = Codec.encode(items)
		if code == "":
			join_failed.emit("no_route")
			return
		_answer_ms = maxi(now, 1)
		answer_ready.emit(code)


func _on_opened(link: int) -> void:
	links[link] = {"last_rx": now, "times": [], "bad": 0}
	transport.send(link, Msg.hello(my_name))


func _on_received(link: int, text: String) -> void:
	if not links.has(link):
		return
	var l: Dictionary = links[link]
	l["last_rx"] = now
	# NET_RATE_MAX: 直前の 1 秒に受け取った数が上限を超えた相手は切る
	l["times"] = l["times"].filter(func(t): return t > now - 1000)
	l["times"].append(now)
	if l["times"].size() > B.NET_RATE_MAX:
		_cut(link, "closed")
		return
	var m := Msg.parse(text, round_no)
	if m.is_empty():
		l["bad"] += 1
		if l["bad"] >= BAD_MAX:
			_cut(link, "closed")
		return
	l["bad"] = 0
	match m["t"]:
		"ping":
			transport.send(link, Msg.pong(m["n"]))
		"bye":
			if not is_host and phase == "lobby" and not joined:
				join_failed.emit(m["reason"])
			_cut(link, "")
		_:
			if is_host:
				_host_got(link, m)
			else:
				_guest_got(m)


func _host_got(link: int, m: Dictionary) -> void:
	match m["t"]:
		"hello":
			if m["v"] != Msg.VERSION:
				_cut(link, "version")
			elif phase != "playing" and seats[link]["state"] == "connected":
				# 接続済みの相手からの 2 通目は、名前の変更
				seats[link]["name"] = m["name"]
				seat_changed.emit(link)
				_send_lobby()
			elif phase != "lobby" or seats[link]["state"] != "answered":
				_cut(link, "full")
			else:
				seats[link]["state"] = "connected"
				seats[link]["name"] = m["name"]
				seats[link]["fails"] = 0
				seat_changed.emit(link)
				_send_lobby()
		"state", "final":
			if phase == "playing" and seats[link]["state"] == "connected":
				# 送り主の席の番号に書き換えてから使う(相手が名乗った番号は信用しない)
				m["id"] = link
				if vs.apply_row(m):
					var text := Msg.state(m)
					for other in connected_links():
						if other != link:
							transport.send(other, text)
					rivals_changed.emit()


func _guest_got(m: Dictionary) -> void:
	match m["t"]:
		"hello":
			if m["v"] != Msg.VERSION and not joined:
				join_failed.emit("version")
		"lobby":
			if phase != "playing":
				vs.set_lobby(m["players"], m["you"])
				joined = true
				_answer_ms = 0
				lobby_changed.emit()
		"start":
			if phase != "playing" and joined:
				round_no = m["round"]
				_begin(m["seed_text"], m["match_sec"])
		"state", "final":
			if phase == "playing" and vs.apply_row(m):
				rivals_changed.emit()
		"end":
			if phase == "playing":
				_finish(m["results"])


func _on_closed(link: int) -> void:
	_cut(link, "")


# 接続を切る。reason があれば、先に bye を送る。
func _cut(link: int, reason: String) -> void:
	if reason != "":
		transport.send(link, Msg.bye(reason))
	transport.drop(link)
	var was_open := links.has(link)
	links.erase(link)
	if is_host:
		if not seats.has(link):
			return
		var was_connected: bool = seats[link]["state"] == "connected"
		if phase == "playing" and was_connected:
			# E-30: 対戦中は一覧を配り直さず、その人の札を「切断」にする
			seats[link]["state"] = "empty"
			vs.drop(link)
			rivals_changed.emit()
		elif was_connected:
			seats[link] = _empty_seat(0)
			_send_lobby()
		elif seats[link]["state"] == "answered":
			_fail_seat(link, reason if reason != "" else "closed")
			return
		seat_changed.emit(link)
	elif link == 0 and was_open and not host_gone:
		host_gone = true
		vs.drop(0)
		if phase == "lobby" and joined:
			join_failed.emit("closed")
		host_lost.emit()
		rivals_changed.emit()
