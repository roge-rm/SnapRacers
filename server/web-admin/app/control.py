"""Talking to the game server over its control channel.

The server listens for it on 127.0.0.1 only (see DedicatedServer.command() in
scripts/net/dedicated_server.gd, which has the list of commands). A command is
one line of tab separated words, and the answer is one line of JSON.

Each call is a new connection. The server answers from its own game loop and
then hangs up, so a page that gets stuck can't hold anything up for the next.
"""

import json
import os
import socket
import threading

HOST = os.environ.get("SNAPRACERS_CONTROL_HOST", "127.0.0.1")
PORT = int(os.environ.get("SNAPRACERS_CONTROL_PORT", "27289"))
TIMEOUT = float(os.environ.get("CONTROL_TIMEOUT", "5"))


class ServerDown(Exception):
    """The server isn't answering.

    That's not always something wrong: it's what a restart looks like for a
    few seconds, so every page shows it as the server's state.
    """


class ControlError(Exception):
    """The server answered, and the answer was no."""


def _clean(value):
    # A tab or a new line would split the command, so they become spaces.
    return str(value).replace("\t", " ").replace("\r", " ").replace("\n", " ")


class Control:
    def __init__(self, host=HOST, port=PORT, timeout=TIMEOUT):
        self.host = host
        self.port = port
        self.timeout = timeout
        # One at a time, since the server does them one at a time anyway.
        self._lock = threading.Lock()

    def call(self, *words):
        line = "\t".join(_clean(w) for w in words) + "\n"
        with self._lock:
            try:
                connection = socket.create_connection((self.host, self.port), timeout=self.timeout)
            except ConnectionRefusedError as error:
                raise ServerDown("It isn't running, or it's still starting up.") from error
            except OSError as error:
                raise ServerDown(str(error)) from error
            try:
                connection.sendall(line.encode("utf-8"))
                chunks = []
                while True:
                    chunk = connection.recv(65536)
                    if not chunk:
                        break
                    chunks.append(chunk)
                    if b"\n" in chunk:
                        break
            except socket.timeout as error:
                raise ServerDown("It didn't answer in time.") from error
            finally:
                connection.close()
        raw = b"".join(chunks).split(b"\n", 1)[0]
        if not raw:
            raise ServerDown("It hung up without answering.")
        return json.loads(raw.decode("utf-8"))

    def demand(self, *words):
        """call(), but a no from the server is raised instead of returned."""
        reply = self.call(*words)
        if not reply.get("ok"):
            raise ControlError(reply.get("error", "The server said no."))
        return reply

    # The commands, named the way the pages use them.

    def status(self):
        return self.demand("status")

    def courses(self):
        return self.demand("courses")["courses"]

    def cups(self):
        return self.demand("cups")["cups"]

    def set(self, name, value):
        return self.demand("set", name, value)

    def kick(self, player_id):
        return self.demand("kick", player_id)

    def start(self):
        return self.demand("start")

    def lobby(self):
        return self.demand("lobby")

    def log(self, after=0):
        return self.demand("log", after)["lines"]

    def restart(self):
        return self.demand("restart")
