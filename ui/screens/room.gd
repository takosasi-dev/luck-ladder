# 部屋(対戦の待ち合わせ。FR-35〜FR-40・FR-46・FR-47、画面設計書 §3.7)。ホストの席 4 つ、ゲストの参加、返事を渡すだけのタブ。
# 通信は app.session(net/versus_session.gd)に任せ、ここは見せるのと押されたことを伝えるだけ。
# 招待と返事の URL は、文字欄とクリップボードと共有にだけ渡す(INV-17)。
extends Control

signal back_pressed

const B := preload("res://core/balance.gd")
const S := preload("res://core/strings.gd")
const T := preload("res://ui/theme/tokens.gd")
const Kit := preload("res://ui/kit.gd")
const Codec := preload("res://core/invite_codec.gd")

const RELAY_WAIT_MS := 1000
const ANSWER_ERRORS := {"bad": S.NET_UNREADABLE, "expired": S.NET_ANSWER_LATE, "version": S.NET_VERSION, "kind": S.NET_IS_INVITE, "started": S.NET_NO_SEAT}
const JOIN_ERRORS := {"bad": S.NET_UNREADABLE, "version": S.NET_VERSION, "kind": S.NET_IS_ANSWER, "no_rtc": S.NET_NO_RTC,
	"no_route": S.NET_NO_ROUTE, "expired": S.NET_EXPIRED, "full": S.NET_NO_SEAT, "closed": S.NET_CLOSED, "leave": S.NET_CLOSED}

var app
var bridge
# "choose"(部屋を作るか参加するか)/ "host" / "invited"(招待 URL から来た)/ "paste"(招待を貼る)/ "guest"(参加の途中と後)/ "relay"(返事を渡すだけ)
var mode := "choose"
var query := ""
var match_sec := B.MATCH_SEC_DEFAULT
var message := ""
var message_bad := false
var answer_code := ""
var answer_until := 0
# 貼り付けが使えなかったときに出す入力欄(E-28)
var show_box := false
var sure_leave := false
var relay_until := 0
var relayed := false
# ゲストが参加に失敗したときに戻る画面
var guest_from := "paste"

var frame: VBoxContainer
var scroll: ScrollContainer
var box: VBoxContainer
# 下に固定する段: 知らせといちばん大事なボタン(スクロールしても動かない)
var foot: VBoxContainer
# 知らせの欄。高さを決めておき、知らせが出ても消えても、ほかの物の位置を変えない
var note: Label
# 「招待を作る」を押した席。招待ができたら、そのボタンの行まで画面を送る
var reveal_seat := -1
var seat_labels := {}
var answer_label: Label
var paste_box: TextEdit


func setup(app_ref, mode_value: String, url_query: String = "") -> void:
	app = app_ref
	bridge = app.bridge
	mode = mode_value
	query = url_query
	if mode in ["invited", "paste"]:
		guest_from = mode


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame = VBoxContainer.new()
	frame.add_theme_constant_override("separation", 10)
	add_child(frame)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_child(scroll)
	box = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	scroll.add_child(box)
	foot = VBoxContainer.new()
	foot.add_theme_constant_override("separation", 6)
	frame.add_child(foot)
	note = _text("", T.FS_SMALL, T.TEXT, foot)
	bridge.clipboard_read.connect(_on_clipboard)
	bridge.answer_received.connect(_on_answer_text)
	bridge.answer_taken.connect(_on_relay_taken)
	if mode == "relay":
		_relay()
	elif app.session != null:
		# 対戦の結果から戻ってきた: 同じ部屋の続き
		mode = "host" if app.session.is_host else "guest"
		match_sec = app.session.vs.match_sec
		_watch()
		if mode == "host":
			bridge.listen_for_answer()
	_rebuild()


func relayout(landscape: bool, _view: Rect2) -> void:
	size = Vector2(1280, 720) if landscape else Vector2(720, 1280)
	var w := minf(size.x - 28, 900)
	# 端の位置で置く: 大きさで置くと、折り返しが決まる前の背の高さのまま固まり、下の段が画面の外に出る
	frame.offset_left = (size.x - w) / 2
	frame.offset_right = frame.offset_left + w
	frame.offset_top = 10
	frame.offset_bottom = size.y - 10
	# 知らせの欄: 横長は 1 行、縦長は折り返すので 2 行ぶん
	note.custom_minimum_size.y = 33 if landscape else 69


