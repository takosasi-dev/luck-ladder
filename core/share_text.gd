# 結果画面の共有テキスト(§9.11)。絵文字を使わず、得点は 3 桁ごとに半角のカンマで区切る。
# 「ラン」は番号・日付・回数を付けない。SHARE_URL が空なら最後の行を出さない。
extends RefCounted

const S := preload("res://core/strings.gd")


static func group(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


# attempt: 今日の山札の何回目か(1 が初回)。mode が "daily" 以外では使わない。
static func build(mode: String, no: int, date: String, attempt: int, score: int, cleared: bool, draws: int, best_streak: int, url: String) -> String:
	var lines := PackedStringArray()
	if mode == "daily":
		var nth := S.SHARE_FIRST if attempt <= 1 else S.SHARE_NTH % attempt
		lines.append("%s %s No.%d (%s) %s" % [S.SHARE_HEAD, S.SHARE_DAILY, no, date, nth])
	else:
		lines.append("%s %s" % [S.SHARE_HEAD, S.SHARE_RUN])
	lines.append((S.SHARE_CLEAR if cleared else "") + S.SHARE_LINE % [group(score), draws, best_streak])
	if url != "":
		lines.append(url)
	return "\n".join(lines)
