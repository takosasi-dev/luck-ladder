# 音量のスライダー 1 行(FR-21・FR-33)。0〜10 の 11 段で、名前・スライダー・今の段の数字を横に並べる。
# 行の高さを 96 にして、つまみの当たりを大きく取る(INV-11)。
extends HBoxContainer

signal changed(step: int)

const T := preload("res://ui/theme/tokens.gd")
const Kit := preload("res://ui/kit.gd")

var _value: Label


func setup(title: String, step: int) -> void:
	add_theme_constant_override("separation", 16)
	var name_label := Kit.label(title, T.FS_BODY, T.W_BODY)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_label.custom_minimum_size = Vector2(220, 96)
	add_child(name_label)
	var s := HSlider.new()
	s.min_value = 0
	s.max_value = 10
	s.step = 1
	s.value = step
	s.focus_mode = Control.FOCUS_NONE
	s.custom_minimum_size = Vector2(200, 96)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var track := Kit.box(Color(T.BRASS, 0.22), 5)
	track.content_margin_top = 5
	track.content_margin_bottom = 5
	var fill := Kit.box(T.BRASS, 5)
	fill.content_margin_top = 5
	fill.content_margin_bottom = 5
	s.add_theme_stylebox_override("slider", track)
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill)
	for icon in ["grabber", "grabber_highlight", "grabber_disabled"]:
		s.add_theme_icon_override(icon, Kit.disc(44, T.BRASS_HI))
	add_child(s)
	_value = Kit.num_label(str(step), T.FS_BODY, T.BRASS_HI)
	_value.custom_minimum_size = Vector2(56, 96)
	add_child(_value)
	s.value_changed.connect(func(v: float):
		_value.text = str(int(v))
		changed.emit(int(v)))
