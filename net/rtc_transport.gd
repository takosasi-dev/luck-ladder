# WebRTC のデータチャンネルでの通信(§9.15)。transport.gd の口の実装で、相手(link)ごとに接続を 1 つ持つ。
# 相手の接続情報は、core/invite_codec.gd の検査を通った項目からだけ作る(INV-16)。
# 接続情報の中身(IP アドレスが入る)は、どこにも書き出さない(INV-17)。
extends "res://net/transport.gd"

const B := preload("res://core/balance.gd")
const Codec := preload("res://core/invite_codec.gd")

# データチャンネルは両側で同じ番号に決め打ちして、チャンネルの交渉を省く(§9.15)
const CHANNEL_ID := 1
const CHANNEL_LABEL := "ll"

# link → {peer, channel, answer, sdp, cands, wait_until, open}
var _conns := {}


func _start(link: int, answer: bool) -> bool:
	drop(link)
	var peer := WebRTCPeerConnection.new()
	if peer.initialize({"iceServers": [{"urls": B.STUN_URLS}]}) != OK:
		return false
	var channel := peer.create_data_channel(CHANNEL_LABEL, {"negotiated": true, "id": CHANNEL_ID, "ordered": true})
	if channel == null:
		return false
	channel.write_mode = WebRTCDataChannel.WRITE_MODE_TEXT
	_conns[link] = {"peer": peer, "channel": channel, "answer": answer, "sdp": "", "cands": [], "wait_until": 0, "open": false}
	peer.session_description_created.connect(_on_session.bind(link))
	peer.ice_candidate_created.connect(_on_candidate.bind(link))
	return true


func make_invite(link: int) -> bool:
	return _start(link, false) and _conns[link]["peer"].create_offer() == OK


func make_answer(link: int, invite: Dictionary) -> bool:
	return _start(link, true) and _set_remote(link, "offer", invite)


func take_answer(link: int, answer: Dictionary) -> bool:
	return _conns.has(link) and not _conns[link]["answer"] and _set_remote(link, "answer", answer)


func _set_remote(link: int, type: String, items: Dictionary) -> bool:
	var sdp := Codec.to_sdp(items)
	var peer: WebRTCPeerConnection = _conns[link]["peer"]
	if sdp == "" or peer.set_remote_description(type, sdp) != OK:
		return false
	for line in Codec.candidate_lines(items):
		peer.add_ice_candidate("0", 0, line)
	return true


func _on_session(type: String, sdp: String, link: int) -> void:
	if not _conns.has(link):
		return
	var c: Dictionary = _conns[link]
	c["sdp"] = sdp
	c["peer"].set_local_description(type, sdp)
	# 外向きの IP が集まるのを待つ。過ぎたら、集まった分だけで作る
	c["wait_until"] = Time.get_ticks_msec() + B.ICE_WAIT_SEC * 1000


func _on_candidate(_media: String, _index: int, candidate: String, link: int) -> void:
	if _conns.has(link):
		_conns[link]["cands"].append(candidate)


func send(link: int, text: String) -> bool:
	return _conns.has(link) and _conns[link]["open"] and _conns[link]["channel"].put_packet(text.to_utf8_buffer()) == OK


func drop(link: int) -> void:
	if not _conns.has(link):
		return
	var c: Dictionary = _conns[link]
	_conns.erase(link)
	c["channel"].close()
	c["peer"].close()


func poll() -> void:
	for link in _conns.keys():
		if not _conns.has(link):
			continue
		var c: Dictionary = _conns[link]
		var peer: WebRTCPeerConnection = c["peer"]
		peer.poll()
		var gathered := peer.get_gathering_state() == WebRTCPeerConnection.GATHERING_STATE_COMPLETE
		if c["wait_until"] > 0 and (gathered or Time.get_ticks_msec() >= c["wait_until"]):
			c["wait_until"] = 0
			var items := Codec.from_sdp(c["sdp"], c["cands"], false, true, true)
			# 返事を作る側がもうつながっているなら、載せる候補が無くても返事を作れる(§9.16)。それ以外で候補が無ければ E-23
			var bare_ok: bool = c["answer"] and peer.get_connection_state() == WebRTCPeerConnection.STATE_CONNECTED
			if not items.is_empty() and items["cands"].is_empty() and not bare_ok:
				items = {}
			described.emit(link, items)
			if not _conns.has(link):
				continue
		var channel: WebRTCDataChannel = c["channel"]
		var state := channel.get_ready_state()
		if state == WebRTCDataChannel.STATE_OPEN:
			if not c["open"]:
				c["open"] = true
				opened.emit(link)
			while _conns.has(link) and channel.get_available_packet_count() > 0:
				var packet := channel.get_packet()
				# 大きすぎる物は読まずに捨てる(INV-16)
				if packet.size() <= B.NET_MSG_MAX:
					received.emit(link, packet.get_string_from_utf8())
		elif c["open"] and state == WebRTCDataChannel.STATE_CLOSED:
			_conns.erase(link)
			closed.emit(link)
