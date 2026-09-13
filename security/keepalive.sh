#!/usr/bin/env bash
# =============================================================================
# keepalive.sh — Brûleur CPU pour éviter la réclamation OCI Always Free.
#
# Contexte : Oracle Cloud révoque les instances « idle » dont la consommation
#   CPU p95 < 20% ET réseau < 20% ET mémoire < 20% (sur 7 jours glissants).
#
# Ce script occupe 1 cœur (~25% d'une VM 4 OCPU) en calcul cryptographique,
# pendant 40 minutes, puis dort 20 minutes (cycle 1h). Avec Minecraft actif
# par-dessus, on est largement au-dessus du seuil.
#
# Installation (une fois, sur la VM) :
#   sudo cp security/keepalive.sh /opt/minecraft/bin/keepalive.sh
#   sudo chmod +x /opt/minecraft/bin/keepalive.sh
#   sudo tee /etc/systemd/system/keepalive.service <<'EOF'
#   [Unit]
#   Description=Burn CPU to stay above OCI Always Free idle threshold
#   [Service]
#   ExecStart=/opt/minecraft/bin/keepalive.sh
#   Nice=19
#   CPUWeight=10
#   CPUQuota=30%
#   MemoryMax=256M
#   Restart=always
#   RestartSec=60
#   [Install]
#   WantedBy=multi-user.target
#   EOF
#   sudo systemctl enable --now keepalive.service
#
# ⚠️  INCOMPATIBLE avec auto-sleep (utils/auto-sleep.sh) : keepalive simule
#   de l'activité pour paraître occupé, auto-sleep éteint le serveur quand
#   il est vide. Choisissez l'un OU l'autre, jamais les deux.
# =============================================================================
set -euo pipefail

# Dure en minutes : 40 min ON (~25% CPU = 1 cœur), 20 min OFF (idle).
# Entiers stricts uniquement (variables d'environnement = entrée non fiable).
ON_MIN="${KEEPALIVE_ON_MIN:-40}"
OFF_MIN="${KEEPALIVE_OFF_MIN:-20}"
[[ "$ON_MIN" =~ ^[0-9]+$ && "$OFF_MIN" =~ ^[0-9]+$ ]] \
    || { echo "[keepalive] KEEPALIVE_ON/OFF_MIN doivent être des entiers." >&2; exit 1; }

while true; do
    end=$(( $(date +%s) + 10#$ON_MIN * 60 ))
    # UN SEUL worker sha256 (~25% d'une VM 4 OCPU) : le but est de dépasser
    # le seuil idle p95 20% d'OCI, pas de concurrencer Minecraft.
    ( exec yes "$(date +%s%N)" | sha256sum >/dev/null 2>&1 ) &
    while (( $(date +%s) < end )); do sleep 30; done
    kill $(jobs -p) 2>/dev/null || true
    wait 2>/dev/null || true
    sleep $(( 10#$OFF_MIN * 60 ))
done
