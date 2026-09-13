#!/usr/bin/env python3
"""Minecraft Server Launcher — clean GUI over the bash scripts.

Runs on the user's PC. Never duplicates setup.sh logic: every action opens
Git Bash on the matching script (setup.sh / manage.sh / utils/*), which stay
the single source of truth.

Windows: double-click launcher/launch-gui.bat (uses the Python that ships
with Git for Windows, or any installed Python 3 with tkinter).
macOS/Linux: python3 launcher/gui_launcher.py

Stdlib only: tkinter, subprocess, json, os, re, shutil, webbrowser.
"""
import json
import os
import re
import shutil
import subprocess
import sys
import webbrowser

try:
    import tkinter as tk
    from tkinter import filedialog, messagebox, ttk
except ImportError:  # pragma: no cover
    sys.stderr.write("This launcher needs tkinter (ships with CPython).\n")
    sys.exit(1)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONF_PATH = os.path.join(ROOT, ".server.conf")
GIT_REPO = "https://github.com/xyrpxx/oracle-minecraft-5min-setup"
GUIDE_EN = "docs/en/getting-started.md"
GUIDE_FR = "docs/guide-debutant-fr.md"
VCN_EN = "docs/en/vcn-setup.md"
VCN_FR = "docs/oci-vcn-config.md"
STEP_ORDER = ["account", "vm", "key_ip", "ready"]


def detect_lang():
    for var in ("LC_ALL", "LANG", "LANGUAGE"):
        val = os.environ.get(var, "")
        if val.lower().startswith("fr"):
            return "fr"
    try:
        import locale

        loc = (locale.getdefaultlocale()[0] or "").lower()
        if loc.startswith("fr"):
            return "fr"
    except Exception:
        pass
    return "en"


