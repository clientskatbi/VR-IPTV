extends Control
## Login form for Xtream Codes or M3U URL.

@onready var server_input: LineEdit = $ServerInput
@onready var username_input: LineEdit = $UsernameInput
@onready var password_input: LineEdit = $PasswordInput
@onready var login_button: Button = $LoginButton
@onready var m3u_button: Button = $M3UButton
@onready var status_label: Label = $StatusLabel

var _login_in_progress := false
var _elapsed_timer: Timer
var _elapsed_seconds: int = 0

func _ready() -> void:
	login_button.pressed.connect(_on_login_pressed)
	m3u_button.pressed.connect(_on_m3u_pressed)

	# Prefill from saved credentials
	var creds := SettingsManager.load_credentials()
	if not creds.server.is_empty():
		server_input.text = creds.server
		username_input.text = creds.username
		password_input.text = creds.password

	# Wire login signals once
	if not XtreamClient.login_succeeded.is_connected(_on_login_ok):
		XtreamClient.login_succeeded.connect(_on_login_ok)
	if not XtreamClient.login_failed.is_connected(_on_login_fail):
		XtreamClient.login_failed.connect(_on_login_fail)

	# Setup elapsed-time timer
	_elapsed_timer = Timer.new()
	_elapsed_timer.wait_time = 1.0
	_elapsed_timer.one_shot = false
	_elapsed_timer.timeout.connect(_on_tick)
	add_child(_elapsed_timer)

func _on_login_pressed() -> void:
	if _login_in_progress:
		return
	var server := server_input.text.strip_edges()
	var username := username_input.text.strip_edges()
	var password := password_input.text
	if server.is_empty() or username.is_empty() or password.is_empty():
		status_label.text = "All fields required"
		return
	_login_in_progress = true
	_elapsed_seconds = 0
	login_button.disabled = true
	login_button.text = "Connecting..."
	status_label.text = "Connecting... (0s)"
	_elapsed_timer.start()
	SettingsManager.save_credentials(server, username, password)
	XtreamClient.login(server, username, password)

func _on_tick() -> void:
	if not _login_in_progress:
		return
	_elapsed_seconds += 1
	if _elapsed_seconds >= 30:
		# Hard timeout — force fail so the user isn't stuck forever
		_on_login_fail("Timeout after 30s — server not responding")
		_elapsed_timer.stop()
		return
	status_label.text = "Connecting... (%ds)" % _elapsed_seconds

func _on_login_ok(_user_info: Dictionary) -> void:
	_login_in_progress = false
	_elapsed_timer.stop()
	login_button.disabled = false
	login_button.text = "Sign In"
	status_label.text = "Login OK — loading channels..."
	# Switch to browser scene — defer to next frame so UI updates first
	get_tree().create_timer(0.5).timeout.connect(func():
		var main := get_tree().root.get_node_or_null("Main")
		if main and main.has_method("_on_login_ok"):
			main._on_login_ok(_user_info)
	)

func _on_login_fail(reason: String) -> void:
	_login_in_progress = false
	_elapsed_timer.stop()
	login_button.disabled = false
	login_button.text = "Sign In"
	status_label.text = "Login failed: %s" % reason

func _on_m3u_pressed() -> void:
	status_label.text = "M3U mode coming soon — use Xtream for now"