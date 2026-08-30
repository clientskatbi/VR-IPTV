extends VideoStreamPlayer
## VR cinema video player — wraps VideoStreamPlayer and applies screen quad to a ShaderMaterial.
##
## Supports HLS via .m3u8 URLs (Godot 4 VideoStreamPlayer supports HTTP HLS natively
## on Android when the FFmpeg runtime is present — see export_presets.cfg).

signal playback_started
signal playback_failed(reason: String)

func play_url(url: String) -> void:
	# Godot's VideoStreamPlayer supports HTTP/HLS streams via stream_resource.file = url
	var stream := VideoStream.new()
	stream.file = url
	self.stream = stream
	play()
	if not is_playing():
		playback_failed.emit("Failed to start playback for %s" % url)
		return
	playback_started.emit()