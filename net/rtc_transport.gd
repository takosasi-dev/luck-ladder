# WebRTC のデータチャンネル 1 本での接続(§9.15)。Phase 6 の接続実験に要る最小限だけを持つ:
# 招待を作る・返事を作る・返事を受ける・文字を送る・受け取る。部屋や席の管理は Phase 7 で足す。
# 相手の接続情報は、core/invite_codec.gd の検査を通った項目からだけ作る(INV-16)。
extends Node

# 自分の接続情報がそろった。items は invite_codec の項目(kind と reply_to は呼ぶ側が足す)。取り出せなければ空の辞書
signal described(items: Dictionary)
signal opened
signal received(text: String)
signal closed

const B := preload("res://core/balance.gd")
const Codec := preload("res://core/invite_codec.gd")

# データチャンネルは両側で同じ番号に決め打ちして、チャンネルの交渉を省く(§9.15)
const CHANNEL_ID := 1
const CHANNEL_LABEL := "ll"

var peer: WebRTCPeerConnection
var channel: WebRTCDataChannel
# 自分の合言葉を、指紋から作った物に書き換えるか(前提 22 の実験)
var derived := false
# .local の名前の候補も載せるか(実験用の足し。core/invite_codec.gd の CAND_MDNS)
var with_mdns := false
var local_type := ""
var local_sdp := ""
var cand_lines: Array = []
var _wait_until := 0
# 候補が集まるのを待った時間(ミリ秒)と、集め終わりの合図が来たか(実験の記録用)
var gather_ms := 0
var gather_complete := false
var _gather_from := 0
var _open := false
var _closed := false


func _start(use_derived: bool) -> bool:
	derived = use_derived
	peer = WebRTCPeerConnection.new()
	if peer.initialize({"iceServers": [{"urls": B.STUN_URLS}]}) != OK:
		return false
	peer.session_description_created.connect(_on_session)
	peer.ice_candidate_created.connect(_on_candidate)
	channel = peer.create_data_channel(CHANNEL_LABEL, {"negotiated": true, "id": CHANNEL_ID, "ordered": true})
	if channel == null:
		return false
	channel.write_mode = WebRTCDataChannel.WRITE_MODE_TEXT
	return true


# ホスト: offer を作り始める。そろったら described が出る。
func make_invite(use_derived: bool) -> bool:
	return _start(use_derived) and peer.create_offer() == OK


# ゲスト: 招待の項目を相手の情報として渡す。answer がそろったら described が出る。
func make_answer(invite: Dictionary, use_derived: bool) -> bool:
	return _start(use_derived) and _set_remote("offer", invite)


# ホスト: 返事の項目を、待っている接続に渡す。
func take_answer(answer: Dictionary) -> bool:
	return peer != null and _set_remote("answer", answer)


func _set_remote(type: String, items: Dictionary) -> bool:
	var sdp := Codec.to_sdp(items)
	if sdp == "" or peer.set_remote_description(type, sdp) != OK:
		return false
	for line in Codec.candidate_lines(items):
		peer.add_ice_candidate("0", 0, line)
	return true


func _on_session(type: String, sdp: String) -> void:
	local_type = type
	local_sdp = Codec.munge(sdp) if derived else sdp
	peer.set_local_description(type, local_sdp)
	# 外向きの IP が集まるのを待つ。過ぎたら、集まった分だけで作る
	_gather_from = Time.get_ticks_msec()
	_wait_until = _gather_from + B.ICE_WAIT_SEC * 1000


func _on_candidate(_media: String, _index: int, candidate: String) -> void:
	cand_lines.append(candidate)


func send_text(text: String) -> bool:
	return _open and not _closed and channel.put_packet(text.to_utf8_buffer()) == OK


func _process(_delta: float) -> void:
	if peer == null:
		return
	peer.poll()
	if _wait_until > 0 and (Time.get_ticks_msec() >= _wait_until or peer.get_gathering_state() == WebRTCPeerConnection.GATHERING_STATE_COMPLETE):
		_wait_until = 0
		gather_ms = Time.get_ticks_msec() - _gather_from
		gather_complete = peer.get_gathering_state() == WebRTCPeerConnection.GATHERING_STATE_COMPLETE
		described.emit(Codec.from_sdp(local_sdp, cand_lines, derived, with_mdns))
	if channel == null or _closed:
		return
	var state := channel.get_ready_state()
	if state == WebRTCDataChannel.STATE_OPEN:
		if not _open:
			_open = true
			opened.emit()
		while channel.get_available_packet_count() > 0:
			var packet := channel.get_packet()
			# 大きすぎる物は読まずに捨てる(INV-16)
			if packet.size() <= B.NET_MSG_MAX:
				received.emit(packet.get_string_from_utf8())
	elif _open and state == WebRTCDataChannel.STATE_CLOSED:
		_closed = true
		closed.emit()


func _exit_tree() -> void:
	if channel != null:
		channel.close()
	if peer != null:
		peer.close()
