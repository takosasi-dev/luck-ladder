# ブラックジャックとポーカーの卓の、共通の骨組み(追補 1 §5・§7.2)。上の帯・持ち点・賭ける点・「配る」と、入力の受け方を持つ。
# 勝負の決まりは core/ が決め、持ち点の出し入れは save/save_store.gd が行う。
# ゲームごとの画面は「ゲームごとに上書きする物」の関数を上書きし、動きの最後に _idle か _end を呼ぶ。
extends Control

signal back_pressed

const B := preload("res://core/balance.gd")
const S := preload("res://core/strings.gd")
const T := preload("res://ui/theme/tokens.gd")
const Kit := preload("res://ui/kit.gd")
const L := preload("res://ui/layout/casino_layout.gd")
const Deck := preload("res://core/deck.gd")
const ShareText := preload("res://core/share_text.gd")
const Card := preload("res://ui/parts/card.gd")

const DEAL_KEYS := [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]
const BET_KEYS := [KEY_1, KEY_2, KEY_3, KEY_4]

# FR-A3: 選んだ賭ける点を、アプリを開いている間だけゲームごとに覚える(ゲームの鍵 → 点)
static var last_bets := {}

var app
var save
var landscape := true
# "bet"(賭けの段階)か "play"(勝負の段階)
var phase := "bet"
var busy := false
var bet := 0
# 今の勝負に賭けた点(ダブルの後は 2 倍)
var stake := 0
var tw: Tween
var last_input_frame := -1
# 勝負が付いた直後は、この時刻(ms)まで「配る」を受けない(Kit.press_guard_ms)
var quiet_until := 0

var back: Button
var name_label: Label
var wallet_cap: Label
var wallet_num: Label
var delta_label: Label
var notice: Label
var message: Label
var bet_label: Label
var bet_buttons: Array[Button] = []
var deal: Button
var actions := {}


func setup(app_ref) -> void:
	app = app_ref
	save = app.save


# ---- ゲームごとに上書きする物 ----

# 賭ける点を覚える鍵
func _game() -> String:
	return ""


func _game_title() -> String:
	return ""


# 勝負の段階のボタン: [[名前, ボタンの字, [キー]], …]
func _actions() -> Array:
	return []


func _action_enabled(_key: String) -> bool:
	return true


func _build_table() -> void:
	pass


func _layout_table(_r: Dictionary) -> void:
	pass


# 「配る」の後。_begin 済みなので、tw に動きを足す。
func _start(_cards: PackedInt32Array) -> void:
	pass


# 勝負の段階のボタンが押された後。_begin 済みなので、tw に動きを足す。
func _on_action(_key: String) -> void:
	pass


# ボタンに無い、そのゲームだけのキー。受けたら真。
func _extra_key(_keycode: int) -> bool:
	return false


# ---- 組み立てと配置 ----

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	back = Kit.button(S.BTN_BACK, T.FS_SMALL + 2, "ghost")
	back.pressed.connect(_back)
	add_child(back)
	name_label = Kit.label(_game_title(), T.FS_HEAD, T.W_NUM)
	add_child(name_label)
	wallet_cap = Kit.label(S.WALLET, T.FS_SMALL, T.W_BODY, T.TEXT_DIM)
	add_child(wallet_cap)
	wallet_num = Kit.num_label("", T.FS_SCORE, T.BRASS_HI)
	add_child(wallet_num)
	# 「戻り」の字を出すので、本文の字にする(数字用の字には漢字が無い)
	delta_label = Kit.label("", T.FS_BODY - 2, T.W_NUM)
	add_child(delta_label)
	notice = Kit.label("", T.FS_SMALL, T.W_BODY, T.BRASS_HI)
	add_child(notice)
	bet_label = Kit.label("", T.FS_BODY, T.W_NUM)
	add_child(bet_label)
	deal = Kit.button(S.BTN_DEAL, T.FS_BODY, "brass")
	deal.pressed.connect(_deal)
	add_child(deal)
	for a in _actions():
		var b := Kit.button(a[1], T.FS_BODY, "green")
		var key: String = a[0]
		b.pressed.connect(func(): _act(key))
		add_child(b)
		actions[key] = b
	_build_table()
	message = Kit.label("", T.FS_CALLOUT, T.W_BLACK)
	add_child(message)
	app.bgm.play("bgm_play")
	bet = last_bets.get(_game(), B.BET_DEFAULT)
	_enter_bet()


# E-A8: 動いている途中なら最後まで進めてから、並べ直す。勝負は続く。
func relayout(is_landscape: bool, _view: Rect2) -> void:
	_finish_tween()
	landscape = is_landscape
	size = Vector2(1280, 720) if landscape else Vector2(720, 1280)
	var r := L.rects(landscape)
	name_label.add_theme_font_size_override("font_size", T.FS_HEAD if landscape else T.FS_BODY)
	Kit.place(back, r["back"])
	Kit.place(name_label, r["name"])
	Kit.place(wallet_cap, r["wallet_cap"])
	Kit.place(wallet_num, r["wallet"])
	Kit.place(delta_label, r["delta"])
	Kit.place(notice, r["notice"])
	Kit.place(message, r["message"])
	Kit.place(bet_label, r["bet_label"])
	Kit.place(deal, r["deal"])
	var keys := actions.keys()
	for i in keys.size():
		Kit.place(actions[keys[i]], L.slot(r["actions"], keys.size(), i))
	_layout_table(r)
	_refresh()


# ---- 表示 ----

