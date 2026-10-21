"""Load agent settings from the .env file in the project root."""

from dataclasses import dataclass
from pathlib import Path

ENV_PATH = Path(__file__).resolve().parent.parent / ".env"


@dataclass(frozen=True)
class Config:
    token: str
    host: str
    port: int
    dry_run: bool


def _read_env_file(path: Path) -> dict[str, str]:
    """Parse simple KEY=VALUE lines, skipping blanks and # comments."""
    values = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip()
    return values


def load_config() -> Config:
    if not ENV_PATH.exists():
        raise SystemExit(f"Missing {ENV_PATH}. Copy .env.example to .env and set AGENT_TOKEN.")

    env = _read_env_file(ENV_PATH)
    token = env.get("AGENT_TOKEN", "")
    # Refuse to start with an empty or placeholder token.
    if len(token) < 16 or token == "change-me":
        raise SystemExit("AGENT_TOKEN in .env is missing or too short (need 16+ characters).")

    return Config(
        token=token,
        host=env.get("AGENT_HOST", "127.0.0.1"),
        port=int(env.get("AGENT_PORT", "8765")),
        dry_run=env.get("AGENT_DRY_RUN", "0") == "1",
    )
