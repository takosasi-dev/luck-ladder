# BGM の再生と切り替え(FR-32〜FR-34・§9.13)。bgm_title・bgm_play・bgm_last の 3 曲を 0.8 秒で入れ替える。
# 最初の入力を受けるまでは鳴らさない。ファイルが読めない曲は鳴らさずに続ける(E-36)。
extends Node

const Sfx := preload("res://audio/sfx.gd")

const NAMES := ["bgm_title", "bgm_play", "bgm_last"]
const OFFSET_DB := -6.0  # 効果音が埋もれないよう、BGM は 6 dB 下げる
const FADE_SEC := 0.8
# 長さとテンポが同じ 2 曲は、再生位置を引き継ぐ
const SYNCED := ["bgm_play", "bgm_last"]

var step := 5
var current := ""
var unlocked := false
var _players := {}
var _fade := {}
var _tween: Tween


func _ready() -> void:
	for n in NAMES:
		var path := "res://assets/bgm/%s.ogg" % n
		if not ResourceLoader.exists(path):
			continue
		var stream = load(path)
		if stream == null:
			continue
		stream.loop = true
		var p := AudioStreamPlayer.new()
		p.stream = stream
		add_child(p)
		_players[n] = p
		_fade[n] = 0.0
	_apply()


func set_volume(volume_step: int) -> void:
	step = clampi(volume_step, 0, 10)
	_apply()


func _apply() -> void:
	for n in _players:
		var db: float = Sfx.step_to_db(step) + OFFSET_DB + linear_to_db(maxf(_fade[n], 0.0001))
		_players[n].volume_db = maxf(db, Sfx.MUTE_DB)


func _set_fade(v: float, n: String) -> void:
	_fade[n] = v
	_apply()


# 最初のクリック・タップ・キー入力の後に呼ぶ(FR-1)。
func unlock() -> void:
	if unlocked:
		return
	unlocked = true
	var want := current
	current = ""
	play(want)


# 曲を切り替える。まだ入力を受けていなければ、曲名だけ覚えておく。
func play(track: String) -> void:
	if track == current:
		return
	var prev := current
	current = track
	if not unlocked:
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	# 動かす物が 1 つも無い Tween はエラーになるので、空の待ちを 1 つ入れておく
	_tween.tween_interval(0.01)
	for n in _players:
		var p: AudioStreamPlayer = _players[n]
		if n == track:
			var from := 0.0
			if prev in SYNCED and track in SYNCED and _players.has(prev) and _players[prev].playing:
				from = _players[prev].get_playback_position()
			if not p.playing:
				p.play(from)
			_tween.tween_method(_set_fade.bind(n), _fade[n], 1.0, FADE_SEC)
		elif p.playing:
			_tween.tween_method(_set_fade.bind(n), _fade[n], 0.0, FADE_SEC)
			_tween.tween_callback(p.stop).set_delay(FADE_SEC)


# タブが裏に回ったら止め、戻ったら続きから鳴らす(FR-34)。
func set_paused(paused: bool) -> void:
	for p in _players.values():
		p.stream_paused = paused