STRINGS = {
    "en": {
        "title": "Minecraft Server Launcher",
        "subtitle": "Your own server — free, forever (Oracle Always Free)",
        "tab_setup": "Setup",
        "tab_actions": "Actions",
        "tab_checklist": "Checklist",
        "lang_label": "Language:",
        "s1": "1 · Your server",
        "ip": "VM public IP",
        "ip_hint": "e.g. 129.213.56.123 (Compute → Instances → Public IP)",
        "key": "SSH private key",
        "browse": "Browse…",
        "key_hint": "The “Save Private Key” file from VM creation",
        "user": "SSH user",
        "s2": "2 · Server options",
        "stype": "Type",
        "mcver": "Minecraft version",
        "ram": "RAM (GB)",
        "players": "Players",
        "crafty": "Install the Crafty web panel",
        "modpack": "Modpack",
        "mp_none": "none (Forge / Fabric / Vanilla above)",
        "s3": "3 · Install",
        "install": "Install / Repair (guided)",
        "install_hint": "Opens Git Bash on setup.sh — it asks the rest and installs.",
        "expert": "Expert mode (uses the values above, no questions)",
        "dryrun": "Simulation only (dry-run, changes nothing)",
        "copyright_parent": "A parent is needed for steps 1–3 (account, card, phone).",
        "addr": "Server address:",
        "not_configured": "Not installed yet — run the install first.",
        "open_panel": "Open Crafty panel",
        "copy_addr": "Copy address",
        "copied": "Address copied.",
        "manage": "Daily menu (status, backup, mods…)",
        "manage_hint": "Opens Git Bash on manage.sh — one numbered menu for everything.",
        "backup": "Back up now",
        "console_op": "Make me admin (op)",
        "op_name": "In-game name",
        "op_hint": "Join the server once first, then click.",
        "monitor": "Status",
        "hardening": "Harden SSH",
        "whitelist": "Whitelist…",
        "wl_action": "Action (add / remove / list)",
        "wl_name": "Player name",
        "run": "Run",
        "need_conf": "Install the server first (Setup tab).",
        "need_bash": "Git Bash not found. Install Git for Windows:\nhttps://git-scm.com/download/win",
        "need_key": "Pick a valid SSH private key file first.",
        "bad_ip": "That IP address does not look valid (e.g. 129.213.56.123).",
        "open_guide": "Beginner guide",
        "open_vcn": "Open-the-ports guide",
        "cl_title": "Before you click Install",
        "cl_parent": "☐ With a parent: Oracle account created (18+, card = identity check only, decline “Pay As You Go”) [parent]",
        "cl_vm": "☐ VM created: Ubuntu 22.04/24.04, Ampere A1.Flex, 2 OCPU / 12 GB, keys saved (private key kept safe) [parent + you]",
        "cl_ip": "☐ I have the Public IP and the private key file on this PC [you]",
        "cl_ports": "☐ After install: open TCP/UDP 25565 + TCP 8443 in the VCN (guide in Actions tab) [you]",
        "cl_note": "Tick = done. The launcher does not verify these — they happen in the Oracle console.",
        "done": "done",
        "running": "Running in Git Bash — follow the terminal window…",
        "finished_ok": "Finished (exit 0).",
        "finished_err": "Ended with code {code} — read the terminal window above.",
        "confirm_title": "Confirm",
    },
    "fr": {
        "title": "Assistant Serveur Minecraft",
        "subtitle": "Ton serveur à toi — gratuit, pour toujours (Oracle Always Free)",
        "tab_setup": "Installation",
        "tab_actions": "Actions",
        "tab_checklist": "Checklist",
        "lang_label": "Langue :",
        "s1": "1 · Ton serveur",
        "ip": "IP publique de la VM",
        "ip_hint": "ex. 129.213.56.123 (Compute → Instances → Public IP)",
        "key": "Clé privée SSH",
        "browse": "Parcourir…",
        "key_hint": "Le fichier « Save Private Key » téléchargé à la création",
        "user": "Utilisateur SSH",
        "s2": "2 · Options du serveur",
        "stype": "Type",
        "mcver": "Version Minecraft",
        "ram": "RAM (Go)",
        "players": "Joueurs",
        "crafty": "Installer le panel web Crafty",
        "modpack": "Modpack",
        "mp_none": "aucun (Forge / Fabric / Vanilla ci-dessus)",
        "s3": "3 · Installer",
        "install": "Installer / Réparer (guidé)",
        "install_hint": "Ouvre Git Bash sur setup.sh — il pose le reste et installe.",
        "expert": "Mode expert (utilise les valeurs ci-dessus, sans questions)",
        "dryrun": "Simulation seule (dry-run, ne change rien)",
        "copyright_parent": "Un parent est nécessaire pour les étapes 1–3 (compte, carte, téléphone).",
        "addr": "Adresse du serveur :",
        "not_configured": "Pas encore installé — lance l'installation d'abord.",
        "open_panel": "Ouvrir le panel Crafty",
        "copy_addr": "Copier l'adresse",
        "copied": "Adresse copiée.",
        "manage": "Menu quotidien (état, sauvegarde, mods…)",
        "manage_hint": "Ouvre Git Bash sur manage.sh — un menu à numéros pour tout.",
        "backup": "Sauvegarder maintenant",
        "console_op": "Me rendre admin (op)",
        "op_name": "Pseudo en jeu",
        "op_hint": "Rejoins d'abord le serveur une fois, puis clique.",
        "monitor": "État",
        "hardening": "Durcir SSH",
        "whitelist": "Whitelist…",
        "wl_action": "Action (add / remove / list)",
        "wl_name": "Pseudo du joueur",
        "run": "Lancer",
        "need_conf": "Installe d'abord le serveur (onglet Installation).",
        "need_bash": "Git Bash introuvable. Installe Git pour Windows :\nhttps://git-scm.com/download/win",
        "need_key": "Choisis d'abord un fichier de clé privée SSH valide.",
        "bad_ip": "Cette adresse IP semble invalide (ex. 129.213.56.123).",
        "open_guide": "Guide débutant",
        "open_vcn": "Guide d'ouverture des ports",
        "cl_title": "Avant de cliquer Installer",
        "cl_parent": "☐ Avec un parent : compte Oracle créé (18+, carte = simple vérification, refuser « Pay As You Go ») [parent]",
        "cl_vm": "☐ VM créée : Ubuntu 22.04/24.04, Ampere A1.Flex, 2 OCPU / 12 Go, clés sauvegardées (clé privée en lieu sûr) [parent + toi]",
        "cl_ip": "☐ J'ai l'IP publique et le fichier de clé privée sur ce PC [toi]",
        "cl_ports": "☐ Après l'install : ouvrir TCP/UDP 25565 + TCP 8443 dans le VCN (guide dans l'onglet Actions) [toi]",
        "cl_note": "Cocher = fait. Le lanceur ne vérifie pas ces étapes — elles se passent dans la console Oracle.",
        "done": "fait",
        "running": "Exécution dans Git Bash — suis la fenêtre du terminal…",
        "finished_ok": "Terminé (code 0).",
        "finished_err": "Terminé avec le code {code} — lis la fenêtre du terminal ci-dessus.",
        "confirm_title": "Confirmer",
    },
}


