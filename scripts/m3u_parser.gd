extends RefCounted
## Lightweight M3U / M3U8 playlist parser.
##
## Usage:
##     var parser := M3uParser.new()
##     var channels = parser.parse_text(text)
##     var channels = parser.parse_url("https://server.com/playlist.m3u")

class Channel:
	var name: String
	var url: String
	var logo: String = ""
	var group: String = ""
	var tvg_id: String = ""
	var tvg_name: String = ""
	var duration: int = -1

var _channels: Array[Channel] = []
var _pending_group: String = ""

func parse_text(text: String) -> Array[Channel]:
	_channels.clear()
	_pending_group = ""
	var lines := text.split("\n")
	var current := Channel.new()

	for raw_line in lines:
		var line := raw_line.strip_edges()
		if line.is_empty():
			continue

		if line.begins_with("#EXTM3U"):
			continue
		elif line.begins_with("#EXTINF"):
			current = Channel.new()
			current.group = _pending_group
			_pending_group = ""
			# Format: #EXTINF:duration,channel name
			var comma_idx := line.find(",")
			if comma_idx != -1:
				var metadata := line.substr(0, comma_idx)
				current.name = line.substr(comma_idx + 1).strip_edges()
				current.duration = _parse_duration(metadata)
				_parse_extinf_attributes(metadata, current)
		elif line.begins_with("#EXTGRP"):
			_pending_group = line.substr(8).strip_edges()
		elif line.begins_with("http://") or line.begins_with("https://"):
			current.url = line
			_channels.append(current)
			current = Channel.new()

	return _channels

func parse_url(url: String) -> Array[Channel]:
	var http := HTTPRequest.new()
	# Caller is responsible for adding http to tree.
	var done := [false]
	var text := ""
	http.request_completed.connect(func(_r, code, _h, body, h):
		h.queue_free()
		if code == 200 and body.size() > 0:
			text = body.get_string_from_utf8()
		done[0] = true)
	http.request(url)
	while not done[0]:
		await Engine.get_main_loop().process_frame
	return parse_text(text) if not text.is_empty() else []

func get_channels() -> Array[Channel]:
	return _channels

func _parse_duration(metadata: String) -> int:
	# metadata looks like: #EXTINF:-1 tvg-id="..." group-title="..."...
	# The duration is the numeric portion immediately after #EXTINF:
	var hash_idx := metadata.find("#EXTINF")
	if hash_idx == -1:
		return -1
	var after_prefix := metadata.substr(hash_idx + 7)  # len("#EXTINF") = 7
	var parts := after_prefix.split(" ")
	for p in parts:
		var colon := p.find(":")
		if colon != -1:
			var num_str := p.substr(colon + 1)
			if num_str.is_valid_int():
				return num_str.to_int()
	return -1

func _parse_extinf_attributes(metadata: String, ch: Channel) -> void:
	# Extract key="value" pairs
	var regex := RegEx.new()
	regex.compile("([\\w-]+)=\"([^\"]*)\"")
	var matches := regex.search_all(metadata)
	for m in matches:
		var key: String = m.get_string(1)
		var val: String = m.get_string(2)
		match key:
			"tvg-id": ch.tvg_id = val
			"tvg-name": ch.tvg_name = val
			"tvg-logo": ch.logo = val
			"group-title": ch.group = val