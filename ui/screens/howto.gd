# 遊び方の画面(タイトルの「遊び方」)。ルール・完走のボーナス・操作・対戦の勝ち負けを文で出す。
# 文言は core/strings.gd、ボーナスの点は core/balance.gd の値をそのまま出す(ここでは計算しない)。
extends "res://ui/screens/page.gd"

const B := preload("res://core/balance.gd")
const ShareText := preload("res://core/share_text.gd")


func _title() -> String:
	return S.BTN_HOWTO


func _fill() -> void:
	section(S.HOWTO_SEC_RULES)
	for text in S.HOWTO_RULES:
		_line(text)
	_line(S.HOWTO_CLEAR % [ShareText.group(B.CLEAR_BONUS), ShareText.group(B.LIFE_BONUS)])
	section(S.HOWTO_SEC_OPS)
	for text in S.HOWTO_OPS:
		_line(text)
	section(S.BTN_VERSUS)
	_line(S.HOWTO_VERSUS)


func _line(text: String) -> void:
	var l := Kit.label(text, T.FS_BODY - 2, T.W_BODY)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	body.add_child(l)