def find_git_bash():
    candidates = [
        r"C:\Program Files\Git\bin\bash.exe",
        r"C:\Program Files (x86)\Git\bin\bash.exe",
        os.path.expandvars(r"%LOCALAPPDATA%\Programs\Git\bin\bash.exe"),
        os.path.join(ROOT, "..", "Git", "bin", "bash.exe"),
    ]
    for path in candidates:
        if path and os.path.isfile(path):
            return os.path.abspath(path)
    found = shutil.which("bash")
    if found and "git" in found.lower().replace("/", "\\"):
        return found
    return None


def shell_quote(value):
    return "'" + str(value).replace("'", "'\\''") + "'"


def read_conf():
    """Parse .server.conf (KEY='quoted value' lines) without executing it."""
    conf = {}
    if not os.path.isfile(CONF_PATH):
        return conf
    for line in open(CONF_PATH, encoding="utf-8", errors="replace"):
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, val = line.partition("=")
        key = key.strip()
        val = val.strip()
        if len(val) >= 2 and val[0] == val[-1] == "'":
            val = val[1:-1].replace("'\\''", "'")
        elif len(val) >= 2 and val[0] == val[-1] == '"':
            val = val[1:-1]
        conf[key] = val
    return conf


def valid_ipv4(ip):
    parts = ip.strip().split(".")
    if len(parts) != 4:
        return False
    for part in parts:
        if not part.isdigit():
            return False
        if not 0 <= int(part) <= 255:
            return False
        if len(part) > 1 and part.startswith("0"):
            return False
    return True


def valid_mc_version(version):
    return re.match(r"^[0-9]+\.[0-9]+(\.[0-9]+)?$", version.strip()) is not None


def load_modpacks():
    manifest = os.path.join(ROOT, "modpacks", "manifest.json")
    try:
        with open(manifest, encoding="utf-8") as fh:
            data = json.load(fh)
        return [entry["id"] for entry in data.get("modpacks", []) if "id" in entry]
    except (OSError, ValueError, KeyError):
        return []


