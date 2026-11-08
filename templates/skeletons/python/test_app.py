import threading
import urllib.request
from http.server import HTTPServer

from app import Handler


def test_root() -> None:
    server = HTTPServer(("127.0.0.1", 0), Handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        with urllib.request.urlopen(f"http://127.0.0.1:{server.server_port}/") as res:
            assert res.status == 200
            assert res.read() == b"hola\n"
    finally:
        server.shutdown()
