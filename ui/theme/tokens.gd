# 見た目の値(色・角丸・字の大きさ・動きの時間)をまとめる(§9.12・画面設計書 §1・INV-7)。
# 見た目の値はここにだけ置く。設定の「めくりの速さ」「演出」も、ここの speed と lite に写して使う。
extends RefCounted

# テーブル T-01(ミッドナイト)。着せ替えは Phase 4 で差し替える
const BG_DEEP := Color("#0E1F1C")
const BG_FELT := Color("#17352F")
const FELT_HI := Color("#1F4A41")
const BRASS := Color("#C9A45C")
const BRASS_HI := Color("#F0D28A")
const BRASS_LO := Color("#8A6A2C")
const IVORY := Color("#F5EFE0")
const INK := Color("#1B1B1F")
const SUIT_RED := Color("#B8323A")
const GOOD := Color("#5FD3A0")
const BAD := Color("#E2574C")
const LOWER := Color("#8FB7FF")
const TEXT := Color("#F2EDE1")
const TEXT_DIM := Color("#9FB3AC")

const CARD_TOP := Color("#FFFAF0")
const CARD_BOTTOM := Color("#E6DCC4")
const BACK_B01_BG := Color("#1C2B4A")
const BACK_B01_LINE := Color("#C9A45C")
const BET_TOP := Color("#27594E")
const BET_BOTTOM := Color("#183D35")
const SAME_TOP := Color("#3A3626")
const SAME_BOTTOM := Color("#262318")
const BANK_TOP := Color("#D9B76E")
const BANK_BOTTOM := Color("#A9823C")
const BANK_INK := Color("#1D1608")
const RUNG_INK := Color("#2A1F08")
const PANEL_BG := Color(0.055, 0.122, 0.11, 0.55)
const PANEL_EDGE := Color(0.788, 0.643, 0.361, 0.22)
const SCRIM := Color(0.031, 0.063, 0.055, 0.78)
const SHADOW := Color(0, 0, 0, 0.35)
const CONFETTI := [Color("#F0D28A"), Color("#5FD3A0"), Color("#F5EFE0"), Color("#B8323A"), Color("#8FB7FF")]

const R_PANEL := 20
const R_BUTTON := 18
const R_CARD := 14
const SHADOW_SIZE := 16
const SHADOW_DROP := 6

const FS_SCORE := 44
const FS_POT := 48
const FS_BUTTON := 28
const FS_QUOTE := 34
const FS_QUOTE_SMALL := 28
const FS_HEAD := 36
const FS_BODY := 28
const FS_SMALL := 22
const FS_TITLE := 104
const FS_CALLOUT := 48

const W_BLACK := 900
const W_NUM := 700
const W_BODY := 500

# 動きの時間(標準の速さ、秒)。§9.12
const PRESS_IN := 0.06
const PRESS_OUT := 0.12
const PRESS_SCALE := 0.94
const DEAL := 0.14
const FLIP := 0.22
const LITE_SWAP := 0.12
const EDGE_GLOW := 0.25
const FLY := 0.35
const COUNT_UP := 0.30
const LADDER_ON := 0.20
const SHINE := 0.6
const SHAKE := 0.18
const SHAKE_PX := 6.0
const POT_BREAK := 0.40
const LIFE_LOSE := 0.30
const LADDER_OFF := 0.30
const SAME_TEXT := 0.8
const BANK_FLY := 0.45
const BANK_SPARK := 0.60
const BANK_COUNT := 0.50
const LIFE_GAIN := 0.40
const CONFETTI_SEC := 2.0
const CLEAR_SPIN := 0.6
const CLEAR_WAIT := 1.4
const END_FADE := 0.5
const SCREEN_FADE := 0.20
const SCREEN_SHIFT := 12.0
const CALLOUT := 0.8
const RESULT_COUNT := 0.8
const SPARKS_HIT := 24
const SPARKS_BANK := 40
const CONFETTI_COUNT := 120
const PARTICLE_MAX := 200
# ボタンの点の色の段(元の値で決める。§9.1)
const QUOTE_TIER_1 := 300
const QUOTE_TIER_2 := 1000

static var speed := 1.0
static var lite := false


# 設定を写す(speed: "normal"/"fast"、fx: "full"/"lite")。
static func apply_settings(settings: Dictionary) -> void:
	speed = 0.6 if settings.get("speed") == "fast" else 1.0
	lite = settings.get("fx") == "lite"


# 速さの設定を掛けた時間。
static func t(sec: float) -> float:
	return sec * speed
