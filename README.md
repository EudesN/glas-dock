# Glasdock

A macOS-style dock for KDE Plasma 6, written as a plain QML plasmoid.

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
- **App launcher** — opens centered above the dock (apps button, Meta or
  Alt+F1): favorites, categories, search and power actions.
- **Configurable** — icon size, spacing, zoom, glass opacity, corner radius,
  launcher size/distance/opacity/animation and more.

## Install

```bash
git clone https://github.com/EudesN/glas-dock.git
kpackagetool6 -t Plasma/Applet -i glas-dock
```

Then add **Glasdock** to a bottom panel (right-click the panel → *Add Widgets…*).
By default the widget makes its panel transparent and resizes it so the zoom has
room to grow. Settings: right-click the dock → *Configure Glasdock…*

To update after pulling new changes:

```bash
kpackagetool6 -t Plasma/Applet -u glas-dock
systemctl --user restart plasma-plasmashell
```

## Known limitations

- The launcher's custom glass background cannot blur the desktop behind it
  (QML has no API for KWin blur). The theme background keeps the blur.
- Icons cannot be reordered by dragging yet.
- Horizontal panels only.

## License

GPL-2.0-or-later. See [LICENSE](LICENSE).
