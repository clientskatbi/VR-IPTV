extends Node
## Main scene root — orchestrates auth → channel browser → cinema playback.

@onready var login_ui: Control = $LoginUI
@onready var cinema: Node3D = $CinemaScene
@onready var browser: Control = $ChannelBrowser

func _ready() -> void:
	# Auto-login if credentials are saved
	var creds := SettingsManager.load_credentials()
	if not creds.username.is_empty():
		# Route through login_ui so the StatusLabel and Timer are updated
		login_ui.attempt_login(creds.server, creds.username, creds.password)
	else:
		login_ui.show()
		browser.hide()
		cinema.hide()

	# Note: signal wiring lives in login_ui._ready() — main scene also
	# listens so the channel browser and cinema scenes can be shown.
	XtreamClient.login_succeeded.connect(_on_login_ok)
	XtreamClient.login_failed.connect(_on_login_fail)

func _on_login_ok(user_info: Dictionary) -> void:
	login_ui.hide()
	browser.show()
	# Load categories in background
	_load_live_categories()

func _on_login_fail(reason: String) -> void:
	push_warning("Login failed: %s" % reason)
	# login_ui listens to the same signal and already updates the StatusLabel
	# Just make sure the UI is visible so the user sees the error
	login_ui.show()

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