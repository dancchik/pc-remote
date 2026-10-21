# PC Remote

Control your Windows PCs from an Android phone: see if a PC is online, check CPU and RAM, take a screenshot, lock it, put it to sleep, restart, shut down or start a program.

Two parts:

- `agent/` — small Python HTTP server that runs in the background on each PC (no console window, starts at logon via Task Scheduler)
- `app/` — Flutter app for Android with a list of your PCs

The phone talks to the agent over [Tailscale](https://tailscale.com), so there's no port forwarding and no public server. Every request needs a token (`Authorization: Bearer <token>`), and dangerous commands ask for confirmation in the app.

## Agent setup (Windows)

```
python -m venv .venv
.venv\Scripts\pip install -r agent\requirements.txt
copy .env.example .env
```

Put a random token in `.env` (`python -c "import secrets; print(secrets.token_urlsafe(32))"`) and set `AGENT_HOST` to the PC's Tailscale IP. Then:

```
powershell -ExecutionPolicy Bypass -File scripts\install-autostart.ps1
```

`scripts\uninstall-autostart.ps1` removes the task. Set `AGENT_DRY_RUN=1` to only log power commands while testing.

## API

- `GET /status` — online, CPU, RAM
- `GET /screenshot` — PNG of the screen
- `POST /command/<name>` — `lock`, `sleep`, `restart`, `shutdown`, `run`. `restart`, `shutdown` and `run` need `{"confirm": true}` in the body

## App

```
cd app
flutter run
```

Add a PC with its Tailscale address and token. Build an APK with `flutter build apk`.
