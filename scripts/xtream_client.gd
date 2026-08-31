extends Node
## Xtream Codes API client for IPTV subscriptions.
##
## Usage:
##     XtreamClient.login("http://server.com:8080", "username", "password")
##     var categories = await XtreamClient.get_live_categories()
##     var streams = await XtreamClient.get_live_streams(category_id)

signal login_succeeded(user_info: Dictionary)
signal login_failed(reason: String)
signal categories_loaded(kind: String, categories: Array)
signal streams_loaded(kind: String, streams: Array)

const PLAYER_API_PATH := "/player_api.php"
const USER_AGENT := "Mozilla/5.0 (Linux; Quest 2) VR-IPTV/0.1"

var _server_url: String = ""
var _username: String = ""
var _password: String = ""
var _logged_in_user_info: Dictionary = {}

const LOGIN_TIMEOUT_SEC := 15.0

func login(server_url: String, username: String, password: String) -> bool:
	"""Authenticate against Xtream Codes portal. Returns true if request was started."""
	_server_url = server_url.trim_suffix("/")
	_username = username
	_password = password

	var url := "%s%s?username=%s&password=%s" % [
		_server_url, PLAYER_API_PATH,
		_urllib_encode(username), _urllib_encode(password),
	]

	# Defer to next frame so HTTPRequest is fully in the tree before request()
	_initiate_request.call_deferred(url, "login")
	return true

func _initiate_request(url: String, kind: String) -> void:
	## Internal: actually perform the HTTP request after the request node is in the tree.
	var http := HTTPRequest.new()
	add_child(http)
	http.timeout = LOGIN_TIMEOUT_SEC
	http.use_threads = true
	if kind == "login":
		http.request_completed.connect(_on_login_response.bind(http))
	else:
		# _fetch_action manages its own callback via state dict
		pass
	var err := http.request(url, ["User-Agent: " + USER_AGENT])
	if err != OK:
		push_error("XtreamClient: request() failed: %d for %s" % [err, kind])
		http.queue_free()
		if kind == "login":
			login_failed.emit("Cannot start request (code=%d)" % err)

func _on_login_response(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
	http.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS:
		login_failed.emit(_describe_http_error(result, response_code))
		return

	var text := body.get_string_from_utf8()
	var data: Variant = JSON.parse_string(text)
	if not data is Dictionary:
		login_failed.emit("Invalid JSON response (body=%d bytes)" % body.size())
		return

	var d := data as Dictionary
	if int(d.get("user_info", {}).get("auth", 0)) != 1:
		login_failed.emit("Invalid credentials (auth=0)")
		return

	_logged_in_user_info = d.get("user_info", {})
	login_succeeded.emit(_logged_in_user_info)

func _describe_http_error(result: int, response_code: int) -> String:
	## Translates HTTPRequest.Result + status code into a human-readable message.
	var result_name := "Unknown"
	match result:
		HTTPRequest.RESULT_SUCCESS: result_name = "Success"
		HTTPRequest.RESULT_CHUNKED_BODY_SIZE_MISMATCH: result_name = "Chunked body size mismatch"
		HTTPRequest.RESULT_CANT_CONNECT: result_name = "Cannot connect to server (host down or port blocked)"
		HTTPRequest.RESULT_CANT_RESOLVE: result_name = "Cannot resolve hostname (DNS failed or no internet)"
		HTTPRequest.RESULT_CONNECTION_ERROR: result_name = "Connection error"
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR: result_name = "TLS/SSL handshake error (certificate invalid)"
		HTTPRequest.RESULT_NO_RESPONSE: result_name = "No response from server (timeout)"
		HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED: result_name = "Response too large"
		HTTPRequest.RESULT_BODY_DECOMPRESS_FAILED: result_name = "Cannot decompress response"
		HTTPRequest.RESULT_REQUEST_FAILED: result_name = "Request failed"
		HTTPRequest.RESULT_DOWNLOAD_FILE_CANT_OPEN: result_name = "Cannot open download file"
		HTTPRequest.RESULT_REDIRECT_LIMIT_REACHED: result_name = "Too many redirects"
		HTTPRequest.RESULT_TLS_CERTIFICATE_CANT_VERIFY: result_name = "TLS certificate cannot be verified"
	if response_code == 0:
		return "%s (network error, code=%d)" % [result_name, result]
	return "%s (HTTP %d)" % [result_name, response_code]

func get_live_categories() -> Array:
	return await _fetch_action("get_live_categories")

func get_live_streams(category_id: String = "") -> Array:
	return await _fetch_action("get_live_streams", {"category_id": category_id})

func get_vod_categories() -> Array:
	return await _fetch_action("get_vod_categories")

func get_vod_streams(category_id: String = "") -> Array:
	return await _fetch_action("get_vod_streams", {"category_id": category_id})

func get_series_categories() -> Array:
	return await _fetch_action("get_series_categories")

func get_series_streams(category_id: String = "") -> Array:
	return await _fetch_action("get_series_streams", {"category_id": category_id})

func build_stream_url(stream_id: int, extension: String = "ts") -> String:
	"""Return the direct HTTP URL for a live stream."""
	return "%s/live/%s/%s/%d.%s" % [_server_url, _username, _password, stream_id, extension]

func build_vod_url(stream_id: int, extension: String = "mp4") -> String:
	return "%s/movie/%s/%s/%d.%s" % [_server_url, _username, _password, stream_id, extension]

func build_series_url(stream_id: int) -> String:
	return "%s/series/%s/%s/%d" % [_server_url, _username, _password, stream_id]

func is_logged_in() -> bool:
	return not _logged_in_user_info.is_empty()

func _fetch_action(action: String, params: Dictionary = {}) -> Array:
	if not is_logged_in():
		push_error("XtreamClient: not logged in")
		return []

	var url := "%s%s?username=%s&password=%s&action=%s" % [
		_server_url, PLAYER_API_PATH, _username, _password, action,
	]
	for key in params:
		url += "&%s=%s" % [key, _urllib_encode(str(params[key]))]

	var http := HTTPRequest.new()
	add_child(http)
	# Use Array/Dictionary containers since GDScript closures capture by value for primitives
	var state := {"done": false, "data": []}
	# Capture http in lambda scope; signal passes 4 args (result, code, headers, body)
	http.request_completed.connect(func(_r, _c, _h, body):
		http.queue_free()
		if body.size() > 0:
			var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
			if parsed is Array:
				state["data"] = parsed
		state["done"] = true)
	var req_err := http.request(url, ["User-Agent: " + USER_AGENT])
	if req_err != OK:
		push_error("XtreamClient: request failed: %d" % req_err)
		http.queue_free()
		return []

	# Block until response
	var deadline := Time.get_ticks_msec() + 30000
	while not state["done"]:
		if Time.get_ticks_msec() > deadline:
			push_error("XtreamClient: timeout waiting for %s" % action)
			break
		# Use main_loop's process_frame which is always available
		await Engine.get_main_loop().process_frame
	return state["data"]

func _urllib_encode(s: String) -> String:
	return s.replace("%", "%25").replace(" ", "%20").replace("&", "%26").replace("?", "%3F").replace("=", "%3D")