# ---- 部品 ----

func _text(text: String, font_size: int = T.FS_BODY, color: Color = T.TEXT, parent: Node = null) -> Label:
	var l := Kit.label(text, font_size, T.W_BODY, color)
	l.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	(parent if parent != null else box).add_child(l)
	return l


func _button(text: String, kind: String, cb: Callable, parent: Node = null) -> Button:
	var b := Kit.button(text, T.FS_BODY, kind)
	b.custom_minimum_size = Vector2(0, 88)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(cb)
	(parent if parent != null else box).add_child(b)
	return b


func _row(parent: Node = null) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	(parent if parent != null else box).add_child(h)
	return h


func _url_box(url: String) -> void:
	var t := Kit.text_box(url, false)
	t.custom_minimum_size = Vector2(0, 96)
	box.add_child(t)


func _say(text: String, bad: bool = false) -> void:
	message = text
	message_bad = bad
	_rebuild.call_deferred()


func _url(key: String, code: String) -> String:
	var page: String = bridge.page_url()
	return (page if page != "" else B.SHARE_URL) + "?" + key + "=" + code


# ---- 組み立て(状態が変わるたびに作り直す) ----

func _rebuild() -> void:
	for c in box.get_children() + foot.get_children():
		if c != note:
			c.get_parent().remove_child(c)
			c.queue_free()
	note.text = ""
	seat_labels = {}
	answer_label = null
	paste_box = null
	box.add_child(Kit.label(S.ROOM_TITLE, T.FS_HEAD, T.W_NUM))
	var said := T.BAD if message_bad else T.BRASS_HI
	if mode == "relay":
		if message != "":
			_text(message, T.FS_BODY, said)
		return
	match mode:
		"choose":
			_text(S.ROOM_CHOOSE, T.FS_SMALL, T.TEXT_DIM)
			_button(S.ROOM_MAKE, "brass", _make_room)
			_button(S.ROOM_JOIN, "green", func(): _go("paste"))
			_name_row()
		"host":
			_build_host()
		"invited":
			_text(S.ROOM_INVITED)
			_name_row()
			_button(S.ROOM_JOIN_GO, "brass", func(): _join(query))
		"paste":
			_button(S.ROOM_INVITE_PASTE, "brass", bridge.read_clipboard)
			_paste_fallback()
			_name_row()
		"guest":
			_build_guest()
	_text(S.ROOM_IP_NOTE, T.FS_SMALL, T.TEXT_DIM)
	# 知らせは下の段の決まった欄に出す(上に差し込むと、押そうとしたボタンが動く)
	note.text = message
	note.add_theme_color_override("font_color", said)
	var h := _row(foot)
	if mode == "host":
		var start := _button(S.ROOM_START, "brass", _start, h)
		start.size_flags_stretch_ratio = 2.0
		start.disabled = app.session.connected_links().is_empty()
	var leave: String = S.ROOM_SURE if sure_leave else S.ROOM_CLOSE if mode == "host" else S.ROOM_LEAVE if mode == "guest" else S.BTN_TO_TITLE
	_button(leave, "ghost", _leave, h)


func _go(next: String) -> void:
	mode = next
	if next in ["invited", "paste"]:
		guest_from = next
	message = ""
	_rebuild.call_deferred()


func _name_row() -> void:
	var h := _row()
	var l := Kit.label(S.ROOM_NAME % app.save.data["settings"]["name"], T.FS_BODY, T.W_BODY)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	h.add_child(l)
	var b := _button(S.ROOM_RENAME, "ghost", _rename, h)
	b.size_flags_horizontal = Control.SIZE_SHRINK_END
	b.custom_minimum_size = Vector2(260, 88)


func _rename() -> void:
	var text: String = bridge.prompt_text(S.ROOM_RENAME_ASK)
	if text == "":
		return
	if app.set_player_name(text):
		_say("")
	else:
		_say(S.ROOM_NAME_BAD, true)


