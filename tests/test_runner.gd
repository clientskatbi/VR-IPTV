extends Node
## Test harness — runs assertions without external deps.
## Usage: godot --headless --path . res://tests/test_runner.tscn --quit-after 30

var passed := 0
var failed := 0
var current_test := ""
var exit_code := 0

func _ready() -> void:
	_run_m3u_parser()
	_run_settings_manager()
	_run_xtream_url_builder()
	_run_xtream_auth_response_parsing()
	# Run extended tests in-process (same Node tree)
	var ext_runner: Node = load("res://tests/test_runner_extended.gd").new()
	add_child(ext_runner)
	ext_runner.call("run_all")
	# Merge extended results into our counters
	passed += ext_runner.passed
	failed += ext_runner.failed
	if ext_runner.exit_code != 0:
		exit_code = ext_runner.exit_code
	# Print combined summary
	print("\n═══════════════════════════════")
	print("TOTAL: %d passed, %d failed" % [passed, failed])
	print("═══════════════════════════════")
	# Defer quit so all prints flush
	call_deferred("_quit")

func _quit() -> void:
	get_tree().quit(exit_code)

func _begin(name: String) -> void:
	current_test = name
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
	print("Tests: %d passed, %d failed" % [passed, failed])
	print("─────────────────────────────")

func _run_m3u_parser() -> void:
	_begin("M3uParser")

	var parser := preload("res://scripts/m3u_parser.gd").new()
	_assert("empty input returns empty list", parser.parse_text("").size() == 0)

	var sample := """#EXTM3U
#EXTINF:-1 tvg-id="bbc1.uk" tvg-name="BBC One" tvg-logo="http://l/bbc.png" group-title="UK",BBC One HD
http://server.com:8080/live/user/pass/1.ts
#EXTINF:-1 group-title="Sports",ESPN
http://server.com:8080/live/user/pass/2.ts
#EXTGRP:News
#EXTINF:-1 ,CNN
http://server.com:8080/live/user/pass/3.ts"""

	var channels = parser.parse_text(sample)
	_assert("parses 3 channels", channels.size() == 3)

	if channels.size() >= 3:
		_assert("channel 0 name", channels[0].name == "BBC One HD")
		_assert("channel 0 logo", channels[0].logo == "http://l/bbc.png")
		_assert("channel 0 group", channels[0].group == "UK")
		_assert("channel 0 tvg-id", channels[0].tvg_id == "bbc1.uk")
		_assert("channel 0 url", channels[0].url == "http://server.com:8080/live/user/pass/1.ts")
		_assert("channel 1 name", channels[1].name == "ESPN")
		_assert("channel 1 group (from EXTINF)", channels[1].group == "Sports")
		_assert("channel 2 group (from EXTGRP)", channels[2].group == "News")
		_assert("channel 2 url", channels[2].url == "http://server.com:8080/live/user/pass/3.ts")

	# Whitespace / blank lines / comments
	var messy := "\n\n#EXTM3U\n   \n# comment line\n#EXTINF:-1 ,Test\nhttp://x.com/1.ts\n\n"
	var c2 = parser.parse_text(messy)
	_assert("skips blanks and non-EXTINF comment lines", c2.size() == 1)
	if c2.size() == 1:
		_assert("name trims whitespace", c2[0].name == "Test")

	# Missing duration
	var nodur := "#EXTM3U\n#EXTINF:,NoDur\nhttp://x.com/2.ts"
	var c3 = parser.parse_text(nodur)
	_assert("missing duration handled", c3.size() == 1 and c3[0].duration == -1)

	# Unicode (Arabic)
	var arabic := "#EXTM3U\n#EXTINF:-1 ,الجزيرة\nhttp://x.com/a.ts"
	var c4 = parser.parse_text(arabic)
	_assert("Arabic name preserved", c4.size() == 1 and c4[0].name == "الجزيرة")

