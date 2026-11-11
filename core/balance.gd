# 調整値(§9.9・INV-7)。数値はここにだけ置く。
# 変えたら §9.4 の固定値を tools/ref_rules.py で計算し直し、tests/ の期待値も直す。
extends RefCounted

const BASE := 100
const GAIN_CAP := 5000
const STREAK_CAP := 10
const LIVES_START := 4
const LIVES_MAX := 4
const LIFE_EVERY := 3
const CLEAR_BONUS := 3000
const LIFE_BONUS := 1000
const TOP_RUNS := 10
const DAILY_KEEP := 60
const SWIPE_MIN := 60
const SHARE_URL := ""

const MATCH_SEC_CHOICES := [120, 180, 300, 0]
const MATCH_SEC_DEFAULT := 180
const VERSUS_MAX := 4
const INVITE_TTL_SEC := 120
const ICE_WAIT_SEC := 3
const STUN_URLS := ["stun:stun.l.google.com:19302"]
const NET_MSG_MAX := 1024
const NET_RATE_MAX := 20
const NET_SILENT_SEC := 10

# §9.5: 2026-01-01 の通し日数(この日が No.1)
const DAY_NO_ORIGIN := 20454
# §9.10: 途中のランの操作の列の上限(51 手 + 確保 51 回)
const ACTIONS_MAX := 102
# 保存の数の上限(JSON の数が小数で読まれても桁が落ちない範囲)
const SAVE_INT_MAX := 1000000000000000
