# 対戦の接続実験の画面(§8.4。Phase 6 だけの仮の画面で、Phase 7 で部屋の画面に置き換えて消す)。
# 招待を作る・返事を作る・貼る・つながったら「届いた」と出す。測った値を「記録」の欄にためて、コピーできるようにする。
# URL に lab=log が付いているときだけ、自動の確認のために、URL と記録をコンソールにも出す。
extends Control

signal back_pressed

const B := preload("res://core/balance.gd")
const S := preload("res://core/strings.gd")
const T := preload("res://ui/theme/tokens.gd")
const Kit := preload("res://ui/kit.gd")
const Codec := preload("res://core/invite_codec.gd")
const Rtc := preload("res://net/rtc_transport.gd")

# 送る試験(§8.4): 1 KB を毎秒 5 通、60 秒
const PING_GAP_MS := 200
const PING_COUNT := 300
const PING_SIZE := 1000
const PING_GRACE_MS := 2000
const RELAY_WAIT_MS := 1000
const ERRORS := {"bad": S.NET_UNREADABLE, "version": S.NET_VERSION, "kind": S.NET_UNREADABLE}

var app
var bridge
var query := ""
var log_to_console := false
var rtc
var derived := false
var with_mdns := false
var with_v6 := false
var pending_kind := 0
var pending_reply := 0
var invite_check := -1
var made_at := 0
var record := PackedStringArray()
var ping_sent := -1
var ping_next := 0
var ping_times := {}
var ping_rtts: Array[int] = []
var relay_until := 0
var relayed := false
# 今の接続で、データチャンネルが開いているか(送る試験を始めてよいか)
var linked := false

var scroll: ScrollContainer
var box: VBoxContainer
var status: Label
var url_box: TextEdit
var paste_box: TextEdit
var record_box: TextEdit
var derived_button: Button
var mdns_button: Button
var v6_button: Button


func setup(app_ref, bridge_ref, url_query: String) -> void:
	app = app_ref
	bridge = bridge_ref
	query = url_query
	log_to_console = query.contains("lab=log")
	# 招待の URL に付けた実験の切り替えを、ゲストも同じにする
	with_mdns = query.contains("mdns=1")
	with_v6 = query.contains("v6=1")
	derived = query.contains("derived=1")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	box = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	scroll.add_child(box)
	box.add_child(Kit.label(S.LAB_TITLE, T.FS_HEAD, T.W_NUM))
	status = _wrapped(S.LAB_IDLE, T.FS_BODY, T.BRASS_HI)
	_wrapped(S.LAB_NOTE, T.FS_SMALL, T.TEXT_DIM)
	_button(S.LAB_MAKE_INVITE, "brass", _make_invite)
	url_box = Kit.text_box("", false)
	url_box.custom_minimum_size = Vector2(0, 110)
	box.add_child(url_box)
	_button(S.LAB_COPY_URL, "green", _copy_url)
	if bridge.can_share():
		_button(S.LAB_SHARE, "green", func(): bridge.share_url(url_box.text))
	_button(S.LAB_PASTE, "green", bridge.read_clipboard)
	paste_box = Kit.text_box("", true, S.LAB_PASTE_HINT)
	paste_box.custom_minimum_size = Vector2(0, 110)
	box.add_child(paste_box)
	_button(S.LAB_USE_BOX, "ghost", func(): _take_text(paste_box.text, "box"))
	_button(S.LAB_PROMPT, "ghost", func(): _take_text(bridge.prompt_text(S.LAB_PROMPT_ASK), "prompt"))
	derived_button = _button("", "ghost", _toggle_derived)
	mdns_button = _button("", "ghost", _toggle_mdns)
	v6_button = _button("", "ghost", _toggle_v6)
	_button(S.LAB_PING, "green", _start_ping)
	record_box = Kit.text_box("", false)
	record_box.custom_minimum_size = Vector2(0, 320)
	box.add_child(record_box)
	_button(S.LAB_COPY_RECORD, "green", func(): DisplayServer.clipboard_set("\n".join(record)))
	_button(S.BTN_TO_TITLE, "ghost", func(): back_pressed.emit())
	_show_derived()
	bridge.clipboard_read.connect(_on_clipboard)
	bridge.answer_taken.connect(_on_relay_taken)
	_note("ua=" + bridge.user_agent())
	_note("can clipboard_read=%s share=%s broadcast=%s" % [bridge.can_read_clipboard(), bridge.can_share(), bridge.can_broadcast()])
	_note("url_arg=" + ("a" if _arg("a") else "j" if _arg("j") else "none"))
	if _arg("a"):
		_relay_answer()
	elif _arg("j"):
		_take_text(query, "url")