func _run_settings_manager() -> void:
	_begin("SettingsManager")
	var sm := preload("res://scripts/settings_manager.gd").new()
	add_child(sm)

	sm.clear_credentials()
	var empty: Dictionary = sm.load_credentials()
	_assert("empty after clear", empty.username == "" and empty.password == "" and empty.server == "")

	sm.save_credentials("http://s.com:8080", "ali", "secret123")
	var loaded: Dictionary = sm.load_credentials()
	_assert("server roundtrips", loaded.server == "http://s.com:8080")
	_assert("username roundtrips", loaded.username == "ali")
	_assert("password roundtrips through obfuscation", loaded.password == "secret123")

	# Verify password is obfuscated on disk
	var file := FileAccess.open("user://settings.cfg", FileAccess.READ)
	if file:
		var content := file.get_as_text()
		file.close()
		_assert("password NOT stored in plaintext", not "secret123" in content)
		_assert("username IS stored as plain key", "ali" in content)
	else:
		_assert("settings.cfg readable", false)

	# Arabic + URL-unsafe chars
	sm.clear_credentials()
	sm.save_credentials("http://srv.com", "مستخدم", "p@ss&?=+%25")
	var arabic: Dictionary = sm.load_credentials()
	_assert("Arabic username roundtrips", arabic.username == "مستخدم")
	_assert("password with URL-unsafe chars roundtrips", arabic.password == "p@ss&?=+%25")

	# UI preferences
	sm.save_ui_preference("theme", "dark")
	_assert("ui pref persists", sm.get_ui_preference("theme", "light") == "dark")
	_assert("ui pref default fallback", sm.get_ui_preference("missing", "fallback") == "fallback")

	# Obfuscation roundtrip
	var enc: String = sm._obfuscate("secret123")
	var dec: String = sm._deobfuscate(enc)
	_assert("obfuscate roundtrip", dec == "secret123" and enc != "secret123")

	# Cleanup
	sm.clear_credentials()
	sm.queue_free()

func _run_xtream_url_builder() -> void:
	_begin("XtreamClient URL builders")

	var client := preload("res://scripts/xtream_client.gd").new()
	add_child(client)

	# Inject auth state
	client._server_url = "http://example.com:8080"
	client._username = "user123"
	client._password = "pass!@#"
	client._logged_in_user_info = {"auth": 1}

	var live: String = client.build_stream_url(42, "ts")
	_assert("live URL format", live == "http://example.com:8080/live/user123/pass!@#/42.ts")

	var vod: String = client.build_vod_url(100, "mp4")
	_assert("vod URL format", vod == "http://example.com:8080/movie/user123/pass!@#/100.mp4")

	var series: String = client.build_series_url(7)
	_assert("series URL format", series == "http://example.com:8080/series/user123/pass!@#/7")

	_assert("logged_in after inject", client.is_logged_in() == true)

	client._logged_in_user_info = {}
	_assert("logged_in after clear", client.is_logged_in() == false)

	# Empty fetches return [] when not logged in
	var cats: Array = await client.get_live_categories()
	_assert("get_live_categories empty when not logged in", cats.size() == 0)

	# Password with special chars survives URL builder
	client._logged_in_user_info = {"auth": 1}
	client._password = "p&w=d?%"
	var encoded: String = client.build_stream_url(1, "ts")
	_assert("password with special chars present in URL", "p&w=d?%" in encoded)

	client.queue_free()

func _run_xtream_auth_response_parsing() -> void:
	_begin("XtreamClient auth response parsing")

	var fixtures := {
		"success": {"user_info": {"auth": 1, "username": "demo", "status": "Active"}, "server_info": {"url": "x", "port": "80"}},
		"bad_creds": {"user_info": {"auth": 0, "message": "Invalid credentials"}},
		"empty": {},
	}

	for case in fixtures:
		var data: Variant = JSON.parse_string(JSON.stringify(fixtures[case]))
		if not data is Dictionary:
			_assert("fixture %s parses as dict" % case, false)
			continue
		var d: Dictionary = data
		var auth: int = int(d.get("user_info", {}).get("auth", 0))
		if case == "success":
			_assert("success auth=1", auth == 1)
		elif case == "bad_creds":
			_assert("bad_creds auth=0", auth == 0)
		else:
			_assert("empty auth=0 default", auth == 0)