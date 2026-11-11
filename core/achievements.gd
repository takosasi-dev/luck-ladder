# 実績 35 個の定義と判定(§9.7・D-18)。判定は judge の 1 か所だけで、1 手ごととラン終了時に呼ぶ。
# 名前と条件の文言は core/strings.gd の ACHIEVEMENTS にある。
extends RefCounted

# ID → [等級, 隠し]。等級は見た目の枠の色だけに使う
const DEFS := {
	"A-01": ["bronze", false], "A-02": ["bronze", false], "A-03": ["bronze", false],
	"A-04": ["bronze", false], "A-05": ["silver", false], "A-06": ["gold", false],
	"A-07": ["bronze", false], "A-08": ["silver", false], "A-09": ["silver", false],
	"A-10": ["bronze", false], "A-11": ["silver", false], "A-12": ["gold", false],
	"A-13": ["silver", false], "A-14": ["gold", false], "A-15": ["gold", false],
	"A-16": ["bronze", false], "A-17": ["silver", false], "A-18": ["gold", false],
	"A-19": ["gold", false], "A-20": ["silver", false], "A-21": ["silver", false],
	"A-22": ["bronze", false], "A-23": ["bronze", false], "A-24": ["silver", false],
	"A-25": ["gold", false], "A-26": ["silver", false], "A-27": ["gold", false],
	"A-28": ["silver", false], "A-29": ["gold", false], "A-30": ["bronze", true],
	"A-31": ["silver", true], "A-32": ["silver", true], "A-33": ["bronze", false],
	"A-34": ["silver", false], "A-35": ["gold", false],
}


static func ids() -> Array:
	return DEFS.keys()


static func is_hidden(id: String) -> bool:
	return DEFS.has(id) and DEFS[id][1]


# 条件を満たしている実績の ID(達成済みかは見ない。呼ぶ側が新しい物だけを拾う)。
# ctx: {totals: Dictionary, daily_streak: int, daily_days: int}。at_end が偽なら 1 手ごとの判定。
static func judge(s, ctx: Dictionary, at_end: bool) -> Array:
	var out := []
	if not s.counts_for_records():
		return out
	var t: Dictionary = ctx.get("totals", {})
	var checks := {
		"A-02": s.banks >= 1,
		"A-03": s.best_streak >= 3,
		"A-04": s.best_streak >= 5,
		"A-05": s.best_streak >= 8,
		"A-06": s.best_streak >= 12,
		"A-07": s.longshot_hits >= 1,
		"A-09": s.max_gain >= 3000,
		"A-10": s.banks >= 5,
		"A-11": s.max_bank >= 3000,
		"A-12": s.max_bank >= 8000,
		"A-20": s.comeback,
		"A-21": s.life_regains >= 3,
		"A-22": s.same_hits >= 1,
		"A-30": s.sure_misses >= 1,
		"A-31": s.max_pot_lost >= 5000,
		"A-32": s.same_hits >= 2,
	}
	if at_end:
		checks.merge({
			"A-01": true,
			"A-08": int(t.get("longshot_hits", 0)) >= 25,
			"A-13": s.cleared,
			"A-14": s.cleared and s.end_lives == 4,
			"A-15": s.cleared and s.misses <= 6,
			"A-16": s.score >= 3000,
			"A-17": s.score >= 10000,
			"A-18": s.score >= 20000,
			"A-19": s.cleared and not s.counter_shown,
			"A-23": s.mode == "daily" and s.first_daily,
			"A-24": int(ctx.get("daily_streak", 0)) >= 7,
			"A-25": int(ctx.get("daily_days", 0)) >= 30,
			"A-26": int(t.get("runs", 0)) >= 50,
			"A-27": int(t.get("runs", 0)) >= 200,
			"A-28": int(t.get("total_score", 0)) >= 100000,
			"A-29": int(t.get("total_score", 0)) >= 1000000,
			"A-33": s.mode == "versus" and s.versus_done,
			"A-34": s.mode == "versus" and s.versus_done and s.versus_players >= 2 and s.versus_solo_first,
			"A-35": s.mode == "versus" and s.versus_done and s.versus_players == 4 and s.versus_solo_first,
		})
	for id in DEFS:
		if checks.get(id, false):
			out.append(id)
	return out
