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

func login(server_url: String, username: String, password: String) -> bool:
	"""Authenticate against Xtream Codes portal. Returns true if successful."""
	_server_url = server_url.trim_suffix("/")
	_username = username
	_password = password

	var url := "%s%s?username=%s&password=%s" % [
		_server_url, PLAYER_API_PATH,
		_urllib_encode(username), _urllib_encode(password),
	]

	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_login_response.bind(http))
	http.request(url, ["User-Agent: " + USER_AGENT])
	return true

func _on_login_response(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
	http.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		login_failed.emit("HTTP error: %d (result=%d)" % [response_code, result])
		return

	var text := body.get_string_from_utf8()
	var data: Variant = JSON.parse_string(text)
	if not data is Dictionary:
		login_failed.emit("Invalid JSON response")
		return

	var d := data as Dictionary
	if int(d.get("user_info", {}).get("auth", 0)) != 1:
		login_failed.emit("Invalid credentials")
		return

	_logged_in_user_info = d.get("user_info", {})
	login_succeeded.emit(_logged_in_user_info)

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
	var done := [false]
	var result_data: Array = []
	http.request_completed.connect(func(_r, _c, _h, body, h):
		h.queue_free()
		if body.size() > 0:
			var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
			if parsed is Array:
				result_data = parsed
		done[0] = true)
	http.request(url, ["User-Agent: " + USER_AGENT])

	# Block until response (Godot 4.4+ supports await on signal)
	while not done[0]:
		await get_tree().process_frame
	return result_data

func _urllib_encode(s: String) -> String:
	return s.replace("%", "%25").replace(" ", "%20").replace("&", "%26").replace("?", "%3F").replace("=", "%3D")