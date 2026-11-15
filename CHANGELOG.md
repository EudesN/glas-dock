# Changelog

## 0.6.0-alpha.1

New widgets
- **Glasclock** for the top bar (or any panel): time and date in the bar, glass
  calendar panel with month grid, ISO week, event cards, and automatic national
  holiday region detection from the system time zone.

Blur and themes
- Real glass blur in the exact rounded shape of the bar and panels via the
  included `org.glasdock.blur` C++ helper plugin (`KWindowEffects::enableBlurBehind`),
  with multi-region union when multiple blur layers share a window and a frost
  veil/grain slider on top of the blur; independent blur option for the launcher.
- Explicit **Theme** setting (Follow system, Dark, Light) across Glasdock,
  Glasplayer, Glasweather and Glasclock, decoupling the glass and text palette
  from the system-wide Plasma color scheme.

Dock and launcher
- Dock separators: right-click any icon (or the apps button) to add or remove a
  vertical separator after it; separators follow their icon when reordered.
- Multi-window running indicator: pill width scales with open window count (2,
  3+ windows) with per-segment separator ticks.
- Steadier bar during hover: clamped zoom over the apps button, tighter
  water-filling convergence (0 px horizontal drift), hover zoom restricted to
  the glass bar bounds, and spare room reserved for newly opened apps.
- Apps button no longer shows the hover name label above the bar.
- Launcher polish: inner border sheen, category pill transitions, icon tile
  hover highlight, and search input focus ring.

Widgets and panels
- **Weather badge icons**: 20 custom rounded-square SVG badges (10 WMO
  conditions × day/night) for the dock tile, Glasweather and forecast rows.
- **Glasplayer**: instant cover art loading via parallel YouTube HQ thumbnail
  probing (`hqdefault`/`mqdefault`), Spotify Connect metadata fallback via
  `pw-dump` and `oembed`, cover URL prefetching, and reliable app window
  activation on Wayland via `TaskManager.TasksModel`.
- Panels open closer to their widget (configurable gap) and support an
  experimental morph animation growing out of the widget pill.

Fixes
- Live window preview stays open reliably when moving the cursor across dock
  icons or into the preview card, and stops KWin screencasts as soon as hidden.
- Fixed calendar selected day resetting every second when seconds are shown,
  eliminated `FormLayout` QML scene warnings in settings pages, and cleaned up
  redundant surface items and weather startup requests.

## 0.5.0-alpha.1

New widgets
- **Glasplayer** and **Glasweather** for the top bar (or any panel): title,
  artist and previous/play/next in the bar; icon, temperature and city; glass
  panels with cover, progress, controls, current conditions and a 5-day
  forecast. Panels stay on screen near screen edges.
- Experimental player, weather and clock tiles inside the dock.

Dock
- Live window previews on hover (KWin screencast), with close and activate.
- "Blur" style using Plasma's own blurred background, for the dock and all
  panels; style choice for the launcher too (Glass, Frosted, Clear, Solid, Blur).
- Bar width stays constant while the pointer moves along the icons (no wobble).
- Settings split into Appearance, Behavior, Launcher and Widgets tabs.

Animations and performance
- Launcher and panels: single motion, staggered reveal, animated close,
  follow Plasma's animation speed; panels swap content in place.
- Launcher loaded on first use; capped launch/attention bounces; widgets cost
  nothing when disabled; panel content destroyed when closed.

Fixes
- Player followed a paused player or got stuck on "Nothing playing".
- Weather panel stuck on "Loading…", clipped titles, zero-width hidden player.

Project
- One folder per widget plus `shared/`; `install.sh` installs/updates them.
- `tools/fake_player.py`: silent fake MPRIS player for testing.

## 0.4.0-alpha.1

- Drag icons to reorder them; the dragged icon stays inside the bar and the
  new order of pinned apps is saved.
- Notification badges: a dot for one unread notification, the number for two
  or more; system accent color by default (red as an option).
- Dock styles: Glass, Frosted, Clear (no background) and Solid, with optional
  border and shadow.
- Dock details (running dots, active-app pill, labels) follow the system
  accent color; optional accent tint on the glass.
- Icon hit areas cover the whole bar with no gaps between icons.
- Launcher: scrollbar beside the app grid, more room after the categories and
  a tooltip for long app names.

## 0.3.0-alpha.1

First public alpha.

- macOS-style dock for the Plasma 6 panel: parabolic icon zoom, glass bar,
  launch/attention bounce, running indicators and app names on hover.
- Pinned apps, window cycling for grouped apps, context menu (new window,
  keep in dock, minimize, close).
- Built-in app launcher above the dock (favorites, categories, search, power
  actions), opened by the apps button, Meta or Alt+F1, with open/close animation.
- Settings for icon size, spacing, zoom, glass opacity, corner radius, launcher
  size, distance, opacity and background.
- Panel is made transparent and resized automatically to fit the zoom.
