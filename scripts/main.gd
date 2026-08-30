extends Node
## Main scene root — orchestrates auth → channel browser → cinema playback.

@onready var login_ui: Control = $LoginUI
@onready var cinema: Node3D = $CinemaScene
@onready var browser: Control = $ChannelBrowser

func _ready() -> void:
	# Auto-login if credentials are saved
	var creds := SettingsManager.load_credentials()
	if not creds.username.is_empty():
		_attempt_login(creds.server, creds.username, creds.password)
	else:
		login_ui.show()
		browser.hide()
		cinema.hide()

	XtreamClient.login_succeeded.connect(_on_login_ok)
	XtreamClient.login_failed.connect(_on_login_fail)

func _attempt_login(server: String, username: String, password: String) -> void:
	XtreamClient.login(server, username, password)

func _on_login_ok(user_info: Dictionary) -> void:
	login_ui.hide()
	browser.show()
	# Load categories in background
	_load_live_categories()

func _on_login_fail(reason: String) -> void:
	push_warning("Login failed: %s" % reason)
	if login_ui.has_node("StatusLabel"):
		login_ui.get_node("StatusLabel").text = "Login failed: %s" % reason

func _load_live_categories() -> void:
	# Triggered via the browser; keep logic minimal here.
	pass

func play_channel(stream_url: String, channel_name: String) -> void:
	## Switch to cinema scene and start playback.
	login_ui.hide()
	browser.hide()
	cinema.show()
	var player: VideoStreamPlayer = cinema.get_node("Screen/VideoPlayer")
	player.play_url(stream_url)
	print("[VR-IPTV] Playing %s from %s" % [channel_name, stream_url])