#!/usr/bin/env python3
"""
Wachesaw Dev Server — serves the web build + live data files for hot-reload.

The web build's .pck contains a snapshot of data/ at build time, but this server
also serves data/ files live from disk at /data/*, so the MapWatcher can poll
for changes without rebuilding.

When --watch is provided, the server injects a config script into index.html
so the game auto-starts watching the specified file.

Usage:
    python3 tools/dev_server.py [port] [--watch=story/chapter_1.json] [--puzzle=ch1_p03]
"""

import http.server
import json
import os
import re
import sys
import time
import email.utils
from pathlib import Path
from urllib.parse import urlparse, parse_qs

# Resolve project root (parent of tools/)
PROJECT_ROOT = Path(__file__).resolve().parent.parent
WEB_BUILD = PROJECT_ROOT / "builds" / "web"
DATA_DIR = PROJECT_ROOT / "data"

# Parse args
PORT = 8000
WATCH_PATH = ""
WATCH_PUZZLE = ""

for arg in sys.argv[1:]:
    if arg.startswith("--watch="):
        WATCH_PATH = arg[len("--watch="):]
    elif arg.startswith("--puzzle="):
        WATCH_PUZZLE = arg[len("--puzzle="):]
    elif arg.isdigit():
        PORT = int(arg)


def _build_config_script() -> str:
    """Build a <script> tag that sets window.WACHESAW_WATCH before the engine loads."""
    if not WATCH_PATH:
        return ""
    config = {"watch": WATCH_PATH}
    if WATCH_PUZZLE:
        config["puzzle"] = WATCH_PUZZLE
    return f'<script>window.WACHESAW_WATCH={json.dumps(config)};</script>\n'


# Cache the patched index.html (rebuilt on each request to stay current)
_CONFIG_SCRIPT = _build_config_script()


class DevHandler(http.server.SimpleHTTPRequestHandler):
    """Serves web build files + live data files from disk."""

    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(WEB_BUILD), **kwargs)

    def do_GET(self):
        parsed = urlparse(self.path)

        # /data/* → serve live from project data/ directory
        if parsed.path.startswith("/data/"):
            self._serve_data_file(parsed.path)
            return

        # index.html (or /) → inject watch config script
        if _CONFIG_SCRIPT and parsed.path in ("/", "/index.html"):
            self._serve_patched_index()
            return

        # Everything else → serve from builds/web/
        super().do_GET()

    def _serve_patched_index(self):
        """Serve index.html with watch config injected before </head>."""
        index_path = WEB_BUILD / "index.html"
        if not index_path.is_file():
            self.send_error(404, "index.html not found")
            return

        html = index_path.read_text()
        # Inject config script right before </head>
        html = html.replace("</head>", _CONFIG_SCRIPT + "</head>", 1)
        content = html.encode("utf-8")

        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(content)))
        self.send_header("Cache-Control", "no-cache, no-store, must-revalidate")
        self.end_headers()
        self.wfile.write(content)

    def _serve_data_file(self, url_path: str):
        # Map /data/story/chapter_1.json → PROJECT_ROOT/data/story/chapter_1.json
        rel_path = url_path.lstrip("/")
        file_path = PROJECT_ROOT / rel_path

        # Security: prevent path traversal
        try:
            file_path = file_path.resolve()
            if not str(file_path).startswith(str(DATA_DIR.resolve())):
                self.send_error(403, "Forbidden")
                return
        except (ValueError, OSError):
            self.send_error(400, "Bad path")
            return

        if not file_path.is_file():
            self.send_error(404, f"Not found: {rel_path}")
            return

        try:
            content = file_path.read_bytes()
        except OSError as e:
            self.send_error(500, str(e))
            return

        # Send with modification time so the client can detect changes
        mtime = file_path.stat().st_mtime
        last_modified = email.utils.formatdate(mtime, usegmt=True)

        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(content)))
        self.send_header("Last-Modified", last_modified)
        self.send_header("Cache-Control", "no-cache, no-store, must-revalidate")
        self.end_headers()
        self.wfile.write(content)

    def end_headers(self):
        # Cross-Origin-Isolation headers (required for SharedArrayBuffer/threads)
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Access-Control-Allow-Origin", "*")
        super().end_headers()

    def log_message(self, format, *args):
        # Color-code data file requests for visibility
        msg = format % args
        if "/data/" in msg:
            sys.stderr.write(f"\033[36m{self.log_date_time_string()} {msg}\033[0m\n")
        else:
            sys.stderr.write(f"{self.log_date_time_string()} {msg}\n")


def main():
    if not WEB_BUILD.exists():
        print(f"Error: Web build not found at {WEB_BUILD}")
        print("Run 'just build-web-debug' first.")
        sys.exit(1)

    # Get LAN IP for convenience
    import socket
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        lan_ip = s.getsockname()[0]
        s.close()
    except Exception:
        lan_ip = "localhost"

    server = http.server.HTTPServer(("0.0.0.0", PORT), DevHandler)

    print(f"╔══════════════════════════════════════════════════╗")
    print(f"║  Wachesaw Dev Server                            ║")
    print(f"╠══════════════════════════════════════════════════╣")
    print(f"║  Open:  http://localhost:{PORT:<5}                ║")
    if WATCH_PATH:
        label = WATCH_PATH
        if WATCH_PUZZLE:
            label += f" #{WATCH_PUZZLE}"
        print(f"║  Watch: {label:<40} ║")
    else:
        print(f"║  (no watch configured)                           ║")
    print(f"║                                                  ║")
    print(f"║  Edit JSON → save → puzzle reloads in browser.   ║")
    print(f"╚══════════════════════════════════════════════════╝")
    print()

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down.")
        server.shutdown()


if __name__ == "__main__":
    main()