func _show_wallet() -> void:
	wallet_num.text = ShareText.group(save.data["casino"]["wallet"])


# FR-A5: 増えた点・減った点。勝負が付いたときの戻りには「戻り」と付ける(100 点賭けて勝つと +200 と出て、初めての人には分かりにくい)
func _show_delta(points: int, is_return: bool = false) -> void:
	delta_label.text = (S.DELTA_RETURN if is_return else S.DELTA_PLUS) % ShareText.group(points) if points > 0 else ShareText.group(points)
	delta_label.add_theme_color_override("font_color", T.GOOD if points > 0 else T.BAD)


# 段階に合わせてボタンを出し分ける。持ち点の数字は、動きの途中で結果が先に見えないよう、ここでは変えない。
func _refresh() -> void:
	var wallet: int = save.data["casino"]["wallet"]
	var betting := phase == "bet"
	bet_label.text = S.BET_LABEL % ShareText.group(bet if betting else stake)
	back.disabled = not betting or busy
	deal.visible = betting
	# 選んだ物を真鍮色にするため、賭ける点のボタンは作り直す(ボタンの色は作るときに決まる)
	for b in bet_buttons:
		b.queue_free()
	bet_buttons.clear()
	if betting:
		var r := L.rects(landscape)
		for i in B.BET_CHOICES.size():
			var c: int = B.BET_CHOICES[i]
			var b := Kit.button(ShareText.group(c), T.FS_BODY, "brass" if c == bet else "green")
			b.disabled = c > wallet
			b.pressed.connect(_pick_bet.bind(c))
			add_child(b)
			Kit.place(b, L.slot(r["bets"], B.BET_CHOICES.size(), i))
			bet_buttons.append(b)
	for key in actions:
		actions[key].visible = not betting
		actions[key].disabled = busy or not _action_enabled(key)


# ---- 流れ ----

# 賭けの段階に入る。FR-A2 の補充と、E-A2(払えない点を選んでいたら、払える中で最大の選択肢に下げる)。
func _enter_bet() -> void:
	phase = "bet"
	busy = false
	if save.casino_refill():
		notice.text = S.WALLET_REFILLED % ShareText.group(B.WALLET_START)
	var limit := mini(bet, save.data["casino"]["wallet"])
	bet = B.BET_CHOICES[0]
	for c in B.BET_CHOICES:
		if c <= limit:
			bet = c
	_show_wallet()
	_refresh()


func _pick_bet(points: int) -> void:
	if phase != "bet" or busy or points > save.data["casino"]["wallet"]:
		return
	bet = points
	last_bets[_game()] = points
	_refresh()


# E-A4: 動きの間の入力と、同じフレームに届いた 2 つ目からの入力は捨てる。
func _accept() -> bool:
	var f := Engine.get_process_frames()
	if busy or f == last_input_frame:
		return false
	last_input_frame = f
	return true


# D-A8: 勝負ごとに 52 枚を切り直す。テストは、決めた並びを返すように上書きする。
func _new_deck() -> PackedInt32Array:
	return Deck.shuffled("LLC:%d:%d" % [int(Time.get_unix_time_from_system()), Time.get_ticks_usec()])


# FR-A4: 賭ける点を引いて保存してから、札を配る。
func _deal() -> void:
	# 動きの間に連打していた人の次の 1 押しが、結果を読む前に次の勝負を始めないようにする
	if phase != "bet" or Time.get_ticks_msec() < quiet_until or not _accept() or not save.casino_pay(bet):
		return
	phase = "play"
	stake = bet
	notice.text = ""
	message.text = ""
	_show_wallet()
	_show_delta(-bet)
	_begin()
	_start(_new_deck())
	_refresh()


func _act(key: String) -> void:
	if phase != "play" or not actions.has(key) or not _action_enabled(key) or not _accept():
		return
	_begin()
	_on_action(key)
	_refresh()


# 動きを 1 本始める。終わるまで入力を受けない。
func _begin() -> void:
	busy = true
	tw = create_tween()
	tw.tween_interval(0.01)


func _finish_tween() -> void:
	if tw != null and tw.is_valid() and tw.is_running():
		tw.custom_step(100.0)


# 動きが終わって、次の操作を待つ。
func _idle() -> void:
	busy = false
	_refresh()


# 勝負が付いた後の表示。戻りは、結果が決まった時点で呼ぶ側が保存しておく(動きの途中で閉じても戻りが残る)。
func _end(text: String, color: Color, sound: String, returned: int) -> void:
	message.text = text
	message.add_theme_color_override("font_color", color)
	if returned > 0:
		_show_delta(returned, true)
	app.sfx.play(sound)
	quiet_until = Time.get_ticks_msec() + Kit.press_guard_ms
	_enter_bet()


# D-A10: 勝負の途中は戻れない。
func _back() -> void:
	if phase == "bet" and not busy:
		back_pressed.emit()


# ---- 入力(§7.5) ----

func _key_action(keycode: int) -> String:
	for a in _actions():
		if keycode in a[2]:
			return a[0]
	return ""


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var k: int = event.keycode
	if k == KEY_ESCAPE:
		_back()
	elif phase == "bet" and k in DEAL_KEYS:
		_deal()
	elif phase == "bet" and k in BET_KEYS:
		_pick_bet(B.BET_CHOICES[BET_KEYS.find(k)])
	elif phase == "play" and _key_action(k) != "":
		_act(_key_action(k))
	elif not _extra_key(k):
		return
	get_viewport().set_input_as_handled()
