# 称号と、札の裏面・テーブルの解放の判定(§9.8)。通算の得点と達成済みの実績だけを見る。
# 名前の文言は core/strings.gd、色や模様は ui/ が持つ。
extends RefCounted

# 段 1〜10 に上がる通算の得点
const TITLE_STEPS := [0, 5000, 20000, 50000, 100000, 200000, 400000, 700000, 1000000, 2000000]

# 解放の条件: ["start"] / ["ach", 実績 ID] / ["title", 段] / ["count", 実績の数]
const BACKS := {
	"B-01": ["start"], "B-02": ["start"], "B-03": ["ach", "A-04"], "B-04": ["ach", "A-13"],
	"B-05": ["title", 3], "B-06": ["ach", "A-24"], "B-07": ["ach", "A-17"], "B-08": ["count", 24],
}
const TABLES := {
	"T-01": ["start"], "T-02": ["title", 2], "T-03": ["title", 4], "T-04": ["title", 6], "T-05": ["ach", "A-14"],
}


static func title_rank(total_score: int) -> int:
	var rank := 1
	for i in TITLE_STEPS.size():
		if total_score >= TITLE_STEPS[i]:
			rank = i + 1
	return rank


static func _met(cond: Array, achieved: Dictionary, total_score: int) -> bool:
	match cond[0]:
		"start":
			return true
		"ach":
			return achieved.has(cond[1])
		"title":
			return title_rank(total_score) >= cond[1]
		"count":
			return achieved.size() >= cond[1]
	return false


static func is_unlocked(id: String, achieved: Dictionary, total_score: int) -> bool:
	if BACKS.has(id):
		return _met(BACKS[id], achieved, total_score)
	if TABLES.has(id):
		return _met(TABLES[id], achieved, total_score)
	return false


# 解放済みの裏面とテーブルの ID(定義の順)。
static func unlocked(achieved: Dictionary, total_score: int) -> Array:
	var out := []
	for id in BACKS.keys() + TABLES.keys():
		if is_unlocked(id, achieved, total_score):
			out.append(id)
	return out
