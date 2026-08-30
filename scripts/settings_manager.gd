extends Node
## Encrypted local storage for Xtream / M3U credentials.
##
## Uses Godot's ConfigFile (plain text by default) — for production, encrypt
## with OS.set_environment + AES via GodotCrypto. For sideload use we keep
## it simple but write to user:// which is app-private on Quest.

const SETTINGS_PATH := "user://settings.cfg"

var settings := ConfigFile.new()

func save() -> void:
	var err := settings.save(SETTINGS_PATH)
	if err != OK:
		push_warning("SettingsManager: save failed: %d" % err)

func load_settings() -> void:
	if FileAccess.file_exists(SETTINGS_PATH):
		settings.load(SETTINGS_PATH)

func save_credentials(server: String, username: String, password: String) -> void:
	settings.set_value("xtream", "server", server)
	settings.set_value("xtream", "username", username)
	settings.set_value("xtream", "password", _obfuscate(password))
	settings.set_value("xtream", "saved_at", Time.get_unix_time_from_system())
	save()

func load_credentials() -> Dictionary:
	load_settings()
	var pwd: Variant = settings.get_value("xtream", "password", "")
	if typeof(pwd) == TYPE_STRING and not pwd.is_empty():
		pwd = _deobfuscate(pwd)
	return {
		"server": settings.get_value("xtream", "server", ""),
		"username": settings.get_value("xtream", "username", ""),
		"password": pwd,
	}

func clear_credentials() -> void:
	settings.erase_section("xtream")
	save()

func save_ui_preference(key: String, value: Variant) -> void:
	settings.set_value("ui", key, value)
	save()

func get_ui_preference(key: String, default: Variant = null) -> Variant:
	load_settings()
	return settings.get_value("ui", key, default)

# Simple XOR obfuscation (NOT real security — sideload-only apps run with user privileges).
# For production, use GodotCrypto AES-256 with a key derived from device-specific data.
func _obfuscate(plain: String) -> String:
	var key := "vr-iptv-2026"
	var bytes := plain.to_utf8_buffer()
	var key_bytes := key.to_utf8_buffer()
	var out := PackedByteArray()
	for i in bytes.size():
		out.append(bytes[i] ^ key_bytes[i % key_bytes.size()])
	return out.hex_encode()

func _deobfuscate(hex: String) -> String:
	if hex.is_empty():
		return ""
	var bytes := PackedByteArray()
	for i in range(0, hex.length(), 2):
		bytes.append(hex.substr(i, 2).hex_to_int())
	var key := "vr-iptv-2026"
	var key_bytes := key.to_utf8_buffer()
	var out := PackedByteArray()
	for i in bytes.size():
		out.append(bytes[i] ^ key_bytes[i % key_bytes.size()])
	return out.get_string_from_utf8()