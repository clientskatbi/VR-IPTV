extends Control
## Channel browser: lists categories + streams, switches to cinema on selection.

@onready var tabs: TabBar = $CategoryTabs
@onready var search_bar: LineEdit = $SearchBar
@onready var channel_list: ItemList = $ChannelList

var _categories: Array = []
var _streams: Array = []
var _kind: String = "live"

func _ready() -> void:
	tabs.tab_changed.connect(_on_tab_changed)
	channel_list.item_selected.connect(_on_stream_selected)
	XtreamClient.categories_loaded.connect(_on_categories_loaded)
	XtreamClient.streams_loaded.connect(_on_streams_loaded)

func _on_tab_changed(idx: int) -> void:
	match idx:
		0: _kind = "live"
		1: _kind = "vod"
		2: _kind = "series"
	_load_streams()

func _on_categories_loaded(kind: String, categories: Array) -> void:
	if kind != _kind:
		return
	_categories = categories
	if categories.size() > 0 and categories[0] is Dictionary:
		_load_streams()

func _on_streams_loaded(kind: String, streams: Array) -> void:
	if kind != _kind:
		return
	_streams = streams
	channel_list.clear()
	for s in streams:
		if s is Dictionary:
			channel_list.add_item(str(s.get("name", "Unnamed")))
	_refresh_filter()

func _on_stream_selected(idx: int) -> void:
	if idx < 0 or idx >= _streams.size():
		return
	var s: Dictionary = _streams[idx]
	var stream_id: int = int(s.get("stream_id", 0))
	if stream_id == 0:
		return
	var url: String
	match _kind:
		"live": url = XtreamClient.build_stream_url(stream_id, "ts")
		"vod": url = XtreamClient.build_vod_url(stream_id, s.get("container_extension", "mp4"))
		"series": url = XtreamClient.build_series_url(stream_id)
	get_tree().root.get_node("Main").play_channel(url, str(s.get("name", "")))

func _refresh_filter() -> void:
	var q := search_bar.text.to_lower()
	channel_list.clear()
	for s in _streams:
		if not s is Dictionary:
			continue
		var name: String = str(s.get("name", ""))
		if q.is_empty() or q in name.to_lower():
			channel_list.add_item(name)

func _load_streams() -> void:
	# Initial fetch — no category filter, returns all
	match _kind:
		"live": _streams = await XtreamClient.get_live_streams()
		"vod": _streams = await XtreamClient.get_vod_streams()
		"series": _streams = await XtreamClient.get_series_streams()
	channel_list.clear()
	for s in _streams:
		if s is Dictionary:
			channel_list.add_item(str(s.get("name", "Unnamed")))