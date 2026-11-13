# 対戦の通信の口(D-30)。画面と versus_session はここだけを見て、WebRTC を直接さわらない。
# 実装は rtc_transport.gd。link は相手ごとの番号(ホストでは席の番号 1〜3、ゲストではホストへの 0)。
# 接続情報の項目(items)の形は core/invite_codec.gd と同じ(kind と reply_to は呼ぶ側が足す)。
extends RefCounted

# 自分の接続情報がそろった。作れなかったら空の辞書(E-23)
@warning_ignore("unused_signal")
signal described(link: int, items: Dictionary)
@warning_ignore("unused_signal")
signal opened(link: int)
@warning_ignore("unused_signal")
signal received(link: int, text: String)
@warning_ignore("unused_signal")
signal closed(link: int)


# ホスト: link の席のための接続を作り始める。そろったら described が出る。
func make_invite(_link: int) -> bool:
	return false


# ゲスト: 招待の項目を相手の情報として渡し、返事を作り始める。
func make_answer(_link: int, _invite: Dictionary) -> bool:
	return false


# ホスト: 返事の項目を、待っている接続に渡す。
func take_answer(_link: int, _answer: Dictionary) -> bool:
	return false


func send(_link: int, _text: String) -> bool:
	return false


# 接続を捨てる(closed は出さない)。
func drop(_link: int) -> void:
	pass


# 毎フレーム呼ぶ。届いた物をシグナルにして出す。
func poll() -> void:
	pass
