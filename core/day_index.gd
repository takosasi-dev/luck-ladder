# 日付から通し日数・今日の山札の番号と種を出す(§9.5)。整数の計算だけで、グレゴリオ暦のうるう年を含む。
# 日付は端末のローカルの日付。連続日数の更新もここで行う。
extends RefCounted

const B := preload("res://core/balance.gd")


# 1970-01-01 からの通し日数(H. Hinnant の days_from_civil)。
@warning_ignore("integer_division")
static func days_from_civil(y: int, m: int, d: int) -> int:
	if m <= 2:
		y -= 1
	var era := (y if y >= 0 else y - 399) / 400
	var yoe := y - era * 400
	var mp := (m + 9) % 12
	var doy := (153 * mp + 2) / 5 + d - 1
	var doe := yoe * 365 + yoe / 4 - yoe / 100 + doy
	return era * 146097 + doe - 719468


static func day_no(y: int, m: int, d: int) -> int:
	return days_from_civil(y, m, d) - B.DAY_NO_ORIGIN + 1


static func date_string(y: int, m: int, d: int) -> String:
	return "%04d-%02d-%02d" % [y, m, d]


static func daily_seed_text(date: String) -> String:
	return "LL1:daily:" + date


# "YYYY-MM-DD" → [y, m, d]。形が違えば空の配列。
static func parse(date: String) -> Array:
	var re := RegEx.create_from_string("^(\\d{4})-(\\d{2})-(\\d{2})$")
	var m := re.search(date)
	if m == null:
		return []
	var y := int(m.get_string(1))
	var mo := int(m.get_string(2))
	var d := int(m.get_string(3))
	if mo < 1 or mo > 12 or d < 1 or d > 31:
		return []
	return [y, mo, d]


static func is_date(date: String) -> bool:
	return not parse(date).is_empty()


# 今日の山札の初回を終えたときの連続日数(§9.5)。streak は {last, count}。新しい辞書を返す。
static func next_streak(streak: Dictionary, today: String) -> Dictionary:
	var t := parse(today)
	var l := parse(str(streak.get("last", "")))
	var count := int(streak.get("count", 0))
	if not l.is_empty() and not t.is_empty():
		var gap := days_from_civil(t[0], t[1], t[2]) - days_from_civil(l[0], l[1], l[2])
		if gap == 0:
			return {"last": today, "count": count}
		if gap == 1:
			return {"last": today, "count": count + 1}
	return {"last": today, "count": 1}


# 端末のローカルの日付 [y, m, d]。
static func today() -> Array:
	var t := Time.get_date_dict_from_system()
	return [int(t["year"]), int(t["month"]), int(t["day"])]
