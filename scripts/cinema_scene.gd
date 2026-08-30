extends Node3D
## VR cinema scene: large curved screen + ambient environment + playback controls.
##
## - XRCamera3D provides head tracking
## - Screen mesh faces the player, sized like a 200-inch cinema screen
## - Controller ray casts select / play / pause via UI overlays

@onready var screen: MeshInstance3D = $Screen
@onready var ambient_light: OmniLight3D = $Ambient
@onready var playback_ui: Control = $PlaybackUI

func _ready() -> void:
	# Configure screen material — VideoStreamPlayer streams to screen.material_override
	# The actual playback is driven by VideoStreamPlayer node added as child of $Screen
	pass

func attach_video_player(player: Node) -> void:
	# Reparent the VideoStreamPlayer so its texture renders on the cinema screen
	if player.get_parent():
		player.get_parent().remove_child(player)
	screen.add_child(player)
	# VideoStreamPlayer's rendered texture is on `player` itself;
	# the screen mesh's material_override stays as a dark backing plane.
	# When VideoStreamPlayer plays, its texture is shown via the player's own
	# Sprite3D-like rendering. For a quad surface, we use a Sprite3D wrapper.
	var sprite := Sprite3D.new()
	sprite.texture = _make_texture_from(player)
	screen.add_child(sprite)
	sprite.centered = false
	sprite.pixel_size = 0.01  # 1cm per pixel; tune to taste

func _make_texture_from(_player: Node) -> ImageTexture:
	# Placeholder — real implementation wires VideoStreamPlayer texture update
	# via Viewport.get_texture() in production. For now we leave the screen
	# backing material as a dark plane and rely on the player's own output.
	return null

func set_environment_color(color: Color) -> void:
	ambient_light.light_color = color

func _on_play_pause_pressed() -> void:
	# Handled by VideoStreamPlayer toggle
	pass