# 招待コードと返事コード(§9.16)。接続情報(SDP)から指紋・合言葉・候補だけを取り出して 2 進数に詰め、base64url の文字にする。
# 並びと、復元に使う文(テンプレート)は案。§8.4 の実験の後に確定する。
# 相手から来た文字はそのまま使わず、型ごとに検査した値から書き出す(INV-16)。
extends RefCounted

const VERSION := 1
const KIND_INVITE := 1
const KIND_ANSWER := 2
# 旗のビット 0: 合言葉を省いた(受け取った側が指紋から作る)
const FLAG_DERIVED := 1
const CAND_HOST := 1
const CAND_SRFLX := 2
# 実験用の足し(§9.16 の案には無い。§8.4 の結果を見て、入れるかを仲野さんと決める):
# ブラウザが自分の機械の IP の代わりに出す、その場かぎりの名前(<UUID>.local)。同じ Wi-Fi の中や同じ PC でつなぐのに要る
const CAND_MDNS := 3
const MDNS_SIZE := 16
# 実験用の足し、その 2(同じく §9.16 の案には無い): IPv6 のアドレス(16 バイト)。外向きの IPv4 を持たない回線のため
const CAND_V6 := 4
# 16 バイトの住所を持つ種類と、項目の中での名前
const LONG_KEYS := {CAND_MDNS: "name", CAND_V6: "ip6"}
const HEX_CHARS := "0123456789abcdef"
const CANDS_MAX := 3
const FP_SIZE := 32
# 取り出し: ?j= も ?a= も無いとき、base64url の字がこの数以上続く最初の並びを使う
const CODE_MIN := 40
const ICE_CHARS := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
const URL_CHARS := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
const CAND_NAMES := {CAND_HOST: "host", CAND_SRFLX: "srflx", CAND_MDNS: "host", CAND_V6: "srflx"}
# 復元する候補の優先度(Chrome が付ける値にならった。大きい方を先に試す)
const CAND_PRIORITY := {CAND_HOST: 2122260223, CAND_SRFLX: 1686052607, CAND_MDNS: 2122260223, CAND_V6: 1686052607}

# 項目(items)の形:
#   kind      KIND_INVITE か KIND_ANSWER
#   fp        暗号の指紋(SHA-256、PackedByteArray の 32 バイト)
#   derived   合言葉を省いたか。真なら ufrag と pwd は空の文字
#   ufrag pwd 合言葉(ICE の字だけ)
#   cands     候補 1〜3 個(返事は 0 個でもよい)。[{type: CAND_HOST か CAND_SRFLX, ip: [4 つの数], port}]。CAND_MDNS は {type, name: 16 バイト, port}、
#             CAND_V6 は {type, ip6: 16 バイト, port}
#   reply_to  返事のときだけ、対応する招待の検査値。招待では 0


# CRC-16/CCITT-FALSE(初めの値 0xFFFF、多項式 0x1021)。
static func crc16(bytes: PackedByteArray) -> int:
	var crc := 0xFFFF
	for b in bytes:
		crc ^= b << 8
		for i in 8:
			crc = ((crc << 1) ^ 0x1021 if crc & 0x8000 else crc << 1) & 0xFFFF
	return crc


static func _only(text: String, allowed: String) -> bool:
	for i in text.length():
		if not text[i] in allowed:
			return false
	return true


# 合言葉として書き出してよい文字か(1〜255 文字、ICE の字だけ。改行や空白は通らない)。
static func is_ice_text(v) -> bool:
	return v is String and v.length() >= 1 and v.length() <= 255 and _only(v, ICE_CHARS)


static func _valid_cand(c) -> bool:
	if not c is Dictionary or not c.get("type") in CAND_NAMES:
		return false
	var port = c.get("port")
	if not port is int or port < 1 or port > 65535:
		return false
	if c["type"] in LONG_KEYS:
		var v = c.get(LONG_KEYS[c["type"]])
		# IPv6 は、外とつながる範囲(2000::/3)の物だけ。自分の機械の中やリンクの中だけの住所は通さない
		return c.size() == 3 and v is PackedByteArray and v.size() == MDNS_SIZE and (c["type"] == CAND_MDNS or (v[0] & 0xE0) == 0x20)
	if c.size() != 3 or not c.get("ip") is Array or c["ip"].size() != 4:
		return false
	for n in c["ip"]:
		if not n is int or n < 0 or n > 255:
			return false
	return c["ip"] != [0, 0, 0, 0] and c["ip"] != [255, 255, 255, 255]