func _arg(key: String) -> bool:
	return query.contains("?%s=" % key) or query.contains("&%s=" % key)


func _wrapped(text: String, font_size: int, color: Color) -> Label:
	var l := Kit.label(text, font_size, T.W_BODY, color)
	l.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	box.add_child(l)
	return l


func _button(text: String, kind: String, cb: Callable) -> Button:
	var b := Kit.button(text, T.FS_BODY, kind)
	b.custom_minimum_size = Vector2(0, 96)
	b.pressed.connect(cb)
	box.add_child(b)
	return b


func relayout(landscape: bool, _view: Rect2) -> void:
	size = Vector2(1280, 720) if landscape else Vector2(720, 1280)
	var w := minf(size.x - 28, 900)
	Kit.place(scroll, Rect2((size.x - w) / 2, 10, w, size.y - 20))


# ---- 表示と記録 ----

func _say(text: String, color: Color = T.BRASS_HI) -> void:
	status.text = text
	status.add_theme_color_override("font_color", color)


func _note(line: String) -> void:
	record.append(line)
	record_box.text = "\n".join(record)
	if log_to_console:
		print("LAB ", line)


# 記録に残す候補の行から、IP アドレスを伏せる(.local の名前は、その場かぎりの名前なのでそのまま)。
func _mask(line: String) -> String:
	var p := line.split(" ")
	for i in p.size():
		if (i == 4 and not p[i].ends_with(".local")) or (i > 0 and p[i - 1] == "raddr"):
			p[i] = "x:x" if p[i].contains(":") else "x.x.x.x"
	return " ".join(p)


func _toggle_derived() -> void:
	derived = not derived
	_show_derived()


func _toggle_mdns() -> void:
	with_mdns = not with_mdns
	_show_derived()


func _toggle_v6() -> void:
	with_v6 = not with_v6
	_show_derived()


func _show_derived() -> void:
	derived_button.text = S.LAB_DERIVED % (S.LAB_ON if derived else S.LAB_OFF)
	mdns_button.text = S.LAB_MDNS % (S.LAB_ON if with_mdns else S.LAB_OFF)
	v6_button.text = S.LAB_V6 % (S.LAB_ON if with_v6 else S.LAB_OFF)


func _copy_url() -> void:
	DisplayServer.clipboard_set(url_box.text)
	_note("clipboard_write=tried")
	_say(S.LAB_COPIED)


# ---- つなぐ ----

func _new_rtc() -> void:
	if rtc != null:
		rtc.queue_free()
	rtc = Rtc.new()
	linked = false
	rtc.with_mdns = with_mdns
	rtc.with_v6 = with_v6
	rtc.described.connect(_on_described)
	rtc.opened.connect(_on_opened)
	rtc.received.connect(_on_received)
	rtc.closed.connect(_on_closed)
	add_child(rtc)


func _fail(text: String, reason: String) -> void:
	_say(text, T.BAD)
	_note("error=" + reason)


