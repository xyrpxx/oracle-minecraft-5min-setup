#!/usr/bin/env bash
# =============================================================================
# hardening.sh — Durcissement de la VM (exécuté LOCALEMENT, via SSH).
# Applique sur la VM :
#   1. SSH : root interdit, authentification par clé uniquement
#      (drop-in /etc/ssh/sshd_config.d/99-mc-hardening.conf, validé par sshd -t)
#   2. fail2ban sur le service sshd
#   3. mises à jour de sécurité automatiques (unattended-upgrades)
# Idempotent : ré-exécutable sans risque.
# AVERTISSEMENT : vérifiez que votre clé SSH fonctionne AVANT de lancer ce script
# (c'est déjà le cas si setup.sh a réussi).
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib.sh
. "${SCRIPT_DIR}/scripts/lib.sh"

load_server_conf "${SCRIPT_DIR}/.server.conf"

echo
warn "Ce script va interdire le login SSH root et l'authentification par mot de passe."
warn "Votre connexion par clé restera fonctionnelle (utilisée par ce projet)."
ask_yes_no "Continuer ?" "n" || { info "Durcissement annulé."; exit 0; }

run_ssh "bash -s" <<'REMOTE'
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

echo "[hardening] 1/3 — SSH durci (root interdit, clé uniquement)..."
cat > /etc/ssh/sshd_config.d/99-mc-hardening.conf <<'CONF'
# oracle-minecraft-5min-setup — durcissement SSH
PermitRootLogin no
PasswordAuthentication no
CONF
sshd -t
systemctl reload ssh 2>/dev/null || systemctl reload sshd

echo "[hardening] 2/3 — fail2ban (protection brute-force SSH)..."
apt-get install -y -qq fail2ban >/dev/null
cat > /etc/fail2ban/jail.d/minecraft-ssh.local <<'JAIL'
[sshd]
enabled = true
maxretry = 5
findtime = 10m
bantime = 1h
JAIL
systemctl enable --now fail2ban >/dev/null 2>&1 || true
systemctl restart fail2ban

echo "[hardening] 3/3 — mises à jour de sécurité automatiques..."
apt-get install -y -qq unattended-upgrades >/dev/null
systemctl enable --now unattended-upgrades >/dev/null 2>&1 || true

echo "[hardening] Terminé."
REMOTE

success "VM durcie sur ${ORACLE_IP}."