static func is_valid(items) -> bool:
	if not items is Dictionary or not items.get("kind") in [KIND_INVITE, KIND_ANSWER]:
		return false
	if not items.get("fp") is PackedByteArray or items["fp"].size() != FP_SIZE or not items.get("derived") is bool:
		return false
	if items["derived"]:
		if items.get("ufrag") != "" or items.get("pwd") != "":
			return false
	elif not is_ice_text(items.get("ufrag")) or not is_ice_text(items.get("pwd")):
		return false
	var cands = items.get("cands")
	# 実験用の足し、その 3: 返事だけは候補 0 個でもよい(ゲストが先につながっていれば、ホストは届いた通信から相手を知る)
	if not cands is Array or cands.size() < (1 if items["kind"] == KIND_INVITE else 0) or cands.size() > CANDS_MAX:
		return false
	for c in cands:
		if not _valid_cand(c):
			return false
	var reply = items.get("reply_to")
	return reply is int and reply >= 0 and reply <= 0xFFFF and (items["kind"] == KIND_ANSWER or reply == 0)


# 検査値を足して base64url の文字にする(テストは、形の崩れたコードを作るのにも使う)。
static func pack(body: PackedByteArray) -> String:
	var bytes := body.duplicate()
	var crc := crc16(body)
	bytes.append(crc >> 8)
	bytes.append(crc & 0xFF)
	return Marshalls.raw_to_base64(bytes).replace("+", "-").replace("/", "_").rstrip("=")


# 項目 → コード。項目が検査を通らなければ空の文字。
static func encode(items) -> String:
	if not is_valid(items):
		return ""
	var b := PackedByteArray([(VERSION << 4) | items["kind"], FLAG_DERIVED if items["derived"] else 0])
	b.append_array(items["fp"])
	if not items["derived"]:
		for text in [items["ufrag"], items["pwd"]]:
			b.append(text.length())
			b.append_array(text.to_ascii_buffer())
	b.append(items["cands"].size())
	for c in items["cands"]:
		b.append(c["type"])
		b.append_array(c[LONG_KEYS[c["type"]]] if c["type"] in LONG_KEYS else PackedByteArray(c["ip"]))
		b.append(c["port"] >> 8)
		b.append(c["port"] & 0xFF)
	if items["kind"] == KIND_ANSWER:
		b.append(items["reply_to"] >> 8)
		b.append(items["reply_to"] & 0xFF)
	return pack(b)


static func _unpack(code: String) -> PackedByteArray:
	if code == "" or code.length() % 4 == 1 or not _only(code, URL_CHARS):
		return PackedByteArray()
	var bytes := Marshalls.base64_to_raw(code.replace("-", "+").replace("_", "/") + "=".repeat((4 - code.length() % 4) % 4))
	# 余りのビットが 0 でない書き方を通さない(同じ中身のコードは 1 つだけにする)
	if Marshalls.raw_to_base64(bytes).replace("+", "-").replace("/", "_").rstrip("=") != code:
		return PackedByteArray()
	return bytes


# コード → {error, items, check}。error は ""(通った)/ "bad"(読めない)/ "version"(版が違う)/ "kind"(招待と返事を取り違えた)。
# check は、このコードの検査値(返事が「どの招待への返事か」を示すのに使う)。
static func decode(code: String, want_kind: int) -> Dictionary:
	var bad := {"error": "bad", "items": {}, "check": 0}
	var bytes := _unpack(code)
	var size := bytes.size()
	if size < 2 + FP_SIZE + 1 + 2:
		return bad
	var kind := bytes[0] & 0x0F
	var derived := bytes[1] & FLAG_DERIVED != 0
	var pos := 2 + FP_SIZE
	var texts := ["", ""]
	if not derived:
		for i in 2:
			if pos >= size or pos + 1 + bytes[pos] > size:
				return bad
			texts[i] = bytes.slice(pos + 1, pos + 1 + bytes[pos]).get_string_from_ascii()
			pos += 1 + bytes[pos]
	if pos >= size:
		return bad
	var count := bytes[pos]
	pos += 1
	var cands := []
	for i in mini(count, CANDS_MAX):
		# 候補の長さは種類で決まる: 種類 1 バイト + 住所(IPv4 は 4 バイト、名前と IPv6 は 16 バイト)+ ポート 2 バイト
		var key: String = LONG_KEYS.get(bytes[pos], "") if pos < size else ""
		var end := pos + 1 + (MDNS_SIZE if key != "" else 4)
		if end + 2 > size:
			return bad
		var c := {"type": bytes[pos], "port": bytes[end] << 8 | bytes[end + 1]}
		if key != "":
			c[key] = bytes.slice(pos + 1, end)
		else:
			c["ip"] = Array(bytes.slice(pos + 1, end))
		cands.append(c)
		pos = end + 2
	var reply := 0
	if kind == KIND_ANSWER:
		if pos + 2 > size:
			return bad
		reply = bytes[pos] << 8 | bytes[pos + 1]
		pos += 2
	# 長さが項目の並びと合う → 検査値 → 版 → 種類 → 中身、の順に見る
	if pos + 2 != size or count > CANDS_MAX:
		return bad
	var check := bytes[pos] << 8 | bytes[pos + 1]
	if crc16(bytes.slice(0, pos)) != check:
		return bad
	if bytes[0] >> 4 != VERSION:
		return {"error": "version", "items": {}, "check": 0}
	if kind != want_kind and kind in [KIND_INVITE, KIND_ANSWER]:
		return {"error": "kind", "items": {}, "check": 0}
	var items := {"kind": kind, "fp": bytes.slice(2, 2 + FP_SIZE), "derived": derived, "ufrag": texts[0], "pwd": texts[1], "cands": cands, "reply_to": reply}
	# 詰め直して同じ文字にならない物(知らない旗、合言葉の中の 0 のバイトなど)は通さない
	if not is_valid(items) or encode(items) != code:
		return bad
	return {"error": "", "items": items, "check": check}


