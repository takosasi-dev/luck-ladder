# 振り返りの画面(追補 2 §5)。結果の画面の上に重ねて開き、1 手 1 行で、めくった札・予想・当たり外れ・点を並べる。
# 中身は core/run_state.gd の history が種と操作の列から作る。ここでは並べるだけで、保存データを変えない(FR-R6)。
extends "res://ui/screens/page.gd"

const RunState := preload("res://core/run_state.gd")
const Deck := preload("res://core/deck.gd")
const ShareText := preload("res://core/share_text.gd")

var seed_text := ""
var actions := ""
var bg: ColorRect


func set_run(seed_value: String, action_text: String) -> void:
	seed_text = seed_value
	actions = action_text


func _ready() -> void:
	super._ready()
	# 下の結果の画面を隠し、押しても届かないようにする
	bg = ColorRect.new()
	bg.color = T.BG_DEEP
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)
	move_child(bg, 0)


func _title() -> String:
	return S.BTN_REVIEW


func relayout(is_landscape: bool, view: Rect2) -> void:
	super.relayout(is_landscape, view)
	Kit.place(bg, view)


func _fill() -> void:
	var h: Dictionary = RunState.history(seed_text, actions)
	if not h["ok"]:
		return
	var steps: Array = h["steps"]
	var worst := 0
	var worst_at := 0
	for i in steps.size():
		if steps[i]["kind"] == "guess" and steps[i]["pot_lost"] > worst:
			worst = steps[i]["pot_lost"]
			worst_at = i + 1
	if worst > 0:
		_row(S.REVIEW_WORST % [ShareText.group(worst), worst_at], T.BAD, T.FS_BODY - 2)
	for i in steps.size():
		var s: Dictionary = steps[i]
		if s["kind"] == "bank":
			_row(S.REVIEW_BANK % [i + 1, ShareText.group(s["amount"])], T.BRASS_HI)
			continue
		var hit: bool = s["result"] == "hit"
		var amount := (S.QUOTE % ShareText.group(s["gain"])) if hit else ("-" + ShareText.group(s["pot_lost"]) if s["pot_lost"] > 0 else "")
		var text: String = S.REVIEW_GUESS % [i + 1, S.RANKS[s["from_rank"] - 1], S.RANKS[Deck.rank(s["card"]) - 1], S.REVIEW_SIDES[s["side"]], S.REVIEW_HIT if hit else S.REVIEW_MISS, amount]
		if s["life_up"]:
			text += "   " + S.CALL_LIFE
		_row(text, T.TEXT if hit else T.BAD)


func _row(text: String, color: Color, font_size: int = T.FS_BODY - 4) -> void:
	var l := Kit.label(text, font_size, T.W_BODY, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	body.add_child(l)