# 貼り付けが使えないとき用の入力欄と、ブラウザの入力の小窓(E-28)。
func _paste_fallback() -> void:
	if not show_box:
		return
	paste_box = Kit.text_box("", true, S.ROOM_BOX_HINT)
	paste_box.custom_minimum_size = Vector2(0, 96)
	box.add_child(paste_box)
	var h := _row()
	_button(S.ROOM_USE_BOX, "green", func(): _take_text(paste_box.text), h)
	_button(S.ROOM_PROMPT, "ghost", func(): _take_text(bridge.prompt_text(S.ROOM_PROMPT_ASK)), h)


func _build_host() -> void:
	var se = app.session
	_text(S.ROOM_HOST_STEP, T.FS_SMALL, T.TEXT_DIM)
	_name_row()
	var times := _row()
	var tl := Kit.label(S.ROOM_TIME, T.FS_BODY, T.W_BODY)
	tl.custom_minimum_size = Vector2(150, 0)
	times.add_child(tl)
	for sec in B.MATCH_SEC_CHOICES:
		_button(S.ROOM_TIMES[sec], "brass" if sec == match_sec else "ghost", _pick_time.bind(sec), times)
	_text(S.ROOM_SEAT_SELF % se.my_name)
	for link in se.seats:
		var seat: Dictionary = se.seats[link]
		var state: String = seat["state"]
		if state in ["empty", "failed", "expired"]:
			# 席の名前とボタンを 1 行に(縦に長くなって「はじめる」が遠くなるのを防ぐ)
			var h := _row()
			var l := Kit.label("", T.FS_BODY, T.W_BODY)
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			h.add_child(l)
			seat_labels[link] = l
			var b := _button(S.ROOM_INVITE_MAKE if state == "empty" else S.ROOM_REMAKE, "green", _open_seat.bind(link), h)
			b.size_flags_horizontal = Control.SIZE_SHRINK_END
			b.custom_minimum_size = Vector2(260, 88)
			if state != "empty" and (seat["fails"] >= 3 or seat["reason"] == "no_route"):
				_text(S.NET_NO_ROUTE, T.FS_SMALL, T.BAD)
			elif state != "empty" and seat["reason"] == "no_rtc":
				_text(S.NET_NO_RTC, T.FS_SMALL, T.BAD)
			continue
		seat_labels[link] = _text("")
		if state == "inviting":
			var url := _url("j", seat["code"])
			_url_box(url)
			var h := _row()
			_button(S.ROOM_INVITE_COPY, "brass", _copy.bind(url), h)
			if bridge.can_share():
				_button(S.ROOM_SHARE, "green", bridge.share_url.bind(url), h)
			_button(S.ROOM_ANSWER_PASTE, "green", bridge.read_clipboard, h)
			if link == reveal_seat:
				reveal_seat = -1
				_reveal(h)
	_paste_fallback()
	_refresh_seats()


func _open_seat(link: int) -> void:
	reveal_seat = link
	app.session.open_seat(link)


# 作ったばかりの招待のボタンが下の段の裏に隠れないように、見える所まで送る(並べ終わるのを待ってから)
func _reveal(row: Control) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(row):
		scroll.ensure_control_visible(row)


func _refresh_seats() -> void:
	if app.session == null:
		return
	var now := Time.get_ticks_msec()
	for link in seat_labels:
		var seat: Dictionary = app.session.seats[link]
		var n: int = link + 1
		var left := maxi((seat["made_ms"] + B.INVITE_TTL_SEC * 1000 - now + 999) / 1000, 0)
		seat_labels[link].text = {
			"empty": S.ROOM_SEAT_EMPTY % n, "making": S.ROOM_SEAT_MAKING % n, "inviting": S.ROOM_SEAT_INVITING % [n, left],
			"answered": S.ROOM_SEAT_ANSWERED % n, "connected": S.ROOM_SEAT_CONNECTED % [n, seat["name"]],
			"failed": S.ROOM_SEAT_FAILED % n, "expired": S.ROOM_SEAT_EXPIRED % n,
		}[seat["state"]]
	if answer_label != null:
		answer_label.text = S.ROOM_ANSWER_SEND % maxi((answer_until - now + 999) / 1000, 0)


