# VR IPTV 🎬

**VR-native IPTV player for Meta Quest 2 and other OpenXR headsets.**

Bring your own Xtream Codes, M3U playlist, or Stalker portal — watch live TV, movies, and series inside an immersive cinema environment.

## Features

- ✅ **Xtream Codes API** — URL + Username + Password login
- ✅ **M3U / M3U8 playlists** — local file or remote URL
- ✅ **Stalker portals** — MAC-based authentication
- ✅ **VR-native cinema** — large screen, ambient environments, controller playback controls
- ✅ **EPG (Electronic Program Guide)** — XMLTV-aware
- ✅ **Live TV, Movies, Series categories**
- ✅ **Favorites + watch history**
- ✅ **100% offline** — credentials never leave the device
- ✅ **MIT licensed**, no ads, no tracking

## Target platforms

- Meta Quest 2 / 3 / Pro (Android, OpenXR)
- Any OpenXR headset (PCVR — Windows / Linux)

## Stack

- **Engine:** Godot 4.7
- **VR:** OpenXR via godotopenxrvendors (Meta loader)
- **Video:** Godot's built-in VideoStreamPlayer (libvpx/libtheora + FFmpeg at runtime)
- **Streaming:** HTTPClient + HTTPSClient + custom HLS / MPEG-TS parser

## Quick start (sideload to Quest 2)

```bash
# 1. Enable developer mode on your Quest (Meta Horizon app → headset → Developer Mode)
# 2. Connect Quest via USB-C
# 3. Build APK (requires Android SDK + OpenJDK 17)
godot --headless --path . --export-debug "Android" build/VR-IPTV-debug.apk

# 4. Install
adb install -r build/VR-IPTV-debug.apk
```

## Project layout

```
VR-IPTV/
├── scenes/
│   ├── main.tscn          # VR scene root
│   ├── cinema.tscn        # Immersive cinema with screen + seats
│   └── ui/                # Controller-friendly menus
├── scripts/
│   ├── xtream_client.gd   # Xtream Codes API client
│   ├── m3u_parser.gd      # M3U playlist parser
│   ├── video_player.gd    # HLS/MPEG-TS playback controller
│   └── settings_manager.gd # Encrypted credential storage
├── addons/
│   └── godotopenxrvendors/  # Meta Quest OpenXR loader
└── export/                 # Built APKs
```

## License

MIT — see [LICENSE](LICENSE).

## Disclaimer

VR IPTV is a media player only. It does not provide, host, or sell any IPTV subscriptions or content. Users must supply their own legal subscriptions. We assume no responsibility for the legality of streams accessed through third-party providers.