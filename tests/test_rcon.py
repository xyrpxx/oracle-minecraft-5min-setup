#!/usr/bin/env python3
"""Tests du client RCON (exécutés si python3/python est disponible)."""
import os
import struct
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "utils"))
import rcon_client  # noqa: E402

failures = []


def check(name, cond):
    if cond:
        print(f"  OK    {name}")
    else:
        failures.append(name)
        print(f"  ÉCHEC {name}", file=sys.stderr)


# --- build_packet : [longueur][id][type][charge][nul][nul] ---
p = rcon_client.build_packet(1, 3, "secret")
check("longueur totale = 20", len(p) == 20)
check("champ length = 16", struct.unpack("<i", p[:4])[0] == 16)
check("champ id = 1", struct.unpack("<i", p[4:8])[0] == 1)
check("champ type = 3", struct.unpack("<i", p[8:12])[0] == 3)
check("charge utile", p[12:18] == b"secret")
check("double octet nul final", p[18:20] == b"\x00\x00")

p2 = rcon_client.build_packet(7, 2, "list")
check("paquet 'list' : length = 14", struct.unpack("<i", p2[:4])[0] == 14)

total = 7
print(f"\nRésultats : {total - len(failures)} OK, {len(failures)} échec(s)")
sys.exit(1 if failures else 0)
