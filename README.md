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

Download the latest APK from [GitHub Actions artifacts](https://github.com/clientskatbi/VR-IPTV/actions), or build locally:

```bash
# 1. Enable developer mode on your Quest (Meta Horizon app → headset → Developer Mode)
# 2. Connect Quest via USB-C
# 3. Build APK (requires Android SDK + OpenJDK 17)
godot --headless --path . --export-debug "Android" build/VR-IPTV-debug.apk

# 4. Install
adb install -r build/VR-IPTV-debug.apk
```

**Latest CI build:** 55M debug APK built automatically on every push. See Actions artifacts.

## Tests

```bash
godot --headless --quit-after 30 --path . res://tests/test_runner.tscn
```

Covers:
- `M3uParser` — empty input, multi-channel M3U, EXTINF/EXTGRP groups, tvg-id/logo, whitespace, missing duration, Arabic names
- `SettingsManager` — roundtrip credentials, disk obfuscation verified (password NOT stored plaintext), Arabic usernames, URL-unsafe characters, UI preferences
- `XtreamClient` — live/VOD/series URL builders, is_logged_in state, auth JSON contract (success/bad-creds/empty)
- `M3uParser` edge cases — BOM stripping, EXTVLCOPT ignored, EXTGRP-to-next-EXTINF pairing, orphan URLs, consecutive EXTINF, commas in names, IPv4/HTTPS URLs, durations -1/0, 10K-channel stress
- `LoginUI` validation — empty fields rejected, whitespace-only treated as empty, M3U fallback
- `ChannelBrowser` logic — search filter (case-insensitive + Arabic), tab routing
- `Main flow` — scene composition, signal contracts (login_succeeded/login_failed)
- `VideoPlayer` — stream construction, playback signals
- Scene smoke tests — all .tscn files load + instantiate
- Performance benchmarks — 50K channels <5s, 1K credential roundtrips <3s, 10K URL builds <200ms

Current: **123/123 passing** (36 core + 50 extended + 19 integration + 18 property).

Tests run automatically in CI before APK build (`.github/workflows/build.yml`).

Run all tests with one command:
```bash
godot --headless --quit-after 360 --path . res://tests/test_runner_combined.tscn
```

Run individual suites:
```bash
# Core + extended + integration (105 tests)
godot --headless --quit-after 240 --path . res://tests/test_runner_combined.tscn

# Property-based / fuzz (18 tests)
godot --headless --quit-after 120 --path . res://tests/test_property.tscn

# Lint (style/TODO markers — warning only)
godot --headless --quit-after 30 --path . --script res://tests/lint_runner.gd
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