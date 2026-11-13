# Changelog

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
