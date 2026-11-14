# ブラウザの機能への橋(§2・前提 26)。URL の読み取り・クリップボードの読み取り・共有・タブ間の受け渡し・保存の置き場。
# JavaScriptBridge を使うのはこのファイルだけ(AC-37)。JavaScript の文を文字列で組み立てず、値は引数で渡す。
# ブラウザの外(テスト・エディター)では、どの関数も「使えない」を返すだけで落ちない。
extends RefCounted

signal clipboard_read(ok: bool, text: String)
signal answer_received(code: String)
signal answer_taken

const CHANNEL_NAME := "luck-ladder-answer"
# 受け取った側が返す決まった返事(D-28)
const TAKEN := "taken"

var _channel
# 画面を消さないための鍵(WakeLockSentinel)。持っていない間は null
var _wake = null
var _wake_wanted := false
var _wake_cbs := []
# JavaScript に渡したコールバックは、持っておかないと消える
var _callbacks := []


static func on_web() -> bool:
	return OS.has_feature("web")


func _js(name: String):
	return JavaScriptBridge.get_interface(name) if on_web() else null


func _callback(fn: Callable):
	var cb = JavaScriptBridge.create_callback(fn)
	_callbacks.append(cb)
	return cb


# ---- 保存の置き場(save/save_store.gd が使う)。localStorage は同じサイトのゲームで 1 つだが、書いてもほかのキーには触らない ----

# キーの値。無い時・ブラウザの外・保存を止めたブラウザでは null。
static func storage_get(key: String):
	var s = _storage()
	if s == null:
		return null
	var v = s.getItem(key)
	return v if v is String else null


# 書けたら真。setItem は一杯の時に投げ(橋が受け止めて null を返す)、通っても何も返さないので、読み直して確かめる。
static func storage_set(key: String, text: String) -> bool:
	var s = _storage()
	if s == null:
		return false
	s.setItem(key, text)
	var back = s.getItem(key)
	return back is String and back == text


# 保存を止めたブラウザでは、window.localStorage を読むだけで投げる。get_interface("localStorage") ではその例外が止まらないので、
# window の項目として読む(橋が受け止めて null を返す)。
static func _storage():
	if not on_web():
		return null
	var w = JavaScriptBridge.get_interface("window")
	return w.localStorage if w != null else null


# ページの URL の「?」から後ろ(引数が無ければ空の文字)。
func url_query() -> String:
	var w = _js("window")
	return str(w.location.search) if w != null else ""


# ページの URL から引数とハッシュを除いた物(招待 URL の頭に使う)。
func page_url() -> String:
	var w = _js("window")
	return str(w.location.origin) + str(w.location.pathname) if w != null else ""


func user_agent() -> String:
	var n = _js("navigator")
	return str(n.userAgent) if n != null else ""


# ブラウザの入力の小窓(E-28: 画面の入力欄に字を入れられない端末のため)。やめたときは空の文字。
func prompt_text(message: String) -> String:
	var w = _js("window")
	if w == null:
		return ""
	var v = w.prompt(message, "")
	return "" if v == null else str(v)


func can_read_clipboard() -> bool:
	var n = _js("navigator")
	return n != null and n.clipboard != null and n.clipboard.readText != null


# クリップボードを読む。結果は clipboard_read で届く(ボタンを押した操作の中で呼ぶこと)。
func read_clipboard() -> void:
	if not can_read_clipboard():
		clipboard_read.emit(false, "")
		return
	var ok = _callback(func(args: Array): clipboard_read.emit(true, str(args[0])))
	var ng = _callback(func(_args: Array): clipboard_read.emit(false, ""))
	_js("navigator").clipboard.readText().then(ok, ng)


func can_share() -> bool:
	var n = _js("navigator")
	return n != null and n.share != null


# 端末の共有の小窓に URL を渡す(ボタンを押した操作の中で呼ぶこと)。
func share_url(url: String) -> void:
	if not can_share():
		return
	var data = JavaScriptBridge.create_object("Object")
	data.url = url
	var ng = _callback(func(_args: Array): pass)
	_js("navigator").share(data).catch(ng)


# 部屋と対戦の間、画面が自動で消えるのを止める(消えるとブラウザが止まり、相手から切断に見える)。
# 対応していないブラウザでは何もしない。ブラウザを隠すと勝手に外れるので、戻ってきたらもう一度呼ぶ。
func keep_awake(on: bool) -> void:
	_wake_wanted = on
	var held: bool = _wake != null and not _wake.released
	if held == on:
		return
	if held:
		_wake.release()
		_wake = null
		return
	var n = _js("navigator")
	if n == null or n.wakeLock == null:
		return
	if _wake_cbs.is_empty():
		_wake_cbs = [_callback(_on_wake), _callback(func(_args: Array): pass)]
	n.wakeLock.request("screen").then(_wake_cbs[0], _wake_cbs[1])


func _on_wake(args: Array) -> void:
	# 頼んでから届くまでの間に要らなくなっていたら、すぐ返す
	if _wake_wanted:
		_wake = args[0]
	else:
		args[0].release()


func can_broadcast() -> bool:
	var w = _js("window")
	return w != null and w.BroadcastChannel != null


func _open_channel() -> bool:
	if _channel == null and can_broadcast():
		_channel = JavaScriptBridge.create_object("BroadcastChannel", CHANNEL_NAME)
		_channel.onmessage = _callback(_on_channel_message)
	return _channel != null


# 部屋のタブ: 返事のコードを待つ。届いたら answer_received を出し、送ったタブへ受け取りを返す。
func listen_for_answer() -> bool:
	return _open_channel()


# ?a= で開かれたタブ: 部屋のタブへコードを送る。受け取られたら answer_taken が出る。
func send_answer(code: String) -> bool:
	if not _open_channel():
		return false
	_channel.postMessage(code)
	return true


func _on_channel_message(args: Array) -> void:
	var text := str(args[0].data)
	if text == TAKEN:
		answer_taken.emit()
	elif answer_received.get_connections().size() > 0:
		_channel.postMessage(TAKEN)
		answer_received.emit(text)