class Launcher(tk.Tk):
    def __init__(self):
        super().__init__()
        self.lang = detect_lang()
        self.t = STRINGS[self.lang]
        self.conf = read_conf()
        self.modpacks = load_modpacks()
        self.bash = find_git_bash()
        self.title("Minecraft Server Launcher")
        self.geometry("560x640")
        self.minsize(520, 600)
        self._build()

    # -- language ------------------------------------------------------
    def set_lang(self, lang):
        self.lang = lang
        self.t = STRINGS[lang]
        for widget in (self.tab_setup, self.tab_actions, self.tab_check):
            for child in widget.winfo_children():
                child.destroy()
        self._build_setup()
        self._build_actions()
        self._build_checklist()
        self.refresh_chrome()
        self.title(self.t["title"])

    # -- layout --------------------------------------------------------
    def _build(self):
        top = ttk.Frame(self, padding=(14, 10, 14, 4))
        top.pack(fill="x")
        title_row = ttk.Frame(top)
        title_row.pack(fill="x")
        ttk.Label(title_row, text="⛏", font=("", 20)).pack(side="left")
        head = ttk.Frame(title_row)
        head.pack(side="left", padx=(8, 0))
        self.title_var = tk.StringVar(value=self.t["title"])
        self.sub_var = tk.StringVar(value=self.t["subtitle"])
        ttk.Label(head, textvariable=self.title_var, font=("", 13, "bold")).pack(anchor="w")
        ttk.Label(head, textvariable=self.sub_var, font=("", 9)).pack(anchor="w")
        lang_row = ttk.Frame(title_row)
        lang_row.pack(side="right")
        ttk.Label(lang_row, text=self.t["lang_label"]).pack(side="left")
        self.lang_var = tk.StringVar(value=self.lang)
        lang_box = ttk.Combobox(
            lang_row, textvariable=self.lang_var, values=["en", "fr"],
            width=4, state="readonly",
        )
        lang_box.pack(side="left", padx=(4, 0))
        lang_box.bind("<<ComboboxSelected>>", lambda _e: self.set_lang(self.lang_var.get()))
        self.lang_combo = lang_box
        self.lang_label = lang_row.winfo_children()[0]

        self.notebook = ttk.Notebook(self)
        self.notebook.pack(fill="both", expand=True, padx=10, pady=6)
        self.tab_setup = ttk.Frame(self.notebook, padding=12)
        self.tab_actions = ttk.Frame(self.notebook, padding=12)
        self.tab_check = ttk.Frame(self.notebook, padding=12)
        self.notebook.add(self.tab_setup, text=self.t["tab_setup"])
        self.notebook.add(self.tab_actions, text=self.t["tab_actions"])
        self.notebook.add(self.tab_check, text=self.t["tab_checklist"])
        self._build_setup()
        self._build_actions()
        self._build_checklist()

        self.status_var = tk.StringVar()
        ttk.Label(self, textvariable=self.status_var, padding=(14, 2),
                  font=("", 9)).pack(fill="x")

    def refresh_chrome(self):
        self.title_var.set(self.t["title"])
        self.sub_var.set(self.t["subtitle"])
        self.notebook.tab(0, text=self.t["tab_setup"])
        self.notebook.tab(1, text=self.t["tab_actions"])
        self.notebook.tab(2, text=self.t["tab_checklist"])
        self.lang_label.config(text=self.t["lang_label"])
        self.title(self.t["title"])

    # -- setup tab -----------------------------------------------------
    def _build_setup(self):
        t = self.t
        row = 0
        ttk.Label(self.tab_setup, text=t["s1"], font=("", 10, "bold")).grid(
            row=row, column=0, columnspan=3, sticky="w", pady=(0, 4))
        row += 1
        ttk.Label(self.tab_setup, text=t["ip"]).grid(row=row, column=0, sticky="w")
        self.ip_var = tk.StringVar(value=self.conf.get("ORACLE_IP", ""))
        ttk.Entry(self.tab_setup, textvariable=self.ip_var, width=22).grid(
            row=row, column=1, sticky="ew", padx=(6, 0))
        row += 1
        ttk.Label(self.tab_setup, text=t["ip_hint"], font=("", 8),
                  foreground="gray").grid(row=row, column=0, columnspan=3,
                                          sticky="w", pady=(0, 6))
        row += 1
        ttk.Label(self.tab_setup, text=t["key"]).grid(row=row, column=0, sticky="w")
        self.key_var = tk.StringVar(value=self.conf.get("SSH_KEY_PATH", ""))
        ttk.Entry(self.tab_setup, textvariable=self.key_var, width=30).grid(
            row=row, column=1, sticky="ew", padx=(6, 0))
        ttk.Button(self.tab_setup, text=t["browse"],
                   command=self.pick_key).grid(row=row, column=2, padx=(6, 0))
        row += 1
        ttk.Label(self.tab_setup, text=t["key_hint"], font=("", 8),
                  foreground="gray").grid(row=row, column=0, columnspan=3,
                                          sticky="w", pady=(0, 6))
        row += 1
        ttk.Label(self.tab_setup, text=t["user"]).grid(row=row, column=0, sticky="w")
        self.user_var = tk.StringVar(value=self.conf.get("SSH_USER", "ubuntu"))
        ttk.Entry(self.tab_setup, textvariable=self.user_var, width=12).grid(
            row=row, column=1, sticky="w", padx=(6, 0))
        row += 1
        ttk.Separator(self.tab_setup).grid(row=row, column=0, columnspan=3,
                                          sticky="ew", pady=10)
        row += 1
        ttk.Label(self.tab_setup, text=t["s2"], font=("", 10, "bold")).grid(
            row=row, column=0, columnspan=3, sticky="w", pady=(0, 4))
        row += 1
        ttk.Label(self.tab_setup, text=t["stype"]).grid(row=row, column=0, sticky="w")
        self.type_var = tk.StringVar(value=self.conf.get("SERVER_TYPE", "forge"))
        ttk.Combobox(self.tab_setup, textvariable=self.type_var,
                     values=["vanilla", "forge", "fabric", "modpack"],
                     width=10, state="readonly").grid(row=row, column=1,
                                                      sticky="w", padx=(6, 0))
        row += 1
        ttk.Label(self.tab_setup, text=t["mcver"]).grid(row=row, column=0, sticky="w")
        self.mc_var = tk.StringVar(value=self.conf.get("MC_VERSION", "1.20.1"))
        ttk.Entry(self.tab_setup, textvariable=self.mc_var, width=10).grid(
            row=row, column=1, sticky="w", padx=(6, 0))
        row += 1
        ttk.Label(self.tab_setup, text=t["ram"]).grid(row=row, column=0, sticky="w")
        self.ram_var = tk.StringVar(value=self.conf.get("RAM_GB", "8"))
        ttk.Combobox(self.tab_setup, textvariable=self.ram_var,
                     values=["2", "3", "4", "6", "8"],
                     width=5, state="readonly").grid(row=row, column=1,
                                                     sticky="w", padx=(6, 0))
        row += 1
        ttk.Label(self.tab_setup, text=t["players"]).grid(row=row, column=0, sticky="w")
        self.players_var = tk.StringVar(value="10")
        ttk.Entry(self.tab_setup, textvariable=self.players_var, width=6).grid(
            row=row, column=1, sticky="w", padx=(6, 0))
        row += 1
        self.crafty_var = tk.BooleanVar(value=True)
        ttk.Checkbutton(self.tab_setup, text=t["crafty"],
                        variable=self.crafty_var).grid(row=row, column=0,
                                                       columnspan=3, sticky="w")
        row += 1
        ttk.Label(self.tab_setup, text=t["modpack"]).grid(row=row, column=0, sticky="w")
        saved_mp = self.conf.get("MODPACK", "none")
        if saved_mp not in self.modpacks:
            saved_mp = t["mp_none"]
        self.mp_var = tk.StringVar(value=saved_mp)
        ttk.Combobox(self.tab_setup, textvariable=self.mp_var,
                     values=[t["mp_none"]] + self.modpacks,
                     width=22, state="readonly").grid(row=row, column=1,
                                                      columnspan=2, sticky="w",
                                                      padx=(6, 0))
        row += 1
        ttk.Separator(self.tab_setup).grid(row=row, column=0, columnspan=3,
                                          sticky="ew", pady=10)
        row += 1
        ttk.Label(self.tab_setup, text=t["s3"], font=("", 10, "bold")).grid(
            row=row, column=0, columnspan=3, sticky="w", pady=(0, 4))
        row += 1
        ttk.Button(self.tab_setup, text="▶  " + t["install"],
                   command=self.do_install).grid(row=row, column=0,
                                                 columnspan=3, sticky="ew")
        row += 1
        ttk.Label(self.tab_setup, text=t["install_hint"], font=("", 8),
                  foreground="gray").grid(row=row, column=0, columnspan=3,
                                          sticky="w", pady=(0, 4))
        row += 1
        btn_row = ttk.Frame(self.tab_setup)
        btn_row.grid(row=row, column=0, columnspan=3, sticky="ew")
        ttk.Button(btn_row, text=t["expert"],
                   command=self.do_expert).pack(side="left", expand=True,
                                                fill="x", padx=(0, 4))
        ttk.Button(btn_row, text=t["dryrun"],
                   command=self.do_dryrun).pack(side="left", expand=True,
                                                fill="x", padx=(4, 0))
        row += 1
        ttk.Label(self.tab_setup, text="👨‍👩‍👧 " + t["copyright_parent"], font=("", 8),
                  foreground="gray", wraplength=480).grid(
            row=row, column=0, columnspan=3, sticky="w", pady=(6, 0))
        self.tab_setup.columnconfigure(1, weight=1)

    # -- actions tab ---------------------------------------------------
    def _build_actions(self):
        t = self.t
        self.addr_var = tk.StringVar(value=self.server_address() or t["not_configured"])
        ttk.Label(self.tab_actions, text=t["addr"], font=("", 10, "bold")).pack(anchor="w")
        ttk.Label(self.tab_actions, textvariable=self.addr_var, font=("", 12)).pack(
            anchor="w", pady=(0, 4))
        addr_row = ttk.Frame(self.tab_actions)
        addr_row.pack(fill="x", pady=(0, 8))
        ttk.Button(addr_row, text=t["copy_addr"],
                   command=self.copy_address).pack(side="left", padx=(0, 4))
        ttk.Button(addr_row, text=t["open_panel"],
                   command=self.open_panel).pack(side="left")
        ttk.Separator(self.tab_actions).pack(fill="x", pady=6)
        ttk.Button(self.tab_actions, text="▶  " + t["manage"],
                   command=lambda: self.run_script("manage.sh", ["--lang", self.lang])
                   ).pack(fill="x")
        ttk.Label(self.tab_actions, text=t["manage_hint"], font=("", 8),
                  foreground="gray").pack(anchor="w", pady=(0, 6))
        grid = ttk.Frame(self.tab_actions)
        grid.pack(fill="x")
        ttk.Button(grid, text=t["monitor"],
                   command=lambda: self.run_script("utils/monitor.sh", [])
                   ).grid(row=0, column=0, sticky="ew", padx=(0, 4), pady=2)
        ttk.Button(grid, text=t["backup"],
                   command=lambda: self.run_script("utils/backup.sh", [])
                   ).grid(row=0, column=1, sticky="ew", padx=(4, 0), pady=2)
        ttk.Button(grid, text=t["hardening"],
                   command=lambda: self.run_script("security/hardening.sh", [])
                   ).grid(row=1, column=0, sticky="ew", padx=(0, 4), pady=2)
        ttk.Button(grid, text=t["whitelist"],
                   command=self.whitelist_dialog).grid(row=1, column=1,
                                                       sticky="ew", padx=(4, 0),
                                                       pady=2)
        grid.columnconfigure(0, weight=1)
        grid.columnconfigure(1, weight=1)
        op = ttk.LabelFrame(self.tab_actions, text=t["console_op"], padding=8)
        op.pack(fill="x", pady=(8, 0))
        ttk.Label(op, text=t["op_name"]).pack(anchor="w")
        self.op_var = tk.StringVar()
        ttk.Entry(op, textvariable=self.op_var, width=20).pack(anchor="w", pady=2)
        ttk.Label(op, text=t["op_hint"], font=("", 8),
                  foreground="gray").pack(anchor="w")
        ttk.Button(op, text="op", command=self.do_op).pack(anchor="w", pady=(4, 0))
        links = ttk.Frame(self.tab_actions)
        links.pack(fill="x", pady=(10, 0))
        ttk.Button(links, text=t["open_guide"],
                   command=lambda: self.open_doc(GUIDE_EN, GUIDE_FR)).pack(
            side="left", expand=True, fill="x", padx=(0, 4))
        ttk.Button(links, text=t["open_vcn"],
                   command=lambda: self.open_doc(VCN_EN, VCN_FR)).pack(
            side="left", expand=True, fill="x", padx=(4, 0))

    # -- checklist tab -------------------------------------------------
    def _build_checklist(self):
        t = self.t
        ttk.Label(self.tab_check, text=t["cl_title"], font=("", 10, "bold")).pack(
            anchor="w", pady=(0, 6))
        self.check_vars = []
        for key in ("cl_parent", "cl_vm", "cl_ip", "cl_ports"):
            var = tk.BooleanVar(value=False)
            box = ttk.Checkbutton(self.tab_check, text=t[key], variable=var,
                                  wraplength=480)
            box.pack(anchor="w", pady=3)
            self.check_vars.append(var)
        ttk.Label(self.tab_check, text=t["cl_note"], font=("", 8),
                  foreground="gray", wraplength=480).pack(anchor="w", pady=(8, 0))

    # -- helpers -------------------------------------------------------
    def pick_key(self):
        path = filedialog.askopenfilename(
            title=self.t["key"],
            filetypes=[("Key files", "*.key *.pem *.ppk"), ("All files", "*.*")],
        )
        if path:
            self.key_var.set(path)

    def server_address(self):
        ip = self.conf.get("ORACLE_IP", "")
        return f"{ip}:25565" if ip else ""

    def copy_address(self):
        addr = self.server_address()
        if not addr:
            messagebox.showinfo(self.t["title"], self.t["need_conf"])
            return
        self.clipboard_clear()
        self.clipboard_append(addr)
        self.status(self.t["copied"])

    def open_panel(self):
        ip = self.conf.get("ORACLE_IP", "")
        if not ip:
            messagebox.showinfo(self.t["title"], self.t["need_conf"])
            return
        webbrowser.open(f"https://{ip}:8443")

    def open_doc(self, en_rel, fr_rel):
        rel = fr_rel if self.lang == "fr" else en_rel
        webbrowser.open(os.path.join("file://" + ROOT, rel.replace("/", os.sep)))

    def status(self, msg):
        self.status_var.set(msg)
        self.update_idletasks()

    def validate_inputs(self, need_key=True):
        t = self.t
        ip = self.ip_var.get().strip()
        if not valid_ipv4(ip):
            messagebox.showerror(t["title"], t["bad_ip"])
            return None
        key = self.key_var.get().strip().strip('"')
        if need_key and not os.path.isfile(key):
            messagebox.showerror(t["title"], t["need_key"])
            return None
        mc = self.mc_var.get().strip()
        if not valid_mc_version(mc):
            messagebox.showerror(t["title"], "Minecraft version: " + mc)
            return None
        try:
            players = int(self.players_var.get().strip())
            if not 1 <= players <= 100:
                raise ValueError
        except ValueError:
            messagebox.showerror(t["title"], "Players: 1–100")
            return None
        mp_label = self.mp_var.get()
        modpack = "none" if mp_label == t["mp_none"] else mp_label
        return {
            "ip": ip, "key": key,
            "user": self.user_var.get().strip() or "ubuntu",
            "type": self.type_var.get(), "mc": mc,
            "ram": self.ram_var.get(), "players": str(players),
            "crafty": "true" if self.crafty_var.get() else "false",
            "modpack": modpack,
        }

    def run_script(self, rel, args):
        t = self.t
        if not self.bash:
            messagebox.showerror(t["title"], t["need_bash"])
            webbrowser.open("https://git-scm.com/download/win")
            return
        script = os.path.join(ROOT, *rel.split("/"))
        if not os.path.isfile(script):
            messagebox.showerror(t["title"], script)
            return
        quoted = " ".join(shell_quote(a) for a in [script] + args)
        cmd = [self.bash, "--login", "-c", quoted]
        self.status(t["running"])
        try:
            # Interactive scripts need a visible terminal on Windows.
            if sys.platform == "win32":
                subprocess.Popen(cmd, cwd=ROOT,
                                 creationflags=subprocess.CREATE_NEW_CONSOLE)
            else:
                subprocess.Popen(cmd, cwd=ROOT)
        except OSError as exc:
            messagebox.showerror(t["title"], str(exc))
            return
        self.conf = read_conf()
        if hasattr(self, "addr_var"):
            self.addr_var.set(self.server_address() or t["not_configured"])

    def do_install(self):
        self.run_script("setup.sh", ["--lang", self.lang])

    def do_expert(self):
        vals = self.validate_inputs()
        if not vals:
            return
        if vals["type"] == "modpack" and vals["modpack"] == "none":
            messagebox.showerror(self.t["title"], self.t["modpack"] + ": ?")
            return
        self.run_script("setup.sh", [
            "--lang", self.lang, "--ip", vals["ip"], "--key", vals["key"],
            "--type", vals["type"], "--mc-version", vals["mc"],
            "--ram", vals["ram"], "--players", vals["players"],
            "--crafty", vals["crafty"], "--modpack", vals["modpack"],
            "--pack-url", "-", "--yes",
        ])

    def do_dryrun(self):
        vals = self.validate_inputs(need_key=False)
        if not vals:
            return
        key = vals["key"] or os.path.join(ROOT, "README.md")
        self.run_script("setup.sh", [
            "--lang", self.lang, "--ip", vals["ip"], "--key", key,
            "--type", vals["type"], "--mc-version", vals["mc"],
            "--ram", vals["ram"], "--players", vals["players"],
            "--crafty", vals["crafty"], "--modpack", vals["modpack"],
            "--pack-url", "-", "--yes", "--dry-run",
        ])

    def do_op(self):
        t = self.t
        name = self.op_var.get().strip()
        if not re.match(r"^[A-Za-z0-9_]{3,16}$", name):
            messagebox.showerror(t["title"], t["op_name"] + " (A-Z, 0-9, _, 3–16)")
            return
        self.run_script("utils/console.sh", [f"op {name}"])

    def whitelist_dialog(self):
        t = self.t
        if not self.conf.get("ORACLE_IP"):
            messagebox.showinfo(t["title"], t["need_conf"])
            return
        dlg = tk.Toplevel(self)
        dlg.title(t["whitelist"])
        dlg.geometry("320x200")
        dlg.transient(self)
        ttk.Label(dlg, text=t["wl_action"]).pack(anchor="w", padx=12, pady=(10, 0))
        act = tk.StringVar(value="add")
        ttk.Combobox(dlg, textvariable=act, values=["add", "remove", "list"],
                     width=10, state="readonly").pack(anchor="w", padx=12)
        ttk.Label(dlg, text=t["wl_name"]).pack(anchor="w", padx=12, pady=(8, 0))
        name = tk.StringVar()
        ttk.Entry(dlg, textvariable=name, width=20).pack(anchor="w", padx=12)

        def go():
            action = act.get()
            player = name.get().strip()
            if action in ("add", "remove"):
                if not re.match(r"^[A-Za-z0-9_]{3,16}$", player):
                    messagebox.showerror(t["title"], t["wl_name"] + " (A-Z, 0-9, _, 3–16)")
                    return
                args = [action, player]
            else:
                args = [action]
            dlg.destroy()
            self.run_script("security/whitelist_manager.sh", args)

        ttk.Button(dlg, text=t["run"], command=go).pack(pady=12)


def main():
    app = Launcher()
    app.mainloop()


if __name__ == "__main__":
    main()
