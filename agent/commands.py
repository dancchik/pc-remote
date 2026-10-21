"""Commands from the phone: lock, sleep, restart, shutdown, run a program."""

import ctypes
import logging
import os
import subprocess
import threading

# Dangerous commands need {"confirm": true} in the request.
NEEDS_CONFIRM = {"restart", "shutdown", "run"}

# Delay before power actions, so the HTTP response reaches the phone first.
ACTION_DELAY_SECONDS = 1.0

log = logging.getLogger("agent")


def _lock() -> None:
    ctypes.windll.user32.LockWorkStation()


def _sleep() -> None:
    # SetSuspendState(hibernate=False, force=True, disable_wake_events=False)
    ctypes.windll.powrprof.SetSuspendState(0, 1, 0)


def _restart() -> None:
    subprocess.run(["shutdown", "/r", "/t", "0"], creationflags=subprocess.CREATE_NO_WINDOW)


def _shutdown() -> None:
    subprocess.run(["shutdown", "/s", "/t", "0"], creationflags=subprocess.CREATE_NO_WINDOW)


POWER_ACTIONS = {
    "lock": _lock,
    "sleep": _sleep,
    "restart": _restart,
    "shutdown": _shutdown,
}


def _run_program(body: dict, dry_run: bool) -> tuple[int, dict]:
    """Start a program, like typing it into Win+R: "notepad", "chrome", a full path, a file or a URL."""
    program = body.get("program")
    arguments = body.get("arguments", "")
    if not isinstance(program, str) or not program.strip() or not isinstance(arguments, str):
        return 400, {"error": 'expected {"program": "<name or path>", "arguments": "<optional string>"}'}

    if dry_run:
        log.info("[dry run] would run: %s %s", program, arguments)
        return 200, {"ok": True, "command": "run", "program": program, "dry_run": True}

    log.info("Running: %s %s", program, arguments)
    try:
        # startfile uses the Windows shell, so it finds apps like "chrome" without a full path.
        os.startfile(program, arguments=arguments)
    except OSError as error:
        return 400, {"error": f"failed to start: {error.strerror or error}", "program": program}
    return 200, {"ok": True, "command": "run", "program": program, "dry_run": False}


def run_command(name: str, body: dict, dry_run: bool) -> tuple[int, dict]:
    """Validate and execute a command. Returns (http_code, response_body)."""
    if name not in POWER_ACTIONS and name != "run":
        return 404, {"error": f"unknown command: {name}"}
    if name in NEEDS_CONFIRM and body.get("confirm") is not True:
        return 400, {"error": "confirmation required", "command": name}

    if name == "run":
        return _run_program(body, dry_run)

    if dry_run:
        log.info("[dry run] would execute: %s", name)
    else:
        log.info("Executing: %s", name)
        threading.Timer(ACTION_DELAY_SECONDS, POWER_ACTIONS[name]).start()
    return 200, {"ok": True, "command": name, "dry_run": dry_run}
