# 画面に出す文言をまとめる(INV-6)。文言はこのファイルにだけ置く。
# 同梱フォントがここの全文字を持つことを tests/run_tests.gd で確かめる。
extends RefCounted

const TITLE := "LuckLadder"
const SUBTITLE := "ハイ&ローの梯子"
const VERSION_PREFIX := "v"

# タイトル(Phase 3 は「つづきから」「ラン」「設定」)
const BTN_RUN := "ラン"
const BTN_CONTINUE := "つづきから"
const BTN_SETTINGS := "設定"
const CONFIRM_DISCARD := "途中のランを捨てて新しく始めますか"
const BTN_DISCARD := "捨てて始める"
const BTN_CANCEL := "やめる"
const RESTORE_FAILED := "前回の途中のランは復元できませんでした"
const BTN_DAILY := "今日の山札"
const DAILY_NO := "No.%d"
const DAILY_FIRST := "初回 %s 点"
const DAILY_ONGOING := "途中"
const DAILY_AGAIN := "2 回目からは記録に残りません"
const BTN_START := "はじめる"
const BTN_VERSUS := "対戦"
const COMING_SOON := "準備中"
const BTN_ACH := "実績"
const ACH_COUNT := "%d / %d"
const BTN_COLLECTION := "コレクション"
const BTN_RECORDS := "記録"

# プレイ(FR-4・§9.1)
const BTN_PAUSE := "一時停止"
const SCORE_LABEL := "得点"
const POT_LABEL := "ポット"
const MODE_RUN := "ラン"
const MODE_DAILY := "今日の山札 No.%d"
const TOAST_HEAD := "実績を達成"
const DECK_LEFT := "残り %d"
const BTN_HIGH := "HIGH"
const BTN_LOW := "LOW"
const BTN_SAME := "同じ"
const BTN_BANK := "確保"
const QUOTE := "+%s"
const QUOTE_NONE := "なし"
const BANK_EMPTY := "—"
const STREAK := "%d 連続"
const MULT := "×%d.%d"
const RANKS := ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]
const CALL_LONGSHOT := "大穴"
const CALL_SAME := "ぴたり"
const CALL_LIFE := "ライフ +1"
const CALL_BANK := "確保 +%s"
const CALL_CLEAR := "完走"
const TUT_1 := "次の札は、大きい? 小さい?"
const TUT_2 := "当てた点はポットに貯まる。外すと 0"
const TUT_3 := "確保すると自分の点になる"

# 一時停止(FR-24)
const PAUSED := "一時停止"
const BTN_RESUME := "つづける"
const BTN_TO_TITLE := "タイトルへ"
const PAUSE_NOTE := "途中のランは保存されます"

# 設定(FR-21 のうち Phase 3 の分)
const SETTINGS := "設定"
const BTN_BACK := "もどる"
const SET_BGM := "BGM の音量"
const SET_SFX := "効果音の音量"
const SET_FX := "演出"
const FX_FULL := "標準"
const FX_LITE := "控えめ"
const SET_SPEED := "めくりの速さ"
const SPEED_NORMAL := "標準"
const SPEED_FAST := "速い"
const SET_COUNTER := "残り札の表示"
const SWITCH_ON := "入"
const SWITCH_OFF := "切"
const SET_TUTORIAL := "手ほどき"
const BTN_TUTORIAL_AGAIN := "もう一度"
const TUTORIAL_QUEUED := "次のランで出ます"
const SAVE_UNAVAILABLE := "このブラウザでは記録が残りません"
const SET_DATA := "保存データ"
const BTN_DATA := "書き出し・読み込み"

# 保存データ(FR-25・FR-26)
const EXPORT_HEAD := "書き出し"
const EXPORT_NOTE := "この文字を控えておくと、別の端末やブラウザに移せます"
const BTN_COPY := "コピー"
const COPY_TRIED := "コピーを試しました。貼れないときは下の文字を選んでコピーしてください"
const IMPORT_HEAD := "読み込み"
const IMPORT_HINT := "書き出した文字をここに貼る"
const BTN_IMPORT := "読み込む"
const IMPORT_CONFIRM := "今のデータを上書きします"
const BTN_OVERWRITE := "上書きする"
const IMPORT_FAILED := "読み込めませんでした。今のデータは変えていません"
const IMPORT_DONE := "読み込みました"
const ERASE_HEAD := "消去"
const BTN_ERASE := "保存データを消す"
const BTN_ERASE_CONFIRM := "本当に消す"
const ERASE_DONE := "保存データを消しました"

# 実績(FR-18)・記録(FR-19)・コレクション(FR-20)
const ACH_DATE := "達成 %s"
const REC_RUNS := "ラン数"
const REC_CLEARS := "完走数"
const REC_BEST := "最高得点"
const REC_STREAK := "最大の連続"
const REC_TOTAL := "通算得点"
const REC_HITS := "当たり / 外れ"
const REC_RATE := "当たりの割合"
const REC_RATE_VALUE := "%d%%"
const REC_SAME := "「同じ」の当たり"
const REC_DAILY_DAYS := "今日の山札の日数"
const REC_DAILY_STREAK := "連続日数"
const REC_TOP := "得点の上位"
const REC_EMPTY := "まだ記録がありません"
const REC_MODES := {"run": "ラン", "daily": "今日の山札", "versus": "対戦"}
const REC_DRAWS := "%d 枚"
const REC_CLEAR_MARK := "完走"
const COL_BACKS := "札の裏面"
const COL_TABLES := "テーブル"
const COL_COND := "条件: %s"
const COND_TITLE := "称号「%s」"
const COND_COUNT := "実績を %d 個"

