# 画面に出す文言をまとめる(INV-6)。文言はこのファイルにだけ置く。
# 同梱フォントがここの全文字を持つことを tests/run_tests.gd で確かめる。
extends RefCounted

const TITLE := "LuckLadder"
const SUBTITLE := "ハイ&ローの梯子"
const VERSION_PREFIX := "v"

# タイトル(Phase 2 は「ラン」と「つづきから」だけ)
const BTN_RUN := "ラン"
const BTN_CONTINUE := "つづきから"
const CONFIRM_DISCARD := "途中のランを捨てて新しく始めますか"
const BTN_DISCARD := "捨てて始める"
const BTN_CANCEL := "やめる"
const RESTORE_FAILED := "前回の途中のランは復元できませんでした"
const FIXED_OK := "固定値 一致"
const FIXED_NG := "固定値 不一致"

# プレイ(FR-4・§9.1)
const BTN_PAUSE := "一時停止"
const SCORE := "得点 %s"
const MODE_RUN := "ラン"
const LIVES := "ライフ "
const LIFE_ON := "●"
const LIFE_OFF := "○"
const DECK_LEFT := "残り %d"
const POT := "ポット %s"
const BTN_HIGH := "▲ HIGH"
const BTN_LOW := "▼ LOW"
const BTN_SAME := "= 同じ"
const BTN_BANK := "確保"
const QUOTE := "+%s"
const QUOTE_NONE := "なし"
const BANK_EMPTY := "—"
const STREAK := "%d 連続"
const MULT := "x%d.%d"
const RANKS := ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]
const ST_HIT := "○ 当たり +%s"
const ST_SAME := "◎ ぴたり +%s"
const ST_MISS := "× 外れ"
const ST_LIFE_UP := "  ライフ +1"
const ST_BANKED := "確保 +%s"
const ST_CLEAR := "完走"
const TUT_1 := "次の札は、大きい? 小さい?"
const TUT_2 := "当てた点はポットに貯まる。外すと 0"
const TUT_3 := "確保すると自分の点になる"

# 一時停止(FR-24)
const PAUSED := "一時停止"
const BTN_RESUME := "つづける"
const BTN_TO_TITLE := "タイトルへ"
const PAUSE_NOTE := "途中のランは保存されます"

# 結果(FR-13)
const RESULT_GAMEOVER := "ラン終了"
const RESULT_CLEAR := "完走"
const RESULT_POINTS := "%s 点"
const RESULT_DRAWS := "めくった枚数 %d"
const RESULT_HITS := "当たり %d / 外れ %d"
const RESULT_SAME := "「同じ」の当たり %d"
const RESULT_STREAK := "最大の連続 %d"
const RESULT_BANKS := "確保 %d 回"
const RESULT_BEST := "自己ベスト更新"
const RESULT_ACH := "達成した実績: %s"
const RESULT_UNLOCK := "解放: %s"
const RESULT_TITLE_UP := "称号が「%s」に上がりました"
const BTN_RETRY := "もう一度"
const LIST_SEP := "、"

# 保存の既定値(§9.10)。後ろに 2 桁の数字を付ける
const DEFAULT_NAME := "プレイヤー"

# 共有テキスト(§9.11)
const SHARE_HEAD := "LuckLadder"
const SHARE_DAILY := "今日の山札"
const SHARE_RUN := "ラン"
const SHARE_FIRST := "初回"
const SHARE_NTH := "%d回目"
const SHARE_LINE := "%s点 / %d枚 / 最大%d連続"
const SHARE_CLEAR := "完走 "

# 実績(§9.7): ID → [名前, 条件]
const ACHIEVEMENTS := {
	"A-01": ["最初の一枚", "ランを 1 回終える"],
	"A-02": ["手堅く", "確保を 1 回する"],
	"A-03": ["三段目", "3 連続で当てる"],
	"A-04": ["五段目", "5 連続で当てる"],
	"A-05": ["八段目", "8 連続で当てる"],
	"A-06": ["梯子の上", "12 連続で当てる"],
	"A-07": ["大穴", "大穴を 1 回当てる"],
	"A-08": ["大穴ねらい", "大穴を通算 25 回当てる"],
	"A-09": ["一撃", "1 回の当たりで 3,000 点以上"],
	"A-10": ["こまめに", "1 ランで確保を 5 回する"],
	"A-11": ["大口", "1 回の確保で 3,000 点以上"],
	"A-12": ["超大口", "1 回の確保で 8,000 点以上"],
	"A-13": ["完走", "山札を最後までめくる"],
	"A-14": ["無傷の完走", "ライフ 4 のまま完走する"],
	"A-15": ["少ない傷", "外れ 6 回以下で完走する"],
	"A-16": ["3,000 点", "1 ランで 3,000 点"],
	"A-17": ["10,000 点", "1 ランで 10,000 点"],
	"A-18": ["20,000 点", "1 ランで 20,000 点"],
	"A-19": ["暗算", "残り札の表示を切ったまま完走する"],
	"A-20": ["崖っぷちから", "ライフ 1 から 3 まで戻す"],
	"A-21": ["しぶとい", "1 ランでライフを 3 回戻す"],
	"A-22": ["ぴたり", "「同じ」を当てる"],
	"A-23": ["今日の一組", "今日の山札を終える"],
	"A-24": ["七日つづけて", "今日の山札を 7 日つづけて遊ぶ"],
	"A-25": ["三十日", "今日の山札を 30 日遊ぶ"],
	"A-26": ["常連", "ランを通算 50 回終える"],
	"A-27": ["通いづめ", "ランを通算 200 回終える"],
	"A-28": ["十万点", "通算 100,000 点"],
	"A-29": ["百万点", "通算 1,000,000 点"],
	"A-30": ["まさか", "鉄板の側で外す"],
	"A-31": ["欲ばり", "5,000 点以上のポットを失う"],
	"A-32": ["二度あることは", "1 ランで「同じ」を 2 回当てる"],
	"A-33": ["卓を囲む", "対戦を 1 回終える"],
	"A-34": ["一着", "対戦で単独の 1 位になる"],
	"A-35": ["四人卓の一着", "4 人の対戦で単独の 1 位になる"],
}
const HIDDEN_TEXT := "???"

# 称号(§9.8)。段 1〜10 の順
const TITLES := ["見習い", "札読み", "梯子のぼり", "勝負師", "目利き", "ラウンジの常連", "山札の主", "梯子の達人", "夜の支配人", "伝説"]

# 札の裏面とテーブル(§9.8)
const CARD_BACKS := {
	"B-01": "紺の格子", "B-02": "えんじの菱", "B-03": "真鍮の梯子", "B-04": "深緑の波",
	"B-05": "白磁の点", "B-06": "夜空", "B-07": "金の放射", "B-08": "黒曜",
}
const TABLES := {"T-01": "ミッドナイト", "T-02": "ワイン", "T-03": "森", "T-04": "砂", "T-05": "墨"}
