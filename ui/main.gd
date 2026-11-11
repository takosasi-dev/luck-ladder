# 窓の縦横比を見て、基準の座標を横長 1280×720 と縦長 720×1280 で付け替える(D-12・FR-22)。
# 付け替えたら、表示中の画面に relayout(横長か) を伝える。
extends Control

const Title := preload("res://ui/screens/title.gd")

const LANDSCAPE := Vector2i(1280, 720)
const PORTRAIT := Vector2i(720, 1280)

var screen: Control
var landscape := true


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := ColorRect.new()
	bg.color = Color("#0E1F1C")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	screen = Title.new()
	add_child(screen)
	# size_changed の中で content_scale_size を変えると、窓の側の計算が古い縦横比で上書きするので、後回しにする
	get_tree().root.size_changed.connect(_on_window_resized, CONNECT_DEFERRED)
	_on_window_resized()


func _on_window_resized() -> void:
	var w := get_window()
	var s := w.size
	landscape = s.x >= s.y
	w.content_scale_size = LANDSCAPE if landscape else PORTRAIT
	screen.relayout(landscape, s)
