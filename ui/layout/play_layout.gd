# プレイ画面の部品の位置と大きさ(§9.1・画面設計書 §2.1・§2.2)。横長 1280×720 と縦長 720×1280 の 2 つ。
# 部品は 2 つの配置で同じ物を使い、位置と大きさだけをここで決める。OVER は部品の上に重ねて出す物(重なってよい)。
extends RefCounted

const LANDSCAPE := {
	"pause": Rect2(14, 4, 120, 56),
	"score": Rect2(150, 4, 380, 56),
	"mode": Rect2(540, 4, 330, 56),
	"lives": Rect2(1060, 4, 206, 56),
	"ladder": Rect2(14, 72, 150, 560),
	"deck": Rect2(250, 140, 171, 240),
	"deck_label": Rect2(250, 388, 171, 34),
	"card": Rect2(485, 104, 214, 300),
	"pot": Rect2(352, 432, 400, 130),
	"high": Rect2(936, 72, 330, 180),
	"same": Rect2(936, 262, 160, 180),
	"bank": Rect2(1106, 262, 160, 180),
	"low": Rect2(936, 452, 330, 180),
	"counter": Rect2(14, 640, 1252, 66),
}

const LANDSCAPE_OVER := {
	"pause_hit": Rect2(14, 0, 120, 96),
	"callout": Rect2(176, 66, 752, 70),
	"tut1": Rect2(596, 412, 330, 46),
	"tut2": Rect2(322, 566, 460, 46),
	"tut3": Rect2(966, 204, 300, 46),
	"toast": Rect2(896, 68, 370, 76),
}

const PORTRAIT := {
	"pause": Rect2(14, 14, 120, 68),
	"score": Rect2(144, 14, 330, 68),
	"lives": Rect2(484, 14, 222, 68),
	"ladder": Rect2(14, 104, 692, 80),
	"deck": Rect2(108, 236, 208, 291),
	"deck_label": Rect2(108, 532, 208, 34),
	"card": Rect2(352, 200, 260, 364),
	"pot": Rect2(160, 568, 400, 118),
	"counter": Rect2(14, 690, 692, 78),
	"high": Rect2(14, 778, 692, 150),
	"same": Rect2(14, 938, 341, 150),
	"bank": Rect2(365, 938, 341, 150),
	"low": Rect2(14, 1098, 692, 150),
}

const PORTRAIT_OVER := {
	"pause_hit": Rect2(14, 0, 120, 96),
	"callout": Rect2(14, 186, 692, 70),
	"tut1": Rect2(130, 712, 460, 48),
	"tut2": Rect2(130, 694, 460, 48),
	"tut3": Rect2(380, 884, 320, 44),
	"toast": Rect2(160, 100, 400, 76),
}


static func rects(landscape: bool) -> Dictionary:
	return LANDSCAPE if landscape else PORTRAIT


static func over(landscape: bool) -> Dictionary:
	return LANDSCAPE_OVER if landscape else PORTRAIT_OVER


static func size(landscape: bool) -> Vector2:
	return Vector2(1280, 720) if landscape else Vector2(720, 1280)
