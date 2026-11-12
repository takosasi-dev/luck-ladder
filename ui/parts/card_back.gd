# 札の裏面 8 種の模様をコードで描く(§9.8・D-13)。生成りの縁 5 px の内側に、地の色と線の模様。
# 色は ui/theme/tokens.gd の BACKS、解放の条件は core/progress.gd が持つ。乱数は使わず、いつも同じ模様になる。
extends RefCounted

const T := preload("res://ui/theme/tokens.gd")
const Kit := preload("res://ui/kit.gd")


static func draw(ci: CanvasItem, r: Rect2, id: String = "") -> void:
	var key := id if T.BACKS.has(id) else T.card_back
	var bg := Color(T.BACKS[key][0])
	var line := Color(T.BACKS[key][1])
	var border := maxf(3.0, r.size.x * 0.024)
	var radius := minf(T.R_CARD, r.size.x * 0.07)
	ci.draw_style_box(Kit.box(T.IVORY, int(radius)), r)
	var inner := r.grow(-border)
	ci.draw_style_box(Kit.box(bg, int(radius * 0.7), Color(line, 0.35), 1), inner)
	var a := inner.grow(-maxf(2.0, r.size.x * 0.02))
	# 模様の大きさは、札の幅 171(横長の山札)を基準に伸び縮みさせる
	var u := r.size.x / 171.0
	match key:
		"B-01":
			_lattice(ci, a, Color(line, 0.55), 10.5 * u, 1.5 * u)
		"B-02":
			_diamonds(ci, a, Color(line, 0.5), 22.0 * u)
		"B-03":
			_ladders(ci, a, Color(line, 0.7), u)
		"B-04":
			_waves(ci, a, Color(line, 0.8), u)
		"B-05":
			_dots(ci, a, Color(line, 0.75), 14.0 * u, 2.2 * u)
		"B-06":
			_stars(ci, a, line, u)
		"B-07":
			_rays(ci, a, Color(line, 0.7), u)
		"B-08":
			_obsidian(ci, a, Color(line, 0.9), u)


# 斜め 45 度の格子。
static func _lattice(ci: CanvasItem, a: Rect2, col: Color, step: float, w: float) -> void:
	var c := a.position.x + a.position.y
	while c < a.end.x + a.end.y:
		var xa := maxf(a.position.x, c - a.end.y)
		var xb := minf(a.end.x, c - a.position.y)
		if xa < xb:
			ci.draw_line(Vector2(xa, c - xa), Vector2(xb, c - xb), col, w, true)
		c += step
	c = a.position.x - a.end.y
	while c < a.end.x - a.position.y:
		var xa := maxf(a.position.x, c + a.position.y)
		var xb := minf(a.end.x, c + a.end.y)
		if xa < xb:
			ci.draw_line(Vector2(xa, xa - c), Vector2(xb, xb - c), col, w, true)
		c += step


# 菱形の並び(1 つおきにずらす)。
static func _diamonds(ci: CanvasItem, a: Rect2, col: Color, cell: float) -> void:
	var cols := int(a.size.x / cell)
	var rows := int(a.size.y / (cell * 0.5))
	var x0 := a.position.x + (a.size.x - cols * cell) / 2
	var y0 := a.position.y + (a.size.y - rows * cell * 0.5) / 2
	var h := cell * 0.42
	for j in rows:
		for i in cols:
			if j % 2 == 1 and i == cols - 1:
				continue
			var c := Vector2(x0 + (i + 0.5 + (0.5 if j % 2 == 1 else 0.0)) * cell, y0 + (j + 0.5) * cell * 0.5)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -h * 0.5), c + Vector2(h * 0.5, 0), c + Vector2(0, h * 0.5), c + Vector2(-h * 0.5, 0)]), col)


# 縦の梯子の並び(2 本の柱と横木)。
static func _ladders(ci: CanvasItem, a: Rect2, col: Color, u: float) -> void:
	var n := 3
	var gap := a.size.x / n
	var w := gap * 0.42
	for k in n:
		var cx := a.position.x + (k + 0.5) * gap
		for side in [-1.0, 1.0]:
			ci.draw_line(Vector2(cx + side * w / 2, a.position.y), Vector2(cx + side * w / 2, a.end.y), col, 2.5 * u, true)
		var y := a.position.y + 9 * u
		while y < a.end.y - 4 * u:
			ci.draw_line(Vector2(cx - w / 2, y), Vector2(cx + w / 2, y), col, 2.2 * u, true)
			y += 15 * u


# 横の波線 6 本。
static func _waves(ci: CanvasItem, a: Rect2, col: Color, u: float) -> void:
	for k in 6:
		var y0 := a.position.y + (k + 0.5) * a.size.y / 6
		var pts := PackedVector2Array()
		var steps := 40
		for i in steps + 1:
			var x := a.position.x + a.size.x * i / steps
			pts.append(Vector2(x, y0 + sin(float(i) / steps * TAU * 3.0) * 6.0 * u))
		ci.draw_polyline(pts, col, 2.2 * u, true)


# 等間隔の点。
static func _dots(ci: CanvasItem, a: Rect2, col: Color, cell: float, rad: float) -> void:
	var cols := int(a.size.x / cell)
	var rows := int(a.size.y / cell)
	var x0 := a.position.x + (a.size.x - (cols - 1) * cell) / 2
	var y0 := a.position.y + (a.size.y - (rows - 1) * cell) / 2
	for j in rows:
		for i in cols:
			ci.draw_circle(Vector2(x0 + i * cell, y0 + j * cell), rad, col, true, -1.0, true)


# 夜空: 大きさの違う点 40 個。位置は式で決めた固定の並び(黄金比のずらし)。
static func _stars(ci: CanvasItem, a: Rect2, col: Color, u: float) -> void:
	var b := a.grow(-4 * u)
	for i in 40:
		var fx := fposmod(0.137 + i * 0.6180339887, 1.0)
		var fy := fposmod(0.311 + i * 0.7548776662, 1.0)
		var rad := (0.8 + 1.9 * fposmod(i * 0.3819660113, 1.0)) * u
		ci.draw_circle(b.position + Vector2(fx, fy) * b.size, rad, Color(col, 0.55 + 0.45 * fposmod(i * 0.57, 1.0)), true, -1.0, true)


# 中心から 24 本の線(札の縁まで)。
static func _rays(ci: CanvasItem, a: Rect2, col: Color, u: float) -> void:
	var c := a.get_center()
	for k in 24:
		var d := Vector2.from_angle(TAU * k / 24.0)
		var tx := (a.size.x / 2) / maxf(absf(d.x), 0.0001)
		var ty := (a.size.y / 2) / maxf(absf(d.y), 0.0001)
		ci.draw_line(c + d * 7 * u, c + d * minf(tx, ty), col, 1.8 * u, true)
	ci.draw_circle(c, 4.5 * u, col, true, -1.0, true)


# 二重の枠と、中央の菱 1 つ。
static func _obsidian(ci: CanvasItem, a: Rect2, col: Color, u: float) -> void:
	Kit.draw_outline(ci, a.grow(-5 * u), 5 * u, col, 2.0 * u)
	Kit.draw_outline(ci, a.grow(-11 * u), 3 * u, Color(col, 0.6), 1.0 * u)
	var c := a.get_center()
	var h := a.size.x * 0.2
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -h * 1.3), c + Vector2(h, 0), c + Vector2(0, h * 1.3), c + Vector2(-h, 0)]), col)