# 追補 1: ブラックジャックとポーカー。「チップ」や通貨の字は使わない(D-A9)
const BTN_BJ := "ブラックジャック"
const BTN_POKER := "ポーカー"
const WALLET := "持ち点"
const WALLET_REFILLED := "持ち点を %s 点に補充しました"
const BET_LABEL := "賭ける点 %s"
const BTN_DEAL := "配る"
const BTN_HIT := "ヒット"
const BTN_STAND := "スタンド"
const BTN_DOUBLE := "ダブル"
const DEALER := "ディーラー"
const PLAYER := "あなた"
const BJ_RESULTS := {"natural": "ブラックジャック", "win": "勝ち", "push": "引き分け", "lose": "負け", "bust": "バースト"}
const DELTA_PLUS := "+%s"
const REC_WALLET_PEAK := "持ち点の最高"
const REC_REFILLS := "補充した回数"
const REC_HANDS := "勝負の数"
const REC_WINS := "勝った数"
const REC_NATURALS := "ブラックジャックの数"
# 並びは役の番号(0 = 役なし … 9 = ロイヤルフラッシュ。core/poker_rules.gd)
const POKER_HANDS := ["役なし", "J 以上のペア", "ツーペア", "スリーカード", "ストレート", "フラッシュ", "フルハウス", "フォーカード", "ストレートフラッシュ", "ロイヤルフラッシュ"]
const PAY_TIMES := "×%s"
const BTN_DRAW := "交換"
const HOLD := "残す"
const REC_PK_PAID := "配当が付いた数"
const REC_PK_BEST := "いちばん良い役"

# 対戦のつなぎ方(§9.15・§10)
const NET_NO_ROUTE := "この回線からは対戦につなげませんでした。別の回線(Wi-Fi とモバイル回線を替える)で試してください"
const NET_UNREADABLE := "読み取れませんでした。URL を最後までコピーできているか確かめてください"
const NET_VERSION := "相手とゲームの版が違います。両方でページを読み込み直してください"
const NET_PASTE_FAILED := "貼り付けを使えませんでした。下の欄に貼ってください"
const RELAY_DONE := "元のタブに戻ってください。このタブは閉じてかまいません"
const RELAY_LOST := "部屋のタブが見つかりません。部屋の画面で『返事を貼り付け』を押してください"

# 接続の実験の画面(Phase 6 だけ。Phase 7 で部屋の画面に置き換えて消す)
const LAB_TITLE := "接続の実験"
const LAB_IDLE := "「招待を作る」を押すか、招待の URL を貼ってください"
const LAB_MAKE_INVITE := "招待を作る"
const LAB_PASTE := "クリップボードから貼り付け"
const LAB_USE_BOX := "上の欄の文字を使う"
const LAB_PROMPT := "小窓で入力"
const LAB_PROMPT_ASK := "招待か返事の URL を貼ってください"
const LAB_DERIVED := "合言葉を省く: %s"
const LAB_MDNS := "同じ Wi-Fi 用の名前も載せる: %s"
const LAB_V6 := "IPv6 のアドレスも載せる: %s"
const LAB_ON := "入"
const LAB_OFF := "切"
const LAB_PING := "送る試験(60 秒)"
const LAB_COPY_URL := "URL をコピー"
const LAB_SHARE := "共有"
const LAB_COPY_RECORD := "記録をコピー"
const LAB_PASTE_HINT := "ここに URL を貼る(字を打てるかも試す)"
const LAB_WAIT_ICE := "外向きの IP を集めています…"
const LAB_INVITE_READY := "招待の URL ができました。「URL をコピー」で相手に送ってください。相手から返事の URL が届いたら、このブラウザで開くとつながります"
const LAB_ANSWER_READY := "返事の URL ができました。まだつながっていません。「URL をコピー」で、招待をくれた相手に送り返してください"
const LAB_NOT_CONNECTED := "まだつながっていません。緑の「届いた」が出てから押してください"
const LAB_CONNECTING := "つないでいます…"
const LAB_CONNECTED := "届いた"
const LAB_CLOSED := "切れました"
const LAB_NO_RTC := "このブラウザでは WebRTC を使えませんでした"
const LAB_COPIED := "コピーを試しました"
const LAB_PING_RUN := "送っています… %d / %d"
const LAB_PING_DONE := "送る試験: 届かなかった数 %d、往復の遅れ(中央値)%d ミリ秒"
const LAB_NOTE := "招待と返事の URL には、あなたの IP アドレスが入ります。つながると、相手にも IP アドレスが見えます"

# 結果(FR-13)
const RESULT_GAMEOVER := "ラン終了"
const RESULT_CLEAR := "完走"
const RESULT_DRAWS := "めくった枚数"
const RESULT_HITS := "当たり / 外れ"
const RESULT_HITS_VALUE := "%d / %d"
const RESULT_SAME := "「同じ」の当たり"
const RESULT_STREAK := "最大の連続"
const RESULT_BANKS := "確保"
const RESULT_BEST := "自己ベスト更新"
const RESULT_NOT_RECORDED := "この回は記録に残りません"
const BTN_COPY_RESULT := "結果をコピー"
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
