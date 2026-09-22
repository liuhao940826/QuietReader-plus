# QuietReader

<p align="center">
  <strong>A lightweight macOS menu-bar reader for local TXT books.</strong><br>
  Floating reading · automatic paging · chapter navigation · progress recovery
</p>

<p align="center">
  <a href="https://github.com/liuhao940826/QuietReader-plus/releases">Download</a> ·
  <a href="README_CN.md">中文</a>
</p>

<p align="center">
  <a href="https://github.com/liuhao940826/QuietReader-plus/releases"><img src="https://img.shields.io/github/v/release/liuhao940826/QuietReader-plus?display_name=tag&style=flat-square" alt="Latest release"></a>
  <a href="https://github.com/liuhao940826/QuietReader-plus/blob/main/LICENSE"><img src="https://img.shields.io/github/license/liuhao940826/QuietReader-plus?style=flat-square" alt="License"></a>
  <a href="https://github.com/liuhao940826/QuietReader-plus"><img src="https://img.shields.io/github/stars/liuhao940826/QuietReader-plus?style=flat-square" alt="GitHub stars"></a>
</p>

---

## Overview

QuietReader is a native macOS menu-bar reader for local UTF-8 TXT files. It is designed for a small, unobtrusive floating window that stays above other apps while keeping your place between launches.

## Highlights

- **Floating reader** — draggable overlay with opacity and display-position controls.
- **Automatic paging** — play, pause, previous/next page, and adjustable playback speed.
- **Karaoke-style highlighting** — text is highlighted progressively and follows the selected speed.
- **Chapter navigation** — detects common Chinese chapter headings and jumps directly to them.
- **Full overview** — browse page previews and start reading from a selected paragraph.
- **Multi-display support** — choose the built-in display or an external monitor instead of showing on all screens.
- **Progress recovery** — remembers the current book, page, and character position.

## Screenshots

### Menu-bar controls

The menu-bar menu provides reading, book, display, opacity, and monitor controls in one place.

![Menu-bar controls](docs/screenshots/menu-bar-floating.png)

### Display selection

Choose exactly one display when using a MacBook with an external monitor.

![Display selection](docs/screenshots/screen-selection.png)

### Playback highlighting

During playback, characters transition to the highlight color at the current speed.

![Playback highlighting](docs/screenshots/word-highlight-playback.png)

### Chapters and overview

Use the chapter list for coarse navigation, or open the overview to select a precise page or paragraph.

![Chapter directory](docs/screenshots/chapter-directory.png)

![Overview and chapter navigation](docs/screenshots/overview-and-directory.png)

## Download

Download the latest macOS installer from [Releases](https://github.com/liuhao940826/QuietReader-plus/releases). The current release targets Apple Silicon Macs and includes `QuietReader-1.0.0.dmg`.

> The app is not notarized with an Apple Developer ID. If macOS blocks the first launch, open **System Settings → Privacy & Security** and allow the app manually.

## Requirements

- macOS 13 Ventura or later
- Apple Silicon Mac (`arm64` build)
- No network connection or online book source is required

## Build From Source

```bash
chmod +x build.sh build-dmg.sh
./build.sh
open build/MenuReader.app
```

To create a DMG installer:

```bash
./build-dmg.sh
```

## Basic Usage

1. Launch QuietReader from the menu bar.
2. Import a local TXT file from the book menu.
3. Select a display under **显示屏幕** when multiple monitors are connected.
4. Choose **居中** to show the floating reader.
5. Press `▶` to start automatic paging.
6. Use the speed menu or `‹ / ›` beside the speed value to tune playback.
7. Press `⤢` for page-level overview, or open **设置 → 目录** for chapter navigation.

## Project Status

This project is focused on local TXT reading on macOS. Windows `.exe` builds are not provided because the current implementation uses macOS AppKit and SwiftUI APIs.

## Credits and Disclaimer

QuietReader is a derivative work based on [zhiyozhao/menu-reader](https://github.com/zhiyozhao/menu-reader). The original project and its license notices remain acknowledged. Please review the upstream license and the licenses of all dependencies before redistributing modified versions.

QuietReader only displays local files supplied by the user. It does not provide books, online sources, search services, or copyright content. Users are responsible for ensuring that their files are lawfully obtained and used. The software is provided “as is”, without guarantees for every macOS version, device, encoding, or third-party environment.

## License

MIT License. See [LICENSE](LICENSE) if present, and the upstream project for the original licensing terms.
