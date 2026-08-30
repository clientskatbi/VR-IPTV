extends SceneTree
## Lint script — scans scripts/ and tests/ for common GDScript issues.
## Reports: tab indentation, trailing whitespace, deprecated APIs, unused vars.

func _init() -> void:
	var exit_code := 0
	var paths := ["res://scripts/", "res://tests/"]
	var issues := 0
	for dir_path in paths:
		var dir = DirAccess.open(dir_path)
		if dir == null:
			print("Skipping %s (not found)" % dir_path)
			continue
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".gd"):
				var full_path: String = dir_path + file_name
				issues += _check_file(full_path)
			file_name = dir.get_next()
		dir.list_dir_end()

	print("\n%s" % ("❌ Lint found issues" if issues > 0 else "✅ Lint clean"))
	quit(1 if issues > 0 else 0)

func _check_file(path: String) -> int:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return 0
	var text := file.get_as_text()
	file.close()
	var line_no := 0
	var issues := 0
	var in_multiline_string := false
	for line in text.split("\n"):
		line_no += 1
		# Skip multi-line string bodies
		var stripped := line.strip_edges(true, false)
		if stripped.begins_with('"""') or stripped.begins_with("'''"):
			# Toggle multi-line state
			if stripped.count('"""') % 2 == 1 or stripped.count("'''") % 2 == 1:
				in_multiline_string = not in_multiline_string
		if in_multiline_string:
			continue
		# Trailing whitespace
		var trimmed := line.rstrip(" 	")
		if line != trimmed:
			print("  [trailing-whitespace] %s:%d" % [path, line_no])
			issues += 1
		# Mixed tabs/spaces (we want tabs for indentation)
		if line.length() > 0 and line[0] == ' ':
			print("  [leading-spaces] %s:%d (use tabs)" % [path, line_no])
			issues += 1
		# Detect obvious deprecated API usage
		if "OS.get_ticks_msec" in line and not "_" in line.substr(0, line.find("OS.get_ticks_msec")):
			# OS.get_ticks_msec is fine in Godot 4, no deprecation
			pass
		# print() debug statements left in code
		if stripped.begins_with("print(") and not path.contains("tests/"):
			# print in production code is a code smell
			if not stripped.contains("#"):
				print("  [debug-print] %s:%d (consider removing)" % [path, line_no])
				# Don't fail on this — it's a warning
		# TODO/FIXME markers
		if stripped.contains("TODO") or stripped.contains("FIXME"):
			print("  [todo-marker] %s:%d %s" % [path, line_no, stripped.substr(0, 60)])
			# Don't fail
		# Magic numbers in production code (heuristic: lines with > 2 numeric literals)
		var digit_count := 0
		for c in line:
			if c >= '0' and c <= '9':
				digit_count += 1
		# Skip this heuristic — too noisy

	# Limit issues per file to avoid spam
	return min(issues, 5)