func _make_invite() -> void:
	_new_rtc()
	pending_kind = Codec.KIND_INVITE
	pending_reply = 0
	if not rtc.make_invite(derived):
		_fail(S.LAB_NO_RTC, "make_invite")
		return
	_say(S.LAB_WAIT_ICE)
	# 返事の URL が別のタブで開かれたら、そのタブからコードが届く(D-28)
	if bridge.listen_for_answer() and not bridge.answer_received.is_connected(_on_broadcast):
		bridge.answer_received.connect(_on_broadcast)


func _on_broadcast(code: String) -> void:
	_take_answer(code, "broadcast")


func _on_clipboard(ok: bool, text: String) -> void:
	_note("clipboard_read=" + ("ok" if ok else "refused"))
	if ok:
		_take_text(text, "clipboard")
	else:
		_say(S.NET_PASTE_FAILED, T.BAD)


# 貼られた文字が招待なら返事を作り、返事なら待っている接続に渡す。
func _take_text(text: String, from: String) -> void:
	var code := Codec.extract(text)
	var res := Codec.decode(code, Codec.KIND_INVITE)
	if res["error"] == "kind":
		_take_answer(code, from)
		return
	_note("invite_from=%s decode=%s" % [from, res["error"] if res["error"] != "" else "ok"])
	if res["error"] != "":
		_say(ERRORS[res["error"]], T.BAD)
		return
	_new_rtc()
	pending_kind = Codec.KIND_ANSWER
	pending_reply = res["check"]
	if rtc.make_answer(res["items"], derived):
		_say(S.LAB_WAIT_ICE)
	else:
		_fail(S.LAB_NO_RTC, "make_answer")


@warning_ignore("integer_division")
func _take_answer(code: String, from: String) -> void:
	var res := Codec.decode(Codec.extract(code), Codec.KIND_ANSWER)
	_note("answer_from=%s decode=%s" % [from, res["error"] if res["error"] != "" else "ok"])
	if res["error"] != "":
		_say(ERRORS[res["error"]], T.BAD)
	elif rtc == null or res["items"]["reply_to"] != invite_check:
		# E-25: どの招待にも対応しない返事
		_fail(S.NET_UNREADABLE, "answer_for_other_invite")
	elif rtc.take_answer(res["items"]):
		_note("answer_age_sec=%d" % ((Time.get_ticks_msec() - made_at) / 1000))
		_say(S.LAB_CONNECTING)
	else:
		_fail(S.LAB_NO_RTC, "take_answer")


@warning_ignore("integer_division")
func _on_described(items: Dictionary) -> void:
	_note("local_type=%s gather_ms=%d gather_complete=%s early_connected=%s" % [rtc.local_type, rtc.gather_ms, rtc.gather_complete, rtc.early_connected])
	_note("local_sdp=" + JSON.stringify(rtc.local_sdp))
	for line in rtc.cand_lines:
		_note("cand=" + _mask(line))
	# 実験用の足し、その 3: 返事を作る側がもうつながっているなら、載せる候補が無くても返事を作る(ホストは届いた通信から相手を知る)
	var bare_answer: bool = pending_kind == Codec.KIND_ANSWER and rtc.early_connected
	if items.is_empty() or (items["cands"].is_empty() and not bare_answer):
		# E-23
		_fail(S.NET_NO_ROUTE, "no_candidate")
		return
	items["kind"] = pending_kind
	items["reply_to"] = pending_reply
	var code := Codec.encode(items)
	if code == "":
		_fail(S.NET_UNREADABLE, "encode")
		return
	var invite := pending_kind == Codec.KIND_INVITE
	if invite:
		invite_check = Codec.decode(code, pending_kind)["check"]
	made_at = Time.get_ticks_msec()
	url_box.text = bridge.page_url() + ("?j=" if invite else "?a=") + code
	if invite:
		url_box.text += ("&mdns=1" if with_mdns else "") + ("&v6=1" if with_v6 else "") + ("&derived=1" if derived else "")
	_note("%s_code chars=%d bytes=%d derived=%s mdns=%s v6=%s cands=%d" % ["invite" if invite else "answer", code.length(), code.length() * 3 / 4, derived, with_mdns, with_v6, items["cands"].size()])
	if log_to_console:
		print("LAB url=", url_box.text)
	_say(S.LAB_INVITE_READY if invite else S.LAB_ANSWER_READY)


