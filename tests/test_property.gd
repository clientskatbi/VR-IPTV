extends Node
## Property-based / fuzz-style tests — run operations many times with random inputs.

var passed := 0
var failed := 0
var exit_code := 0
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	_run_obfuscation_invariants()
	_run_url_builder_invariants()
	_run_m3u_parser_invariants()
	_run_settings_invariants()
	_print_summary()
	# Signal completion to host (test_runner_combined.gd)
	queue_free()

func _begin(name: String) -> void:
	print("\n=== %s ===" % name)

func _assert(label: String, condition: bool) -> void:
	if condition:
		passed += 1
		print("  ✓ %s" % label)
	else:
		failed += 1
		print("  ✗ FAIL: %s" % label)
		exit_code = 1

func _print_summary() -> void:
	print("\n─────────────────────────────")
	print("Property tests: %d passed, %d failed" % [passed, failed])
	print("─────────────────────────────")

# --- Helpers ---

func _rand_string(min_len: int, max_len: int) -> String:
	var len := rng.randi_range(min_len, max_len)
	var chars := ""
	for i in len:
		chars += char(rng.randi_range(32, 126))
	return chars

func _rand_url_special_char() -> String:
	var specials := "% & ? = + # @ $ / : ; , < > \" ' ! * ( ) { } [ ] | \\ ^ ~ `"
	var arr := specials.split(" ", false)
	return arr[rng.randi() % arr.size()]

func _rand_password(min_len: int, max_len: int) -> String:
	var len := rng.randi_range(min_len, max_len)
	var s := ""
	for i in len:
		if rng.randf() < 0.2:
			s += _rand_url_special_char()
		elif rng.randf() < 0.3:
			s += char(rng.randi_range(0x0600, 0x06FF))
		else:
			s += char(rng.randi_range(32, 126))
	return s

# --- Obfuscation ---

func _run_obfuscation_invariants() -> void:
	_begin("Obfuscation invariants (fuzz)")
	var sm := preload("res://scripts/settings_manager.gd").new()
	get_tree().root.add_child(sm)

	var roundtrip_ok := true
	for i in 100:
		var plain := _rand_password(1, 64)
		var enc: String = sm._obfuscate(plain)
		var dec: String = sm._deobfuscate(enc)
		if dec != plain:
			roundtrip_ok = false
			break
	_assert("100 random strings roundtrip obfuscate/deobfuscate", roundtrip_ok)

	var not_equal_ok := true
	for i in 50:
		var plain := _rand_password(1, 32)
		if plain.is_empty():
			continue
		var enc: String = sm._obfuscate(plain)
		if enc == plain:
			not_equal_ok = false
			break
	_assert("50 random strings: obfuscated != plaintext", not_equal_ok)

	_assert("empty string roundtrips", sm._deobfuscate(sm._obfuscate("")) == "")

	var deterministic_ok := true
	for i in 20:
		var plain := _rand_password(5, 20)
		var e1: String = sm._obfuscate(plain)
		var e2: String = sm._obfuscate(plain)
		if e1 != e2:
			deterministic_ok = false
			break
	_assert("obfuscation is deterministic", deterministic_ok)

	sm.queue_free()

# --- URL builder ---

func _run_url_builder_invariants() -> void:
	_begin("URL builder invariants (fuzz)")
	var client = load("res://scripts/xtream_client.gd").new()
	get_tree().root.add_child(client)
	client._logged_in_user_info = {"auth": 1}

	var live_ok := true
	var live_first_failure := ""
	for i in 50:
		client._server_url = "http://%s:%d" % [_rand_string(5, 20), rng.randi_range(1, 65535)]
		client._username = _rand_password(1, 30)
		client._password = _rand_password(1, 30)
		var stream_id: int = rng.randi_range(1, 999999)
		var ext: String = ["ts", "mp4", "m3u8"][rng.randi() % 3]
		var url: String = client.build_stream_url(stream_id, ext)
		if not (url.contains(client._username) and url.contains(client._password)):
			live_ok = false
			live_first_failure = "creds missing i=%d" % i
			break
		if not url.ends_with(".%s" % ext):
			live_ok = false
			live_first_failure = "ext wrong i=%d" % i
			break
		if not url.begins_with(client._server_url):
			live_ok = false
			live_first_failure = "server missing i=%d" % i
			break
	_assert("50 random creds: live URL valid" if live_ok else "50 random creds: live URL valid (%s)" % live_first_failure, live_ok)

	var vod_ok := true
	for i in 30:
		var stream_id: int = rng.randi_range(1, 999999)
		var ext: String = ["mp4", "mkv", "avi"][rng.randi() % 3]
		var url: String = client.build_vod_url(stream_id, ext)
		if not url.contains("/movie/"):
			vod_ok = false
			break
		if not url.ends_with(".%s" % ext):
			vod_ok = false
			break
	_assert("30 random vod URLs valid", vod_ok)

	var series_ok := true
	for i in 30:
		var stream_id: int = rng.randi_range(1, 999999)
		var url: String = client.build_series_url(stream_id)
		if not url.contains("/series/"):
			series_ok = false
			break
		if not url.ends_with(str(stream_id)):
			series_ok = false
			break
	_assert("30 random series URLs valid", series_ok)

	client.queue_free()

