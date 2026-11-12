# ブラックジャックとポーカーの卓の、部品の位置と大きさ(追補 1 §7.2〜§7.4)。位置の数字はここにだけ置く。
# 基準は横長 1280×720 と縦長 720×1280。bets は賭ける点のボタン 4 つを並べる帯、actions は勝負の段階のボタンを並べる帯。
# bj_ はブラックジャック、pk_ はポーカー(pk_pays は配当表、pk_message は役の名前を出す場所)。
extends RefCounted

const LANDSCAPE := {
	"back": Rect2(14, 4, 150, 56),
	"name": Rect2(340, 4, 600, 56),
	"wallet_cap": Rect2(930, 4, 130, 56),
	"wallet": Rect2(1066, 4, 200, 56),
	"delta": Rect2(1066, 60, 200, 36),
	"notice": Rect2(240, 62, 800, 30),
	"message": Rect2(240, 284, 800, 64),
	"bet_label": Rect2(240, 550, 800, 44),
	"bets": Rect2(206, 608, 556, 96),
	"deal": Rect2(774, 608, 300, 96),
	"actions": Rect2(208, 608, 864, 96),
	"bj_dealer_cap": Rect2(90, 132, 180, 36),
	"bj_dealer_total": Rect2(90, 168, 180, 60),
	"bj_dealer": Rect2(290, 92, 700, 190),
	"bj_player_cap": Rect2(90, 390, 180, 36),
	"bj_player_total": Rect2(90, 426, 180, 60),
	"bj_player": Rect2(290, 350, 700, 190),
	"bj_card": Vector2(136, 190),
	"pk_pays": Rect2(24, 104, 340, 432),
	"pk_cards": Rect2(350, 200, 900, 210),
	"pk_card": Vector2(150, 210),
	"pk_message": Rect2(350, 436, 900, 64),
}

const PORTRAIT := {
	"back": Rect2(14, 8, 150, 88),
	"name": Rect2(170, 8, 260, 88),
	"wallet_cap": Rect2(436, 8, 270, 36),
	"wallet": Rect2(436, 40, 270, 56),
	"delta": Rect2(436, 96, 270, 36),
	"notice": Rect2(0, 136, 720, 34),
	"message": Rect2(0, 478, 720, 72),
	"bet_label": Rect2(0, 868, 720, 44),
	"bets": Rect2(22, 930, 676, 96),
	"deal": Rect2(22, 1040, 676, 110),
	"actions": Rect2(22, 1040, 676, 110),
	"bj_dealer_cap": Rect2(180, 180, 180, 44),
	"bj_dealer_total": Rect2(370, 180, 120, 44),
	"bj_dealer": Rect2(30, 230, 660, 238),
	"bj_player_cap": Rect2(180, 560, 180, 44),
	"bj_player_total": Rect2(370, 560, 120, 44),
	"bj_player": Rect2(30, 610, 660, 238),
	"bj_card": Vector2(170, 238),
	"pk_pays": Rect2(120, 180, 480, 342),
	"pk_cards": Rect2(10, 580, 700, 180),
	"pk_card": Vector2(128, 180),
	"pk_message": Rect2(0, 772, 720, 64),
}


static func rects(landscape: bool) -> Dictionary:
	return LANDSCAPE if landscape else PORTRAIT


# 帯 r の中央に札 n 枚を並べたときの、i 枚目の場所。幅に収まらなければ重ねて詰める(§7.3)。
static func fan(r: Rect2, card: Vector2, n: int, i: int, gap: float = 12.0) -> Rect2:
	var step := minf(card.x + gap, (r.size.x - card.x) / maxi(n - 1, 1))
	var x0 := r.position.x + (r.size.x - card.x - step * (n - 1)) / 2
	return Rect2(Vector2(x0 + step * i, r.position.y + (r.size.y - card.y) / 2), card)


# 帯 r の中に n 個のボタンを等しい幅で並べたときの、i 番目の場所。
static func slot(r: Rect2, n: int, i: int, gap: float = 12.0) -> Rect2:
	var w := (r.size.x - gap * (n - 1)) / n
	return Rect2(r.position.x + i * (w + gap), r.position.y, w, r.size.y)
