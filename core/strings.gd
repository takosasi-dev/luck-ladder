# 画面に出す文言をまとめる(INV-6)。文言はこのファイルにだけ置く。
# 同梱フォントがここの全文字を持つことを tests/run_tests.gd で確かめる。
extends RefCounted

const TITLE := "LuckLadder"
const SUBTITLE := "ハイ&ローの梯子"
const VERSION_PREFIX := "v"

# Phase 0 の見本と診断表示(Phase 4 で消す)
const DEMO_LANDSCAPE := "横長"
const DEMO_PORTRAIT := "縦長"
const DEMO_BOXES := ["箱 1", "箱 2", "箱 3"]
const DIAG_HEAD := "診断"
const DIAG_OK := "一致"
const DIAG_NG := "不一致"
const DIAG_WINDOW := "窓"
