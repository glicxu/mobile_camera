#!/usr/bin/env python3
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from pathlib import Path
from urllib.parse import parse_qs, unquote, urlparse
import mimetypes
import os


REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_HOST = "127.0.0.1"
DEFAULT_PORT = 8765


class PrototypeViewerHandler(SimpleHTTPRequestHandler):
    def translate_path(self, path):
        parsed = urlparse(path)
        if parsed.path == "/":
            return str(REPO_ROOT / "docs" / "prototype_1_image_viewer.html")
        if parsed.path == "/analysis.json":
            return str(REPO_ROOT / "docs" / "prototype_1_download_image_analysis.json")
        return str(REPO_ROOT / parsed.path.lstrip("/"))

    def do_GET(self):
        parsed = urlparse(self.path)
        if parsed.path == "/image":
            query = parse_qs(parsed.query)
            raw_path = query.get("path", [""])[0]
            image_path = Path(unquote(raw_path)).expanduser().resolve()
            self.serve_file(image_path)
            return

        super().do_GET()

    def serve_file(self, path):
        if not path.exists() or not path.is_file():
            self.send_error(404, "File not found")
            return

        content_type = mimetypes.guess_type(str(path))[0] or "application/octet-stream"
        self.send_response(200)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(path.stat().st_size))
        self.end_headers()
        with path.open("rb") as handle:
            self.wfile.write(handle.read())


def main():
    port = int(os.environ.get("PORT", DEFAULT_PORT))
    server = ThreadingHTTPServer((DEFAULT_HOST, port), PrototypeViewerHandler)
    print(f"Prototype 1 viewer: http://{DEFAULT_HOST}:{port}")
    server.serve_forever()


if __name__ == "__main__":
    main()
