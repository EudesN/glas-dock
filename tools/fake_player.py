#!/usr/bin/env python3
"""Silent fake MPRIS media player for testing Glasplayer / the dock player.

It announces itself on the session bus as "Glasdock Test Player" and pretends to
play a few tracks (no audio). Play/pause, previous/next and seeking work, so the
widgets can be checked without touching a real player.

    python3 tools/fake_player.py [cover.png]

Stop it with Ctrl+C. Needs dbus-python and PyGObject.
"""
import sys
import time

import dbus
import dbus.service
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib

BUS_NAME = "org.mpris.MediaPlayer2.glasdocktest"
PATH = "/org/mpris/MediaPlayer2"
ROOT_IFACE = "org.mpris.MediaPlayer2"
PLAYER_IFACE = "org.mpris.MediaPlayer2.Player"
PROPS_IFACE = "org.freedesktop.DBus.Properties"

TRACKS = [
    ("Golden Hour Drive", "Paper Planets", "Sunset Tapes", 215),
    ("A Much Longer Track Title To Check How Text Is Elided", "The Long Names", "Overflow", 187),
    ("Night Bus", "Quiet Lights", "City Hum", 242),
]


class Player(dbus.service.Object):
    def __init__(self, bus, art_url):
        super().__init__(bus, PATH)
        self.art_url = art_url
        self.index = 0
        self.status = "Playing"
        self.started = time.monotonic()
        self.offset = 0.0

    # --- helpers
    def position_us(self):
        pos = self.offset
        if self.status == "Playing":
            pos += time.monotonic() - self.started
        return int(min(pos, TRACKS[self.index][3]) * 1_000_000)

    def metadata(self):
        title, artist, album, length = TRACKS[self.index]
        md = {
            "mpris:trackid": dbus.ObjectPath(f"/org/glasdock/track/{self.index}"),
            "mpris:length": dbus.Int64(length * 1_000_000),
            "xesam:title": title,
            "xesam:artist": dbus.Array([artist], signature="s"),
            "xesam:album": album,
        }
        if self.art_url:
            md["mpris:artUrl"] = self.art_url
        return dbus.Dictionary(md, signature="sv")

    def player_props(self):
        return {
            "PlaybackStatus": self.status,
            "LoopStatus": "None",
            "Rate": 1.0,
            "Shuffle": False,
            "Metadata": self.metadata(),
            "Volume": 1.0,
            "Position": dbus.Int64(self.position_us()),
            "MinimumRate": 1.0,
            "MaximumRate": 1.0,
            "CanGoNext": True,
            "CanGoPrevious": True,
            "CanPlay": True,
            "CanPause": True,
            "CanSeek": True,
            "CanControl": True,
        }

    def root_props(self):
        return {
            "CanQuit": False,
            "CanRaise": False,
            "HasTrackList": False,
            "Identity": "Glasdock Test Player",
            "DesktopEntry": "",
            "SupportedUriSchemes": dbus.Array([], signature="s"),
            "SupportedMimeTypes": dbus.Array([], signature="s"),
        }

    def changed(self, *names):
        props = self.player_props()
        self.PropertiesChanged(PLAYER_IFACE, {n: props[n] for n in names}, [])

    def set_track(self, index):
        self.index = index % len(TRACKS)
        self.offset = 0.0
        self.started = time.monotonic()
        self.changed("Metadata", "Position")

    # --- org.freedesktop.DBus.Properties
    @dbus.service.method(PROPS_IFACE, in_signature="ss", out_signature="v")
    def Get(self, iface, prop):
        return self.GetAll(iface)[prop]

    @dbus.service.method(PROPS_IFACE, in_signature="s", out_signature="a{sv}")
    def GetAll(self, iface):
        if iface == PLAYER_IFACE:
            return self.player_props()
        if iface == ROOT_IFACE:
            return self.root_props()
        return {}

    @dbus.service.method(PROPS_IFACE, in_signature="ssv")
    def Set(self, iface, prop, value):
        pass

    @dbus.service.signal(PROPS_IFACE, signature="sa{sv}as")
    def PropertiesChanged(self, iface, changed, invalidated):
        pass

    # --- org.mpris.MediaPlayer2
    @dbus.service.method(ROOT_IFACE)
    def Raise(self):
        pass

    @dbus.service.method(ROOT_IFACE)
    def Quit(self):
        pass

    # --- org.mpris.MediaPlayer2.Player
    @dbus.service.method(PLAYER_IFACE)
    def PlayPause(self):
        if self.status == "Playing":
            self.Pause()
        else:
            self.Play()

    @dbus.service.method(PLAYER_IFACE)
    def Play(self):
        if self.status != "Playing":
            self.started = time.monotonic()
            self.status = "Playing"
            self.changed("PlaybackStatus")

    @dbus.service.method(PLAYER_IFACE)
    def Pause(self):
        if self.status == "Playing":
            self.offset += time.monotonic() - self.started
            self.status = "Paused"
            self.changed("PlaybackStatus")

    @dbus.service.method(PLAYER_IFACE)
    def Stop(self):
        self.Pause()

    @dbus.service.method(PLAYER_IFACE)
    def Next(self):
        self.set_track(self.index + 1)

    @dbus.service.method(PLAYER_IFACE)
    def Previous(self):
        self.set_track(self.index - 1)

    @dbus.service.method(PLAYER_IFACE, in_signature="x")
    def Seek(self, offset_us):
        self.offset = self.position_us() / 1_000_000 + offset_us / 1_000_000
        self.started = time.monotonic()
        self.Seeked(dbus.Int64(self.position_us()))

    @dbus.service.method(PLAYER_IFACE, in_signature="ox")
    def SetPosition(self, track_id, position_us):
        self.offset = position_us / 1_000_000
        self.started = time.monotonic()
        self.Seeked(dbus.Int64(self.position_us()))

    @dbus.service.method(PLAYER_IFACE, in_signature="s")
    def OpenUri(self, uri):
        pass

    @dbus.service.signal(PLAYER_IFACE, signature="x")
    def Seeked(self, position):
        pass


def main():
    art = sys.argv[1] if len(sys.argv) > 1 else ""
    art_url = ("file://" + art) if art and not art.startswith("file://") else art
    DBusGMainLoop(set_as_default=True)
    bus = dbus.SessionBus()
    name = dbus.service.BusName(BUS_NAME, bus)  # noqa: F841 (keeps the name)
    Player(bus, art_url)
    print(f"{BUS_NAME} running (Ctrl+C to stop)")
    try:
        GLib.MainLoop().run()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