func _build_guest() -> void:
	var se = app.session
	if se.joined:
		_text(S.ROOM_PLAYERS)
		for id in se.vs.players:
			var p: Dictionary = se.vs.players[id]
			_text((S.ROOM_SEAT_SELF % p["name"]) if id == se.vs.my_id else p["name"], T.FS_BODY, T.BRASS_HI if id == se.vs.my_id else T.TEXT)
		_name_row()
		_text(S.ROOM_WAIT_START, T.FS_BODY, T.BRASS_HI)
	elif answer_code != "":
		answer_label = _text("", T.FS_BODY, T.BRASS_HI)
		var url := _url("a", answer_code)
		_url_box(url)
		var h := _row()
		_button(S.ROOM_ANSWER_COPY, "brass", _copy.bind(url), h)
		if bridge.can_share():
			_button(S.ROOM_SHARE, "green", bridge.share_url.bind(url), h)
		_refresh_seats()
	else:
		_text(S.ROOM_PREPARING, T.FS_BODY, T.BRASS_HI)


func _process(_delta: float) -> void:
	if mode == "relay":
		if relay_until > 0 and Time.get_ticks_msec() >= relay_until:
			relay_until = 0
			if not relayed:
				# D-28: 部屋のタブが見つからなかった。返事をクリップボードへ書くことを試す
				DisplayServer.clipboard_set(_url("a", Codec.extract(query)))
				_say(S.RELAY_LOST, true)
		return
	_refresh_seats()


# ---- 押されたとき ----

func _watch() -> void:
	var se = app.session
	for sig in [se.seat_changed, se.lobby_changed, se.answer_ready, se.join_failed]:
		for c in sig.get_connections():
			sig.disconnect(c["callable"])
	se.seat_changed.connect(func(_link): _rebuild.call_deferred())
	se.lobby_changed.connect(func(): _rebuild.call_deferred())
	se.answer_ready.connect(_on_answer_ready)
	se.join_failed.connect(_on_join_failed)


func _make_room() -> void:
	app.make_session(true)
	_watch()
	bridge.listen_for_answer()
	_go("host")


func _pick_time(sec: int) -> void:
	match_sec = sec
	_rebuild.call_deferred()


func _copy(url: String) -> void:
	DisplayServer.clipboard_set(url)
	# 書き込めたかは確かめられないので、「コピーしました」とは出さない(INV-10)
	_say(S.ROOM_COPY_TRIED)


func _start() -> void:
	app.session.start(match_sec, int(Time.get_unix_time_from_system()), Time.get_ticks_usec())


func _leave() -> void:
	# 部屋にいる間は、押し間違いで閉じないように 2 回押してもらう
	if mode in ["host", "guest"] and not sure_leave:
		sure_leave = true
		_rebuild.call_deferred()
		return
	app.close_session()
	back_pressed.emit()


func _on_clipboard(ok: bool, text: String) -> void:
	if ok:
		_take_text(text)
	else:
		show_box = true
		_say(S.NET_PASTE_FAILED, true)


# 貼られた文字: ホストなら返事として席に渡し、ゲストなら招待として参加する。
func _take_text(text: String) -> void:
	if mode == "host":
		_on_answer_text(text)
	elif mode == "paste":
		_join(text)


func _on_answer_text(text: String) -> void:
	if mode != "host" or app.session == null:
		return
	var err: String = app.session.take_answer_text(text)
	_say(ANSWER_ERRORS.get(err, ""), err != "")


func _join(text: String) -> void:
	var se = app.make_session(false)
	_watch()
	var err: String = se.join(text)
	if err != "":
		app.close_session()
		_say(JOIN_ERRORS.get(err, S.NET_UNREADABLE), true)
		return
	answer_code = ""
	message = ""
	_go("guest")


func _on_answer_ready(code: String) -> void:
	answer_code = code
	answer_until = Time.get_ticks_msec() + B.INVITE_TTL_SEC * 1000
	_rebuild.call_deferred()


func _on_join_failed(reason: String) -> void:
	app.close_session()
	answer_code = ""
	mode = guest_from
	_say(JOIN_ERRORS.get(reason, S.NET_FAILED), true)


# ---- ?a= で開かれたタブ(D-28): 部屋のタブへ返事を渡す ----

func _relay() -> void:
	_say(S.ROOM_PREPARING)
	relay_until = Time.get_ticks_msec() + RELAY_WAIT_MS if bridge.send_answer(Codec.extract(query)) else 1


func _on_relay_taken() -> void:
	relayed = true
	_say(S.RELAY_DONE)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_leave()
