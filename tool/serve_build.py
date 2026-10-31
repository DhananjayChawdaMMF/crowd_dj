#!/usr/bin/env python3
"""Serves build/web exactly like production hosting would: SPA fallback for deep
links plus the real security and cache headers from tool/hosting.py.

Usage: python3 tool/serve_build.py [port] [--no-csp]
"""
import http.server
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import hosting  # noqa: E402

PORT = int(next((a for a in sys.argv[1:] if a.isdigit()), 8080))
NO_CSP = "--no-csp" in sys.argv
ROOT = os.path.join(os.path.dirname(__file__), "..", "build", "web")


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *a, **k):
        super().__init__(*a, directory=ROOT, **k)

    def do_GET(self):
        path = self.translate_path(self.path.split("?")[0])
        if not os.path.exists(path) and "." not in os.path.basename(self.path):
            self.path = "/index.html"  # deep link
        return super().do_GET()

    do_HEAD = do_GET

    def end_headers(self):
        for k, v in hosting.SECURITY.items():
            if NO_CSP and k == "Content-Security-Policy":
                continue
            if k == "Strict-Transport-Security":
                continue  # plain http locally
            self.send_header(k, v)
        name = os.path.basename(self.path.split("?")[0]) or "index.html"
        first = self.path.lstrip("/").split("/")[0]
        if name in hosting.NO_CACHE_FILES or "." not in name:
            self.send_header("Cache-Control", hosting.NO_CACHE)
        elif first in hosting.STATIC_DIRS:
            self.send_header("Cache-Control", hosting.STATIC)
        super().end_headers()

    def log_message(self, *a):
        pass


if __name__ == "__main__":
    print(f"serving build/web on http://127.0.0.1:{PORT} (CSP {'off' if NO_CSP else 'on'})")
    http.server.ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
