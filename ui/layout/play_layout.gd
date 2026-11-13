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


# 対戦のときだけ変わる位置(画面設計書 §2.1・§2.2): 相手の札の帯と残り時間を足し、縦長では梯子と札を下げて小さくする。
# 横長は、帯が札に掛からない高さに収まるので、札の大きさは変えていない。
const VERSUS_LANDSCAPE := {
	"rivals": Rect2(176, 60, 752, 44),
	"timer": Rect2(540, 4, 330, 56),
}
const VERSUS_LANDSCAPE_OVER := {"callout": Rect2(176, 108, 752, 70)}
const VERSUS_PORTRAIT := {
	"rivals": Rect2(14, 98, 552, 62),
	"timer": Rect2(576, 98, 130, 62),
	"ladder": Rect2(14, 164, 692, 76),
	"deck": Rect2(128, 284, 176, 246),
	"deck_label": Rect2(128, 534, 176, 34),
	"card": Rect2(372, 250, 220, 308),
}
const VERSUS_PORTRAIT_OVER := {"callout": Rect2(14, 244, 692, 70)}


static func _with(base: Dictionary, extra: Dictionary, versus: bool) -> Dictionary:
	if not versus:
		return base
	var out := base.duplicate()
	out.merge(extra, true)
	return out


static func rects(landscape: bool, versus: bool = false) -> Dictionary:
	return _with(LANDSCAPE, VERSUS_LANDSCAPE, versus) if landscape else _with(PORTRAIT, VERSUS_PORTRAIT, versus)


static func over(landscape: bool, versus: bool = false) -> Dictionary:
	return _with(LANDSCAPE_OVER, VERSUS_LANDSCAPE_OVER, versus) if landscape else _with(PORTRAIT_OVER, VERSUS_PORTRAIT_OVER, versus)


static func size(landscape: bool) -> Vector2:
	return Vector2(1280, 720) if landscape else Vector2(720, 1280)