# FR-38: 貼られた文字からコードを取り出す。?j= か ?a= の後ろを先に探し、無ければ base64url の字が長く続く最初の並び。
static func extract(text: String) -> String:
	var m := RegEx.create_from_string("[?&][ja]=([A-Za-z0-9_-]+)").search(text)
	if m:
		return m.get_string(1)
	m = RegEx.create_from_string("[A-Za-z0-9_-]{%d,}" % CODE_MIN).search(text)
	return m.get_string() if m else ""


# ---- 接続情報(SDP)との行き来 ----

static func ip_text(ip: Array) -> String:
	return "%d.%d.%d.%d" % ip


# IPv6 の文字(:: の省略つき)→ 16 バイト。読めなければ空。
static func parse_ip6(text: String) -> PackedByteArray:
	var halves := text.to_lower().split("::")
	var groups := []
	for half in halves:
		groups.append([] if half == "" else Array(half.split(":")))
	# :: は 1 回まで。:: が無ければ 8 組、あれば 7 組以下
	if halves.size() > 2 or (halves.size() == 1 and groups[0].size() != 8) or (halves.size() == 2 and groups[0].size() + groups[1].size() > 7):
		return PackedByteArray()
	var out := PackedByteArray()
	for i in halves.size():
		while i == 1 and out.size() < MDNS_SIZE - groups[1].size() * 2:
			out.append(0)
		for g in groups[i]:
			if g.length() < 1 or g.length() > 4 or not _only(g, HEX_CHARS):
				return PackedByteArray()
			out.append(g.hex_to_int() >> 8)
			out.append(g.hex_to_int() & 0xFF)
	return out


static func ip6_text(ip6: PackedByteArray) -> String:
	var parts := PackedStringArray()
	for i in 8:
		parts.append("%x" % (ip6[i * 2] << 8 | ip6[i * 2 + 1]))
	return ":".join(parts)


# 候補の 1 行(candidate:…)→ {type, ip, port}。UDP で、自分の機械か外向きの物だけ(IPv4、.local の名前、IPv6)。ほかは空の辞書。
static func parse_candidate(line: String) -> Dictionary:
	var p := line.strip_edges().trim_prefix("a=").split(" ", false)
	if p.size() < 8 or not p[0].begins_with("candidate:") or p[1] != "1" or p[2].to_lower() != "udp" or p[6] != "typ":
		return {}
	if not p[7] in ["host", "srflx"] or not p[5].is_valid_int():
		return {}
	var c := {"type": CAND_SRFLX if p[7] == "srflx" else CAND_HOST, "port": p[5].to_int()}
	var hex := p[4].to_lower().trim_suffix(".local").replace("-", "")
	if p[4].to_lower().ends_with(".local") and p[7] == "host" and p[4].length() == 42 and hex.length() == MDNS_SIZE * 2 and hex.is_valid_hex_number():
		c["type"] = CAND_MDNS
		c["name"] = hex.hex_decode()
		return c if _valid_cand(c) else {}
	if p[4].contains(":"):
		c["type"] = CAND_V6
		c["ip6"] = parse_ip6(p[4])
		return c if _valid_cand(c) else {}
	var parts := p[4].split(".")
	if parts.size() != 4:
		return {}
	var ip := []
	for s in parts:
		if not s.is_valid_int() or s.length() > 3:
			return {}
		ip.append(s.to_int())
	c["ip"] = ip
	return c if _valid_cand(c) else {}


# 候補の行の集まりから、載せる候補を選ぶ: 外向きを先に、重なりを除いて CANDS_MAX 個まで。
# with_mdns が真のときだけ .local の名前の候補を、with_v6 が真のときだけ IPv6 の候補を載せる(どちらも実験用の足し)。
static func pick_candidates(lines: Array, with_mdns: bool = false, with_v6: bool = false) -> Array:
	var out := []
	for type in [CAND_SRFLX, CAND_V6, CAND_MDNS, CAND_HOST]:
		for line in lines:
			var c := parse_candidate(line)
			var wanted: bool = (with_mdns or type != CAND_MDNS) and (with_v6 or type != CAND_V6)
			if not c.is_empty() and c["type"] == type and wanted and not c in out and out.size() < CANDS_MAX:
				out.append(c)
	return out


