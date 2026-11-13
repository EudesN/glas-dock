# Changelog

## Unreleased

- New panel widgets **Glasplayer** and **Glasweather** (for the top bar or any
  panel), with the same glass panels as the dock.
- Repository reorganized: one folder per widget plus `shared/`, installed with
  `install.sh`.

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
