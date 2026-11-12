# 効果音の再生(FR-28・§9.13)。assets/sfx/*.wav の 12 種を読み、音量の段(0〜10)で鳴らす。
# 段 0 は鳴らさない。ファイルが読めないときは音なしで続ける(E-16)。音量の段 → dB の変換もここに置く。
extends Node

const NAMES := ["tap", "flip", "hit_1", "hit_2", "hit_3", "miss", "same", "bank", "life_up", "toast", "clear", "gameover"]
const MUTE_DB := -80.0

var step := 7
var _players := {}


# 段 1〜10 が -27 dB〜0 dB(3 dB きざみ)。段 0 は無音。
static func step_to_db(volume_step: int) -> float:
	if volume_step <= 0:
		return MUTE_DB
	return -27.0 + 3.0 * (mini(volume_step, 10) - 1)


func _ready() -> void:
	for n in NAMES:
		var path := "res://assets/sfx/%s.wav" % n
		if not ResourceLoader.exists(path):
			continue
		var stream = load(path)
		if stream == null:
			continue
		var p := AudioStreamPlayer.new()
		p.stream = stream
		add_child(p)
		_players[n] = p
	set_volume(step)


func set_volume(volume_step: int) -> void:
	step = clampi(volume_step, 0, 10)
	for p in _players.values():
		p.volume_db = step_to_db(step)


func play(sound_name: String) -> void:
	if step > 0 and _players.has(sound_name):
		_players[sound_name].play()