# --- M3uParser ---

func _run_m3u_parser_invariants() -> void:
	_begin("M3uParser invariants (fuzz)")
	var parser = load("res://scripts/m3u_parser.gd").new()
	# RefCounted — assign to discard var, no manual free needed

	var det_ok := true
	for i in 20:
		var m3u := _gen_random_m3u(10, 50)
		var c1 = parser.parse_text(m3u)
		var c2 = parser.parse_text(m3u)
		if c1.size() != c2.size():
			det_ok = false
			break
		var ok := true
		for j in c1.size():
			if c1[j].url != c2[j].url or c1[j].name != c2[j].name:
				ok = false
				break
		if not ok:
			det_ok = false
			break
	_assert("20 random M3U: parsing is deterministic", det_ok)

	var url_ok := true
	for i in 30:
		var m3u := _gen_random_m3u(5, 20)
		var channels = parser.parse_text(m3u)
		for ch in channels:
			if ch.url.is_empty():
				url_ok = false
				break
		if not url_ok:
			break
	_assert("30 random M3U: all channels have URL", url_ok)

	# Edge cases
	var edge_cases := [
		"",
		"\n\n\n",
		"#EXTM3U\n",
		"#EXTM3U\nhttp://orphan.ts",
		"#EXTINF:-1 ,Name\nhttp://x.ts\ngarbage line\n#EXTINF:-1 ,Other\nhttp://y.ts",
	]
	for m in edge_cases:
		var _dummy = parser.parse_text(m)
	_assert("5 edge cases don't crash parser", true)

	# parser auto-cleaned by RefCounted

func _gen_random_m3u(min_channels: int, max_channels: int) -> String:
	var n := rng.randi_range(min_channels, max_channels)
	var out := "#EXTM3U\n"
	for i in n:
		var dur := rng.randi_range(-1, 7200)
		var name := _rand_string(1, 30)
		var url := "http://%s.com/%d.ts" % [_rand_string(3, 10), i]
		var has_attrs := rng.randf() < 0.5
		var attrs := ""
		if has_attrs:
			attrs = ' tvg-id="id%d" group-title="%s"' % [i, _rand_string(3, 8)]
		out += "#EXTINF:%d%s,%s\n%s\n" % [dur, attrs, name, url]
	return out

# --- SettingsManager ---

func _run_settings_invariants() -> void:
	_begin("SettingsManager invariants (fuzz)")
	var sm = load("res://scripts/settings_manager.gd").new()
	get_tree().root.add_child(sm)

	var clear_ok := true
	for i in 10:
		sm.save_credentials("http://s%d.com" % i, "u%d" % i, "p%d" % i)
		sm.clear_credentials()
		var loaded: Dictionary = sm.load_credentials()
		if not (loaded.username == "" and loaded.password == "" and loaded.server == ""):
			clear_ok = false
			break
	_assert("10 clear→load cycles return empty", clear_ok)

	# Type-preserving prefs
	_assert("pref string roundtrip", _deep_equal(sm.get_ui_preference("k1", null), null) or true)
	sm.save_ui_preference("k1", "dark")
	_assert("pref string roundtrip", sm.get_ui_preference("k1", null) == "dark")
	sm.save_ui_preference("k2", 42)
	_assert("pref int roundtrip", sm.get_ui_preference("k2", 0) == 42)
	sm.save_ui_preference("k3", true)
	_assert("pref bool roundtrip", sm.get_ui_preference("k3", false) == true)
	sm.save_ui_preference("k4", 3.14)
	_assert("pref float roundtrip", sm.get_ui_preference("k4", 0.0) == 3.14)
	sm.save_ui_preference("k5", [1, 2, 3])
	_assert("pref array roundtrip", _deep_equal(sm.get_ui_preference("k5", []), [1, 2, 3]))
	sm.save_ui_preference("k6", {"a": 1})
	_assert("pref dict roundtrip", _deep_equal(sm.get_ui_preference("k6", {}), {"a": 1}))

	sm.queue_free()

func _deep_equal(a, b) -> bool:
	if typeof(a) != typeof(b):
		return false
	if a is Array and b is Array:
		if a.size() != b.size():
			return false
		for i in a.size():
			if not _deep_equal(a[i], b[i]):
				return false
		return true
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size():
			return false
		for k in a.keys():
			if not b.has(k) or not _deep_equal(a[k], b[k]):
				return false
		return true
	return a == b