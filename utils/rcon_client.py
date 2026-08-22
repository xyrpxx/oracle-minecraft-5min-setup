#!/usr/bin/env python3
"""Client RCON minimal (protocole Source RCON) pour Minecraft.

Usage : rcon_client.py <hote> <port> <mot_de_passe> <commande>

Déployé sur la VM dans /opt/minecraft/bin/ par remote_provision.sh.
Le serveur Minecraft doit avoir enable-rcon=true (configuré par le setup).
Limite connue : les réponses de plus de 4096 octets sont tronquées par le
protocole lui-même — suffisant pour save-off/list/whitelist...
"""
import socket
import struct
import sys

SERVERDATA_AUTH = 3
SERVERDATA_AUTH_RESPONSE = 2
SERVERDATA_EXECCOMMAND = 2
SERVERDATA_RESPONSE_VALUE = 0
TIMEOUT = 10


def build_packet(request_id, ptype, payload):
    """Construit un paquet RCON : [longueur][id][type][charge][nul][nul]."""
    body = struct.pack("<ii", request_id, ptype) + payload.encode("utf-8") + b"\x00\x00"
    return struct.pack("<i", len(body)) + body


def recv_exact(sock, size):
    """Lit exactement `size` octets sur le socket."""
    data = b""
    while len(data) < size:
        chunk = sock.recv(size - len(data))
        if not chunk:
            raise ConnectionError("Connexion RCON fermée par le serveur")
        data += chunk
    return data


def read_packet(sock):
    """Lit un paquet RCON et retourne (id, type, charge_utile)."""
    (length,) = struct.unpack("<i", recv_exact(sock, 4))
    body = recv_exact(sock, length)
    request_id, ptype = struct.unpack("<ii", body[:8])
    return request_id, ptype, body[8:-2].decode("utf-8", errors="replace")


def run(host, port, password, command):
    """Se connecte, s'authentifie puis exécute une commande et affiche la réponse."""
    with socket.create_connection((host, port), timeout=TIMEOUT) as sock:
        sock.settimeout(TIMEOUT)
        sock.sendall(build_packet(1, SERVERDATA_AUTH, password))
        while True:
            rid, rtype, _ = read_packet(sock)
            if rtype == SERVERDATA_AUTH_RESPONSE:
                if rid == -1:
                    print("Authentification RCON échouée (mot de passe).", file=sys.stderr)
                    sys.exit(1)
                break
        sock.sendall(build_packet(1, SERVERDATA_EXECCOMMAND, command))
        _rid, rtype, payload = read_packet(sock)
        if rtype == SERVERDATA_RESPONSE_VALUE:
            print(payload)


def main(argv):
    if len(argv) != 5:
        print("Usage : rcon_client.py <hote> <port> <mot_de_passe> <commande>", file=sys.stderr)
        return 2
    try:
        run(argv[1], int(argv[2]), argv[3], argv[4])
    except (OSError, ConnectionError) as exc:
        print(f"Erreur RCON : {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
