# Glasdock

A macOS-style dock for KDE Plasma 6, plus matching panel widgets, written as
plain QML plasmoids.

| Widget | What it is |
| --- | --- |
| **Glasdock** (`glasdock/`) | The dock: icon zoom, glass bar, launcher, badges, optional player/weather/clock tiles |
| **Glasplayer** (`glasplayer/`) | Media player for any panel (e.g. the top bar): cover, title, play/pause, glass panel with controls |
| **Glasweather** (`glasweather/`) | Weather for any panel: icon and temperature, glass panel with a 5-day forecast |

All of them share the same glass look and code (`shared/`).

> **Status: alpha.** Features are still being added and things may change or
> break between versions. Tested on Plasma 6.8 (Wayland).

## Features

- **Icon zoom** — icons grow as the mouse gets close, with the bar growing
  evenly from the center.
- **Glass bar** — translucent background with border, top sheen and shadow;
  adapts to light and dark themes.
- **Animations** — icons bounce while an app launches or asks for attention.
- **Task manager** — pinned apps, running indicators, cycling between windows of
  the same app, middle-click for a new window, context menu.
- **Reorder by dragging** — drag icons along the dock to change their order.
- **Notification badges** — a dot or the number of unread notifications on
  each app, in the system accent color.
- **Styles** — Glass, Frosted, Clear or Solid, with optional border, shadow
  and accent tint; details follow the system accent color.
- **App launcher** — opens centered above the dock (apps button, Meta or
  Alt+F1): favorites, categories, search and power actions.
- **Configurable** — icon size, spacing, zoom, glass opacity, corner radius,
  launcher size/distance/opacity/animation and more.

## Install

```bash
git clone https://github.com/EudesN/glas-dock.git
cd glas-dock
./install.sh --restart          # all widgets
./install.sh glasplayer         # or only some of them
```

Then add the widgets to a panel (right-click the panel → *Add Widgets…*):
**Glasdock** to a bottom panel, **Glasplayer** / **Glasweather** anywhere (they
open their glass panel below the widget on a top panel and above it on a
bottom panel). Settings: right-click a widget → *Configure…*

Each Plasma widget must contain all of its files, so `install.sh` copies
`shared/` into every widget before installing it (`<widget>/contents/ui/shared/`,
ignored by git). After pulling changes, run `./install.sh --restart` again.

## Project layout

```
shared/        code used by every widget (glass surface, panels, player/weather data)
glasdock/      the dock
glasplayer/    panel media player
glasweather/   panel weather
install.sh     syncs shared/ into each widget and installs/updates it
```

## Known limitations

- The launcher's custom glass background cannot blur the desktop behind it
  (QML has no API for KWin blur). The theme background keeps the blur.
- Badges count unread notifications only; app-provided counters (Unity
  LauncherEntry, used by Telegram/Discord) are not read yet.
- No real blur behind the dock (QML has no API for KWin blur).
- Horizontal panels only.

## License

GPL-2.0-or-later. See [LICENSE](LICENSE).
