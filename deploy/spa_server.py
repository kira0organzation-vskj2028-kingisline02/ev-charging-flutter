import http.server
import socketserver
import os
import sys

PORT = 4001
DIRECTORY = os.path.join(os.path.dirname(__file__), "web")

class SPAServer(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIRECTORY, **kwargs)

    def do_GET(self):
        # Serve existing static files, otherwise fallback to index.html for SPA routing
        path = self.translate_path(self.path)
        if not os.path.exists(path) or os.path.isdir(path):
            index_path = os.path.join(DIRECTORY, "index.html")
            if os.path.exists(index_path):
                self.path = "/index.html"
        return super().do_GET()

if __name__ == "__main__":
    if not os.path.exists(DIRECTORY):
        print(f"Error: {DIRECTORY} not found!")
        sys.exit(1)

    with socketserver.TCPServer(("", PORT), SPAServer) as httpd:
        print(f"ChargeBridge Frontend SPA running on http://0.0.0.0:{PORT}")
        print(f"Serving directory: {DIRECTORY}")
        print(f"Target for Cloudflare Tunnel: http://localhost:{PORT}")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nShutting down server.")