func _on_closed() -> void:
	linked = false
	_fail(S.LAB_CLOSED, "closed")


func _on_opened() -> void:
	linked = true
	_note("channel=open")
	rtc.send_text(JSON.stringify({"t": "hello", "v": 1}))


func _on_received(text: String) -> void:
	var json := JSON.new()
	if json.parse(text) != OK or not json.data is Dictionary:
		return
	var m: Dictionary = json.data
	match m.get("t"):
		"hello":
			_note("got=hello")
			_say(S.LAB_CONNECTED, T.GOOD)
		"ping":
			m["t"] = "pong"
			rtc.send_text(JSON.stringify(m))
		"pong":
			var n := int(m.get("n", -1))
			if ping_times.has(n):
				ping_rtts.append(Time.get_ticks_msec() - ping_times[n])
				ping_times.erase(n)


# ---- 送る試験 ----

func _start_ping() -> void:
	if ping_sent >= 0:
		return
	if not linked:
		# つながる前に始めると、60 秒後に「全部届かなかった」としか出ず、つながっていないことが分からない
		_note("ping=not_connected")
		_say(S.LAB_NOT_CONNECTED, T.BAD)
		return
	ping_sent = 0
	ping_times.clear()
	ping_rtts.clear()
	ping_next = Time.get_ticks_msec()


@warning_ignore("integer_division")
func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	if relay_until > 0 and now >= relay_until:
		relay_until = 0
		if not relayed:
			_note("relay=none")
			_say(S.RELAY_LOST, T.BAD)
			url_box.text = bridge.page_url() + "?a=" + Codec.extract(query)
			DisplayServer.clipboard_set(url_box.text)
	if ping_sent < 0:
		return
	if ping_sent < PING_COUNT and now >= ping_next:
		var m := {"t": "ping", "n": ping_sent, "pad": ""}
		m["pad"] = "x".repeat(PING_SIZE - JSON.stringify(m).length())
		ping_times[ping_sent] = now
		rtc.send_text(JSON.stringify(m))
		ping_sent += 1
		ping_next += PING_GAP_MS
		_say(S.LAB_PING_RUN % [ping_sent, PING_COUNT])
	elif ping_sent >= PING_COUNT and now >= ping_next + PING_GRACE_MS:
		ping_sent = -1
		ping_rtts.sort()
		var median: int = ping_rtts[ping_rtts.size() / 2] if not ping_rtts.is_empty() else -1
		_note("ping sent=%d lost=%d rtt_median_ms=%d" % [PING_COUNT, PING_COUNT - ping_rtts.size(), median])
		_say(S.LAB_PING_DONE % [PING_COUNT - ping_rtts.size(), median], T.BAD if ping_rtts.is_empty() else T.GOOD)


# ---- ?a= で開かれたタブ(D-28): 部屋のタブへ返事を渡す ----

func _relay_answer() -> void:
	if bridge.send_answer(Codec.extract(query)):
		relay_until = Time.get_ticks_msec() + RELAY_WAIT_MS
	else:
		relay_until = 1


func _on_relay_taken() -> void:
	relayed = true
	_note("relay=taken")
	_say(S.RELAY_DONE, T.GOOD)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		back_pressed.emit()
	elif log_to_console:
		# lab=log のときだけ: 自動の確認のために、I・D・M・V・P のキーで「招待を作る」と切り替え 3 つ、「送る試験」を押す
		match event.keycode:
			KEY_V:
				_toggle_v6()
			KEY_I:
				_make_invite()
			KEY_D:
				_toggle_derived()
			KEY_M:
				_toggle_mdns()
			KEY_P:
				_start_ping()
