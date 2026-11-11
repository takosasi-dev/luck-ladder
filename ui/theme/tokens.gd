# 見た目の値(色・角丸・字の大きさ・動きの時間)をまとめる(§9.12・INV-7)。見た目の値はここにだけ置く。
# Phase 2 は仮の見た目なので、使う物だけを置いている。Phase 3 で画面設計書の値に広げる。
extends RefCounted

const BG_DEEP := Color("#0E1F1C")
const BG_FELT := Color("#17352F")
const FELT_HI := Color("#1F4A41")
const BRASS := Color("#C9A45C")
const BRASS_HI := Color("#F0D28A")
const IVORY := Color("#F5EFE0")
const INK := Color("#1B1B1F")
const SUIT_RED := Color("#B8323A")
const GOOD := Color("#5FD3A0")
const BAD := Color("#E2574C")
const TEXT := Color("#F2EDE1")
const TEXT_DIM := Color("#9FB3AC")
const BACK_B01 := Color("#1C2B4A")
const SAME_BG := Color("#3A3626")
const BANK_INK := Color("#1D1608")
const SCRIM := Color(0.03, 0.06, 0.055, 0.85)

const R_PANEL := 20
const R_BUTTON := 18
const R_CARD := 14

const FS_SCORE := 56
const FS_POT := 44
const FS_BUTTON := 40
const FS_QUOTE := 36
const FS_BODY := 28
const FS_SMALL := 22

const W_NUM := 700
const W_BODY := 500

# 札の入れ替え(仮の演出。標準の速さ)
const SWAP_SEC := 0.14
const FADE_SEC := 0.2
