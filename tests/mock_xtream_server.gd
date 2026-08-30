extends Node
## In-process HTTP test server — serves canned Xtream API responses for unit tests.
## Single-connection-per-test: caller must call start(), then run scenario, then stop().

var _server: TCPServer
var _port: int = -1
var _running := false
var _routes: Dictionary = {}
var _received_requests: Array = []
var _polling := false

func start() -> String:
	_server = TCPServer.new()
	var err := _server.listen(0, "127.0.0.1")
	if err != OK:
		push_error("MockXtreamServer: listen failed: %d" % err)
		return ""
	_port = _server.get_local_port()
	_running = true
	_received_requests.clear()
	print("[MockServer] listening on http://127.0.0.1:%d" % _port)
	# Start polling
	if not _polling:
		_polling = true
		_poll_loop()
	return "http://127.0.0.1:%d" % _port

func stop() -> void:
	_running = false
	if _server:
		_server.stop()
		_server = null
	_port = -1

func set_route(path: String, response: Variant) -> void:
	_routes[path] = response

func get_received_requests() -> Array:
	return _received_requests.duplicate()

func clear_requests() -> void:
	_received_requests.clear()

func _poll_loop() -> void:
	while _running:
		if _server and _server.is_listening():
			while _server.is_connection_available():
				var conn := _server.take_connection()
				_handle_connection(conn)
		# Yield to tree
		await get_tree().process_frame
	_polling = false

func _handle_connection(conn: StreamPeerTCP) -> void:
	var bytes := PackedByteArray()
	var deadline := Time.get_ticks_msec() + 1000
	# Read until we get \r\n\r\n
	while Time.get_ticks_msec() < deadline:
		var available := conn.get_available_bytes()
		if available > 0:
			var data = conn.get_data(available)
			bytes.append_array(data[1])
			# Check for end of headers
			var found := false
			for i in range(0, bytes.size() - 3):
				if bytes[i] == 13 and bytes[i+1] == 10 and bytes[i+2] == 13 and bytes[i+3] == 10:
					found = true
					break
			if found:
				break
		await get_tree().process_frame

	if bytes.size() == 0:
		conn.disconnect_from_host()
		return

	var raw := bytes.get_string_from_utf8()
	var lines := raw.split("\r\n")
	if lines.size() == 0:
		conn.disconnect_from_host()
		return

	var request_line := lines[0]
	var parts := request_line.split(" ")
	if parts.size() < 2:
		conn.disconnect_from_host()
		return
	var method := parts[0]
	var full_path := parts[1]

	var path := full_path
	var query := {}
	var q_idx := full_path.find("?")
	if q_idx != -1:
		path = full_path.substr(0, q_idx)
		var query_str := full_path.substr(q_idx + 1)
		for pair in query_str.split("&"):
			var kv := pair.split("=")
			if kv.size() == 2:
				query[kv[0]] = kv[1]

	_received_requests.append({
		"method": method,
		"path": path,
		"query": query,
		"raw": request_line,
	})

	var response_body: String = "{}"
	if _routes.has(path):
		var route = _routes[path]
		if route is Callable:
			var result = route.call(query)
			response_body = str(result)
		elif route is String:
			response_body = route
		elif route is Dictionary:
			response_body = JSON.stringify(route)

	var response := "HTTP/1.1 200 OK\r\n"
	response += "Content-Type: application/json\r\n"
	response += "Content-Length: %d\r\n" % response_body.length()
	response += "Connection: close\r\n"
	response += "\r\n"
	response += response_body

	var out := response.to_utf8_buffer()
	conn.put_data(out)
	conn.disconnect_from_host()