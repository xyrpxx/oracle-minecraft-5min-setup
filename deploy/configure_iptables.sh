#!/usr/bin/env bash
# =============================================================================
# configure_iptables.sh — Ouverture des ports sur une VM Ubuntu OCI.
# S'EXÉCUTE SUR LA VM (root). Les images Ubuntu d'Oracle embarquent des règles
# iptables se terminant par un REJECT global : ufw est donc INTERDIT (conflit).
# On insère nos règles AVANT le REJECT, puis on persiste via netfilter-persistent.
# Idempotent : les règles déjà présentes ne sont pas dupliquées.
# =============================================================================
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "[ERREUR] Ce script doit être exécuté avec sudo (root)." >&2
    exit 1
fi

# Numéro de la première règle REJECT de la chaîne INPUT (règle finale d'Oracle).
# On insère juste avant elle ; si elle est introuvable, on insère en tête.
REJECT_LINE="$(iptables -L INPUT --line-numbers -n | awk '/REJECT/ {print $1; exit}')"
INSERT_AT="${REJECT_LINE:-1}"

add_rule() { # protocole port
    local proto="$1" port="$2"
    if iptables -C INPUT -p "$proto" --dport "$port" -m conntrack --ctstate NEW -j ACCEPT 2>/dev/null; then
        echo "[iptables] Règle déjà présente : ${proto}/${port}"
    else
        iptables -I INPUT "$INSERT_AT" -p "$proto" --dport "$port" -m conntrack --ctstate NEW -j ACCEPT
        echo "[iptables] Règle ajoutée : ${proto}/${port} (position ${INSERT_AT})"
    fi
}

add_rule tcp 25565   # Minecraft (TCP)
add_rule udp 25565   # Minecraft (UDP : query, mods vocaux)
add_rule tcp 8443    # Crafty Controller (panel web)

# Persistance après redémarrage
netfilter-persistent save
echo "[iptables] Règles sauvegardées (netfilter-persistent)."
echo "[iptables] RAPPEL : les Ingress Rules du VCN doivent AUSSI être ouvertes"
echo "[iptables] dans la console Oracle (voir docs/oci-vcn-config.md)."
