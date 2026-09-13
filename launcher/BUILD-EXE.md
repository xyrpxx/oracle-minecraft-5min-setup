# Building the optional `MinecraftLauncher.exe` (Windows)

The GUI (`launcher/gui_launcher.py`) runs as a script — no build needed.
This page is only for producing a single-file `.exe` for kids who should
never see a terminal or a `.bat`.

## Recommended: PyInstaller, one folder, no console surprises

On a Windows machine with Python 3.10+:

```bat
pip install pyinstaller
cd oracle-minecraft-5min-setup
pyinstaller --noconfirm --clean --onefile --windowed ^
  --name MinecraftLauncher ^
  launcher\gui_launcher.py
```

Result: `dist\MinecraftLauncher.exe` (~10–15 MB, stdlib-only so nothing
else is bundled). Ship it **next to** the project folder — it locates the
repo from its own path (`..` from `dist\` won't work; place the exe at the
repo root or set the working dir).

> Practical layout: copy `MinecraftLauncher.exe` into the unzipped project
> folder, next to `start-windows.bat`. The launcher finds `setup.sh`,
> `manage.sh`, `.server.conf` and `modpacks/` relative to itself.

## What NOT to do

- Do **not** commit the `.exe` (or `build/`, `dist/`, `*.spec`) to git —
  binaries bloat the repo and trigger antivirus heuristics on every rebuild.
  They are already in `.gitignore`.
- Do **not** use `--onefile` + `--windowed` with an old Python (< 3.10):
  startup gets slow and error popups vanish silently.
- Do **not** ship the exe alone: it is a thin GUI over `setup.sh` /
  `manage.sh` / `utils/*` — without the repo it shows buttons that go
  nowhere. The launcher says so itself when a script is missing.

## Smokescreen-free checklist (before sending the exe to a kid)

1. Double-click → window opens in < 3 s, language auto-detected.
2. Setup tab → `Browse…` picks the `.key`/`.pem`, bad IP shows an error.
3. `Install (guided)` opens a Git Bash window running `setup.sh`.
4. Actions tab on a configured repo shows the `IP:25565` address.
5. `Copy address` pastes correctly into Minecraft → Add Server.

## Antivirus note

Unsigned PyInstaller exes sometimes trip Windows SmartScreen (“Unknown
publisher”). That is expected for a hobby build, not a virus: click
*More info → Run anyway*, or build on the kid's PC directly (`pip install
pyinstaller` takes 1 minute) so nothing is downloaded from strangers.

## macOS / Linux

No build needed: `python3 launcher/gui_launcher.py` (tkinter ships with
CPython; on minimal Linux distros: `sudo apt install python3-tk`).
