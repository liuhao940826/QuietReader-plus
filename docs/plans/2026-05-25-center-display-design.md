# Center Display Mode Design

## Overview

Add a "center display" mode that shows reading text in a transparent NSWindow centered at the top of the screen (menu bar area), instead of the default right-side MenuBarExtra label.

## Architecture

```
┌──────────────────────────────────────────────────────┐
│  macOS Menu Bar                                       │
│  [App Menu]         [Center Text Window]   [📖][...]  │
└──────────────────────────────────────────────────────┘
```

### Two Display Modes (switchable in Settings)

| Mode | Text Location | MenuBarExtra Label | Click Behavior |
|------|--------------|-------------------|---------------|
| Right (default) | MenuBarExtra label | Text + 150pt frame | Opens menu |
| Center | Independent NSWindow | Book icon only (📖) | Text: pass-through; Icon: opens menu |

## Implementation

### CenterDisplayWindow (new file)

NSWindow subclass with:
- `styleMask: [.borderless, .nonactivatingPanel]`
- `level: .statusBar`
- `ignoresMouseEvents = true` (click pass-through)
- `backgroundColor = .clear`
- `isOpaque = false`
- `hasShadow = false`
- `collectionBehavior: [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]`

Content: NSHostingView with a simple Text view (monospaced, 12pt).

### Positioning Logic

```swift
let screenFrame = screen.frame
let safeAreaTop = screen.safeAreaInsets.top // > 0 means notch

let x = screenFrame.midX - windowWidth / 2
let y: CGFloat
if safeAreaTop > 0 {
    // Notch screen: position below the notch
    y = screenFrame.maxY - safeAreaTop
} else {
    // No notch: position at top edge
    y = screenFrame.maxY - menuBarHeight
}
```

### Mode Setting

- Stored in UserDefaults via `@AppStorage("displayMode")`
- Values: `"right"` (default), `"center"`
- Settings UI: Picker in General tab

### State Sync

- `ReaderStore.currentText` changes → update center window text
- `ReaderStore.isHidden` → hide/show center window
- Display mode change → create/destroy center window, toggle MenuBarExtra label

### Edge Cases

| Case | Behavior |
|------|----------|
| Full-screen app | Hide center window (menu bar hidden) |
| Multiple displays | Show on main screen only |
| Notch screen | Offset window below notch area |
| Screen config change | Reposition window |
| Hidden state | Hide center window, show 📖 in MenuBarExtra |

## Files to Create/Modify

- **New**: `MenuReader/CenterDisplayWindow.swift`
- **Modify**: `MenuReader/MenuReaderApp.swift` (toggle label based on mode)
- **Modify**: `MenuReader/ReaderStore.swift` (add displayMode, notify window)
- **Modify**: `MenuReader/SettingsWindow.swift` (add display mode picker)

## Reference

Approach based on [boring.notch](https://github.com/TheBoredTeam/boring.notch) (9.3k stars) — uses NSWindow positioned at screen top-center with `borderless + nonactivatingPanel` style.
