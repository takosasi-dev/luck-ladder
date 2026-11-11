# プレイ画面の部品の位置と大きさ(§9.1・画面設計書 §2.1・§2.2)。横長 1280×720 と縦長 720×1280 の 2 つ。
# 部品は 2 つの配置で同じ物を使い、位置と大きさだけをここで決める。
extends RefCounted

const LANDSCAPE := {
	"pause": Rect2(14, 4, 120, 56),
	"score": Rect2(144, 4, 400, 56),
	"mode": Rect2(554, 4, 360, 56),
	"lives": Rect2(924, 4, 342, 56),
	"ladder": Rect2(14, 72, 150, 560),
	"tutorial": Rect2(176, 72, 752, 48),
	"deck": Rect2(367, 158, 171, 240),
	"deck_label": Rect2(367, 404, 171, 36),
	"card": Rect2(602, 128, 214, 300),
	"status": Rect2(176, 444, 752, 50),
	"pot": Rect2(176, 500, 752, 120),
	"high": Rect2(936, 72, 330, 180),
	"same": Rect2(936, 262, 160, 180),
	"bank": Rect2(1106, 262, 160, 180),
	"low": Rect2(936, 452, 330, 180),
	"counter": Rect2(14, 640, 1252, 66),
}

const PORTRAIT := {
	"pause": Rect2(14, 14, 120, 68),
	"score": Rect2(144, 14, 340, 68),
	"lives": Rect2(494, 14, 212, 68),
	"ladder": Rect2(14, 104, 692, 80),
	"tutorial": Rect2(14, 194, 692, 48),
	"deck": Rect2(106, 268, 208, 291),
	"deck_label": Rect2(106, 566, 208, 40),
	"card": Rect2(354, 248, 260, 364),
	"pot": Rect2(14, 618, 352, 66),
	"status": Rect2(376, 618, 330, 66),
	"counter": Rect2(14, 690, 692, 78),
	"high": Rect2(14, 778, 692, 150),
	"same": Rect2(14, 938, 341, 150),
	"bank": Rect2(365, 938, 341, 150),
	"low": Rect2(14, 1098, 692, 150),
}


static func rects(landscape: bool) -> Dictionary:
	return LANDSCAPE if landscape else PORTRAIT


static func size(landscape: bool) -> Vector2:
	return Vector2(1280, 720) if landscape else Vector2(720, 1280)
