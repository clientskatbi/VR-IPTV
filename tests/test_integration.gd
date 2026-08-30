extends Node
## Integration tests — XtreamClient.login full flow against mock HTTP server.
## Runs as standalone scene via test_integration.tscn.

var passed := 0
var failed := 0
var exit_code := 0

func _ready() -> void:
	await _run_xtream_login_integration()
	await _run_xtream_failed_login_scenarios()
	await _run_xtream_streams_integration()
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
	print("Integration tests: %d passed, %d failed" % [passed, failed])
	print("─────────────────────────────")

func _wait(ms: int) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < ms:
		await get_tree().process_frame

func _run_xtream_login_integration() -> void:
	_begin("XtreamClient login integration")
	var MockServer = load("res://tests/mock_xtream_server.gd")
	var Xtream = load("res://scripts/xtream_client.gd")

	var server = MockServer.new()
	get_tree().root.call_deferred("add_child", server); await _wait(50)

	# Configure auth success response
	server.set_route("/player_api.php", {
		"user_info": {"auth": 1, "username": "demo", "status": "Active"},
		"server_info": {"url": "127.0.0.1", "port": "8080"}
	})

	var url: String = server.start()
	var client = Xtream.new()
	get_tree().root.call_deferred("add_child", client); await _wait(30)

	var succeeded := [false]
	var failed_signal := [""]
	client.login_succeeded.connect(func(ui): succeeded[0] = true)
	client.login_failed.connect(func(reason): failed_signal[0] = reason)

	client.login(url, "demo", "pass123")
	await _wait(500)

	_assert("login_succeeded emitted", succeeded[0])
	_assert("login_failed NOT emitted", failed_signal[0] == "")
	_assert("client is_logged_in() true", client.is_logged_in())

	# Verify the request reached the server with right params
	var reqs = server.get_received_requests()
	_assert("server received 1 request", reqs.size() == 1)
	if reqs.size() >= 1:
		_assert("request path is /player_api.php", reqs[0].path == "/player_api.php")
		_assert("request method is GET", reqs[0].method == "GET")
		_assert("username param sent", reqs[0].query.get("username") == "demo")
		_assert("password param sent", reqs[0].query.get("password") == "pass123")

	client.queue_free()
	server.stop()
	server.queue_free()

func _run_xtream_failed_login_scenarios() -> void:
	_begin("XtreamClient login failure scenarios")
	var MockServer = load("res://tests/mock_xtream_server.gd")
	var Xtream = load("res://scripts/xtream_client.gd")

	# Scenario 1: auth=0 (bad credentials)
	var server1 = MockServer.new()
	get_tree().root.add_child(server1)
	server1.set_route("/player_api.php", {"user_info": {"auth": 0, "message": "Invalid credentials"}})

	var client1 = Xtream.new()
	get_tree().root.add_child(client1)
	var fail_reason := [""]
	client1.login_failed.connect(func(r): fail_reason[0] = r)
	client1.login(server1.start(), "bad", "wrong")
	await _wait(500)
	_assert("auth=0 emits Invalid credentials", fail_reason[0] == "Invalid credentials")
	_assert("client NOT logged in", not client1.is_logged_in())

	client1.queue_free()
	server1.stop()
	server1.queue_free()

	# Scenario 2: malformed JSON response
	var server2 = MockServer.new()
	get_tree().root.add_child(server2)
	server2.set_route("/player_api.php", "this is not JSON {[")

	var client2 = Xtream.new()
	get_tree().root.add_child(client2)
	fail_reason[0] = ""
	client2.login_failed.connect(func(r): fail_reason[0] = r)
	client2.login(server2.start(), "u", "p")
	await _wait(500)
	_assert("invalid JSON triggers login_failed", fail_reason[0] == "Invalid JSON response")

	client2.queue_free()
	server2.stop()
	server2.queue_free()

	# Scenario 3: empty body
	var server3 = MockServer.new()
	get_tree().root.add_child(server3)
	server3.set_route("/player_api.php", "")

	var client3 = Xtream.new()
	get_tree().root.add_child(client3)
	fail_reason[0] = ""
	client3.login_failed.connect(func(r): fail_reason[0] = r)
	client3.login(server3.start(), "u", "p")
	await _wait(500)
	_assert("empty body triggers login_failed", fail_reason[0] == "Invalid JSON response")

	client3.queue_free()
	server3.stop()
	server3.queue_free()

func _run_xtream_streams_integration() -> void:
	_begin("XtreamClient streams fetch integration")
	var MockServer = load("res://tests/mock_xtream_server.gd")
	var Xtream = load("res://scripts/xtream_client.gd")

	var server = MockServer.new()
	get_tree().root.call_deferred("add_child", server); await _wait(50)

	# Auth route
	server.set_route("/player_api.php", func(query):
		if query.get("action") == "get_live_categories":
			return JSON.stringify([
				{"category_id": "1", "category_name": "Sports"},
				{"category_id": "2", "category_name": "News"},
			])
		elif query.get("action") == "get_live_streams":
			return JSON.stringify([
				{"stream_id": 100, "name": "ESPN HD", "category_id": "1"},
				{"stream_id": 101, "name": "BBC One", "category_id": "2"},
				{"stream_id": 102, "name": "CNN", "category_id": "2"},
			])
		elif query.get("action") == "" or not query.has("action"):
			# login response
			return JSON.stringify({"user_info": {"auth": 1}})
		return "[]"
	)

	var client = Xtream.new()
	get_tree().root.call_deferred("add_child", client); await _wait(30)

	client.login(server.start(), "u", "p")
	await _wait(500)
	_assert("logged in via mock", client.is_logged_in())

	# Fetch live categories
	var cats = await client.get_live_categories()
	_assert("get_live_categories returns 2 categories", cats.size() == 2)
	if cats.size() >= 2:
		_assert("first category is Sports", cats[0].category_name == "Sports")
		_assert("second category is News", cats[1].category_name == "News")

	# Fetch live streams
	var streams = await client.get_live_streams()
	_assert("get_live_streams returns 3 streams", streams.size() == 3)
	if streams.size() >= 1:
		_assert("first stream is ESPN HD", streams[0].name == "ESPN HD")

	# Verify stream URL builder works for fetched stream
	if streams.size() >= 1:
		var stream_url: String = client.build_stream_url(int(streams[0].stream_id), "ts")
		_assert("build_stream_url uses correct format",
			stream_url.contains("/live/u/p/100.ts"))

	client.queue_free()
	server.stop()
	server.queue_free()