# 挑戦状のコード(追補 2 §9.1)。種・操作の列・名前を詰めて base64url にする。得点は入れず、読む側が RunState.replay で計算する(D-B3)。
# 外から来た文字は、長さ・字の種類・版・検査値・中身(流し直してランが終わっているか)の全部を確かめてから使う(INV-16・FR-C3)。
extends RefCounted

const Invite := preload("res://core/invite_codec.gd")
const RunState := preload("res://core/run_state.gd")
const SaveCodec := preload("res://core/save_codec.gd")

const VERSION := 1
const CODE_MAX := 400
const ACTIONS_MAX := 120
const NAME_BYTES_MAX := 32


static func _seed_ok(t: String) -> bool:
	return RegEx.create_from_string("^LLR:[0-9]{1,12}:[0-9]{1,20}$").search(t) != null


static func _actions_ok(t: String) -> bool:
	return t.length() <= ACTIONS_MAX and RegEx.create_from_string("^[HLSB]+$").search(t) != null


# 形が通らなければ空の文字。
static func encode(seed_text: String, actions: String, player_name: String) -> String:
	if not _seed_ok(seed_text) or not _actions_ok(actions) or not SaveCodec.is_valid_name(player_name):
		return ""
	var nb := player_name.to_utf8_buffer()
	if nb.size() > NAME_BYTES_MAX:
		return ""
	var b := PackedByteArray([VERSION, seed_text.length()])
	b.append_array(seed_text.to_ascii_buffer())
	b.append(actions.length())
	b.append_array(actions.to_ascii_buffer())
	b.append(nb.size())
	b.append_array(nb)
	return Invite.pack(b)


# コード → {error, seed_text, actions, name, state}。error は ""(通った)/ "bad"(読めない)/ "version"(版が違う)。
static func decode(code: String) -> Dictionary:
	var bad := {"error": "bad", "seed_text": "", "actions": "", "name": "", "state": null}
	if code.length() > CODE_MAX:
		return bad
	var bytes := Invite._unpack(code)
	var size := bytes.size()
	var pos := 1
	var parts := []
	for i in 3:
		if pos >= size or pos + 1 + bytes[pos] > size:
			return bad
		parts.append(bytes.slice(pos + 1, pos + 1 + bytes[pos]))
		pos += 1 + bytes[pos]
	if pos + 2 != size or Invite.crc16(bytes.slice(0, pos)) != (bytes[pos] << 8 | bytes[pos + 1]):
		return bad
	if bytes[0] != VERSION:
		return {"error": "version", "seed_text": "", "actions": "", "name": "", "state": null}
	var seed_text: String = parts[0].get_string_from_ascii()
	var actions: String = parts[1].get_string_from_ascii()
	var player_name: String = parts[2].get_string_from_utf8()
	# 詰め直して同じ文字にならない物(ASCII でない字、壊れた UTF-8、検査に落ちる中身)は通さない
	if encode(seed_text, actions, player_name) != code:
		return bad
	var r: Dictionary = RunState.replay(seed_text, actions)
	if not r["ok"] or r["state"].ended == "":
		return bad
	return {"error": "", "seed_text": seed_text, "actions": actions, "name": player_name, "state": r["state"]}
