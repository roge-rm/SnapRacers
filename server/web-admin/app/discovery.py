"""Tells phones on the local network the server's there.

The game server already shouts about itself on the local network (the UDP
broadcast every copy of the game listens for, see GameFinder). This adds the
other way phones look: an Android phone with the SnapRacers network plugin
asks for `_snapracers._udp` services over NSD (mDNS), the same thing a phone
hosting a game puts out.

Multicast doesn't cross a Docker bridge network, so this only works with host
networking. When it can't, it says so once and gives up quietly. Typing the
address in still works.
"""

import logging
import os
import socket

LOG = logging.getLogger("snapracers.discovery")

# The same name the Android plugin looks for. If they ever differ, phones stop
# seeing the server in their list and nothing else goes wrong, so it's here in
# one place.
SERVICE_TYPE = "_snapracers._udp.local."


class Advertiser:
    def __init__(self, enabled, name, port, ws_port):
        self.enabled = enabled
        self.name = name
        self.port = port
        self.ws_port = ws_port
        self._zeroconf = None
        self._info = None

    def _service_name(self):
        safe = "".join(c for c in self.name if c.isalnum() or c in " _'") or "Server"
        return f"{safe}.{SERVICE_TYPE}"

    def start(self):
        if not self.enabled or self._zeroconf is not None:
            return
        zeroconf = None
        try:
            from zeroconf import ServiceInfo, Zeroconf

            address = lan_address()
            self._info = ServiceInfo(
                SERVICE_TYPE,
                self._service_name(),
                addresses=[socket.inet_aton(address)],
                port=self.port,
                properties={"name": self.name, "ws": str(self.ws_port)},
            )
            # Only on the address players reach us on. On all of them, it hears
            # its own announcement come back on another one, thinks the name's
            # taken and won't register, which only happens some of the time.
            zeroconf = Zeroconf(interfaces=[address])
            # If the name really is taken, by a second server here, it can
            # rename itself. Phones show whatever name answers.
            zeroconf.register_service(self._info, allow_name_change=True)
            self._zeroconf = zeroconf
            LOG.info("Telling the local network about %s on %s:%s", self._info.name, address, self.port)
        except Exception as error:
            # Some errors have no message at all, so the type goes in too.
            LOG.warning(
                "I can't tell the local network about the server (%s: %s). Players can still type the address.",
                type(error).__name__, error or "no detail",
            )
            if zeroconf is not None:
                try:
                    zeroconf.close()
                except Exception:
                    pass
            self._zeroconf = None
            self._info = None

    def stop(self):
        if self._zeroconf is None:
            return
        try:
            self._zeroconf.unregister_service(self._info)
            self._zeroconf.close()
        except Exception:
            pass
        self._zeroconf = None
        self._info = None

    def update(self, name, port, ws_port):
        """Registers again if the server's name or ports have changed."""
        if not self.enabled:
            return
        if (name, port, ws_port) == (self.name, self.port, self.ws_port) and self._zeroconf is not None:
            return
        self.name, self.port, self.ws_port = name, port, ws_port
        self.stop()
        self.start()


def lan_address():
    """This machine's address on the network players reach it from.

    Asking a UDP socket where it would send picks the right one without
    sending anything, which works even when the host name comes back as
    127.0.1.1.
    """
    override = os.environ.get("ADVERTISE_ADDRESS", "")
    if override:
        return override
    probe = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        probe.connect(("192.0.2.1", 9))
        return probe.getsockname()[0]
    finally:
        probe.close()