# 16 バイトの名前 → ブラウザが出した形(8-4-4-4-12 の 16 進 + .local)。
static func mdns_text(mdns_name: PackedByteArray) -> String:
	var h := mdns_name.hex_encode()
	return "%s-%s-%s-%s-%s.local" % [h.substr(0, 8), h.substr(8, 4), h.substr(12, 4), h.substr(16, 4), h.substr(20)]


# 指紋から作る合言葉(前提 22 の実験用の案): [ufrag 4 文字, pwd 24 文字]。
static func derive(fp: PackedByteArray) -> Array:
	return [Marshalls.raw_to_base64(fp.slice(0, 3)), Marshalls.raw_to_base64(fp.slice(3, 21))]


static func _sdp_value(sdp: String, key: String) -> String:
	for line in sdp.split("\n"):
		if line.begins_with(key):
			return line.substr(key.length()).strip_edges()
	return ""


# 自分の接続情報と候補の行から、項目(kind と reply_to を除く)を取り出す。足りなければ空の辞書。
static func from_sdp(sdp: String, cand_lines: Array, derived: bool, with_mdns: bool = false, with_v6: bool = false) -> Dictionary:
	var hex := _sdp_value(sdp, "a=fingerprint:sha-256 ").replace(":", "")
	if hex.length() != FP_SIZE * 2 or not hex.is_valid_hex_number():
		return {}
	var items := {"fp": hex.hex_decode(), "derived": derived, "cands": pick_candidates(cand_lines, with_mdns, with_v6)}
	items["ufrag"] = "" if derived else _sdp_value(sdp, "a=ice-ufrag:")
	items["pwd"] = "" if derived else _sdp_value(sdp, "a=ice-pwd:")
	return items


# 自分の接続情報の合言葉を、指紋から作った物に書き換える(前提 22 の実験)。
static func munge(sdp: String) -> String:
	var hex := _sdp_value(sdp, "a=fingerprint:sha-256 ").replace(":", "")
	if hex.length() != FP_SIZE * 2 or not hex.is_valid_hex_number():
		return sdp
	var made := derive(hex.hex_decode())
	var out := PackedStringArray()
	for line in sdp.split("\n"):
		var end := "\r" if line.ends_with("\r") else ""
		if line.begins_with("a=ice-ufrag:"):
			line = "a=ice-ufrag:" + made[0] + end
		elif line.begins_with("a=ice-pwd:"):
			line = "a=ice-pwd:" + made[1] + end
		out.append(line)
	return "\n".join(out)


# 項目 → 相手の接続情報の文(候補は入れない。add_ice_candidate で別に渡す)。検査を通らない項目なら空の文字。
# 招待は offer、返事は answer として書く。
static func to_sdp(items) -> String:
	if not is_valid(items):
		return ""
	var creds := derive(items["fp"]) if items["derived"] else [items["ufrag"], items["pwd"]]
	var hex: String = items["fp"].hex_encode().to_upper()
	var pairs := PackedStringArray()
	for i in FP_SIZE:
		pairs.append(hex.substr(i * 2, 2))
	return "\r\n".join(PackedStringArray([
		"v=0",
		"o=- 1 2 IN IP4 " + ip_text([127, 0, 0, 1]),
		"s=-",
		"t=0 0",
		"a=group:BUNDLE 0",
		"m=application 9 UDP/DTLS/SCTP webrtc-datachannel",
		"c=IN IP4 " + ip_text([0, 0, 0, 0]),
		"a=ice-ufrag:" + creds[0],
		"a=ice-pwd:" + creds[1],
		"a=ice-options:trickle",
		"a=fingerprint:sha-256 " + ":".join(pairs),
		"a=setup:" + ("actpass" if items["kind"] == KIND_INVITE else "active"),
		"a=mid:0",
		"a=sctp-port:5000",
		"a=max-message-size:262144",
		"",
	]))


# 項目の候補 → add_ice_candidate に渡す行。
static func candidate_lines(items) -> PackedStringArray:
	var out := PackedStringArray()
	if not is_valid(items):
		return out
	for i in items["cands"].size():
		var c: Dictionary = items["cands"][i]
		var address := mdns_text(c["name"]) if c["type"] == CAND_MDNS else ip6_text(c["ip6"]) if c["type"] == CAND_V6 else ip_text(c["ip"])
		out.append("candidate:%d 1 udp %d %s %d typ %s" % [i + 1, CAND_PRIORITY[c["type"]], address, c["port"], CAND_NAMES[c["type"]]])
	return out
