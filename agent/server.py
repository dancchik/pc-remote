"""HTTP server that answers phone requests. Run: .venv\\Scripts\\python agent\\server.py"""

import hmac
import json
import logging
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from logging.handlers import RotatingFileHandler
from pathlib import Path

from commands import run_command
from config import Config, load_config
from screenshot import take_screenshot
from status import get_status

LOG_PATH = Path(__file__).resolve().parent.parent / "logs" / "agent.log"

log = logging.getLogger("agent")
config: Config  # set in main()


def setup_logging() -> None:
    """Log to a file (pythonw has no console) and to the console if there is one."""
    LOG_PATH.parent.mkdir(exist_ok=True)
    handlers = [RotatingFileHandler(LOG_PATH, maxBytes=1_000_000, backupCount=2, encoding="utf-8")]
    if logging.lastResort and logging.lastResort.stream:  # None under pythonw
        handlers.append(logging.StreamHandler())
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s", handlers=handlers)


class AgentHandler(BaseHTTPRequestHandler):
    def log_message(self, format: str, *args) -> None:
        # Default implementation writes to stderr, which doesn't exist under pythonw.
        log.info("%s %s", self.address_string(), format % args)

    def _send_json(self, code: int, data: dict) -> None:
        body = json.dumps(data).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _send_png(self, png: bytes) -> None:
        self.send_response(200)
        self.send_header("Content-Type", "image/png")
        self.send_header("Content-Length", str(len(png)))
        self.end_headers()
        self.wfile.write(png)

    def _is_authorized(self) -> bool:
        header = self.headers.get("Authorization", "")
        expected = f"Bearer {config.token}"
        # compare_digest takes the same time for any input, so the token can't be guessed by timing.
        return hmac.compare_digest(header.encode(), expected.encode())

    def do_GET(self) -> None:
        if not self._is_authorized():
            self._send_json(401, {"error": "unauthorized"})
            return

        if self.path == "/status":
            self._send_json(200, get_status())
        elif self.path == "/screenshot":
            self._send_png(take_screenshot())
        else:
            self._send_json(404, {"error": "not found"})

    def do_POST(self) -> None:
        if not self._is_authorized():
            self._send_json(401, {"error": "unauthorized"})
            return

        prefix = "/command/"
        if not self.path.startswith(prefix):
            self._send_json(404, {"error": "not found"})
            return

        body = self._read_json_body()
        if body is None:
            self._send_json(400, {"error": "invalid JSON body"})
            return

        name = self.path[len(prefix):]
        code, data = run_command(name, body, dry_run=config.dry_run)
        self._send_json(code, data)

    def _read_json_body(self) -> dict | None:
        """Return the request body as a dict ({} if empty), or None if it isn't valid JSON."""
        try:
            length = int(self.headers.get("Content-Length", 0))
            if length == 0:
                return {}
            data = json.loads(self.rfile.read(length))
        except (ValueError, json.JSONDecodeError):
            return None
        return data if isinstance(data, dict) else None


class AgentServer(ThreadingHTTPServer):
    def handle_error(self, request, client_address) -> None:
        # Default implementation prints the traceback to stderr; log it instead.
        log.exception("Error while handling request from %s", client_address[0])


def main() -> None:
    global config
    setup_logging()
    try:
        config = load_config()
        server = AgentServer((config.host, config.port), AgentHandler)
    except (SystemExit, OSError) as error:
        log.error("Agent failed to start: %s", error)
        raise SystemExit(1)

    mode = " (dry run: commands are only logged)" if config.dry_run else ""
    log.info("Agent listening on http://%s:%s%s", config.host, config.port, mode)
    server.serve_forever()


if __name__ == "__main__":
    main()
