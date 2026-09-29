#!/usr/bin/env python3
"""Serves the web page (from tools/build-web.sh) to the other devices on my
network, to try it on a phone or tablet.

A Godot web page only runs from HTTPS (or from localhost on the same
machine), so this serves it over HTTPS with a certificate it makes itself
the first time, for this machine's addresses. Browsers don't know that
certificate, so each device warns about it once. Tap Advanced and carry on,
and after that it runs.

  tools/serve_web.py [port]      (8060 unless you say)
"""

import http.server
import os
import socket
import ssl
import subprocess
import sys

PAGE = "/tmp/snapracers-build/web"
CERTS = "/tmp/snapracers-build/cert"


def addresses():
    """This machine's addresses on the network."""
    out = subprocess.run(["hostname", "-I"], capture_output=True, text=True).stdout.split()
    return [a for a in out if "." in a and not a.startswith("172.17.")]


def make_certificate():
    key = os.path.join(CERTS, "key.pem")
    cert = os.path.join(CERTS, "cert.pem")
    if os.path.exists(key) and os.path.exists(cert):
        return cert, key
    os.makedirs(CERTS, exist_ok=True)
    names = ["DNS:localhost", "DNS:" + socket.gethostname(), "IP:127.0.0.1"] + ["IP:" + a for a in addresses()]
    subprocess.run([
        "openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-days", "825",
        "-keyout", key, "-out", cert, "-subj", "/CN=SnapRacers test page",
        "-addext", "subjectAltName=" + ",".join(names),
    ], check=True, capture_output=True)
    return cert, key


class Page(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=PAGE, **kwargs)

    def end_headers(self):
        # A fresh build shows up straight away instead of an old one.
        self.send_header("Cache-Control", "no-cache")
        super().end_headers()

    def log_message(self, format, *args):
        pass


def main():
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8060
    cert, key = make_certificate()
    server = http.server.ThreadingHTTPServer(("0.0.0.0", port), Page)
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.load_cert_chain(cert, key)
    server.socket = context.wrap_socket(server.socket, server_side=True)
    for address in ["localhost"] + addresses():
        print("Serving at https://%s:%d/" % (address, port))
    server.serve_forever()


if __name__ == "__main__":
    main()
