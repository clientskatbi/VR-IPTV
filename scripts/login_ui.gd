extends Control
## Login form for Xtream Codes or M3U URL.

@onready var server_input: LineEdit = $ServerInput
@onready var username_input: LineEdit = $UsernameInput
@onready var password_input: LineEdit = $PasswordInput
@onready var login_button: Button = $LoginButton
@onready var m3u_button: Button = $M3UButton
@onready var status_label: Label = $StatusLabel

func _ready() -> void:
	login_button.pressed.connect(_on_login_pressed)
	m3u_button.pressed.connect(_on_m3u_pressed)

	# Prefill from saved credentials
	var creds := SettingsManager.load_credentials()
	if not creds.server.is_empty():
		server_input.text = creds.server
		username_input.text = creds.username
		password_input.text = creds.password

func _on_login_pressed() -> void:
	var server := server_input.text.strip_edges()
	var username := username_input.text.strip_edges()
	var password := password_input.text
	if server.is_empty() or username.is_empty() or password.is_empty():
		status_label.text = "All fields required"
		return
	SettingsManager.save_credentials(server, username, password)
	XtreamClient.login(server, username, password)
	status_label.text = "Connecting..."

func _on_m3u_pressed() -> void:
	# Future: open M3U URL prompt scene
	status_label.text = "M3U mode coming soon — use Xtream for now"