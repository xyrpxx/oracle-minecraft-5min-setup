#!/usr/bin/env bash
# =============================================================================
# oci_ingress_setup.sh — Ajoute les Ingress Rules VCN via OCI CLI (OPTIONNEL).
# Alternative scriptée au guide manuel docs/oci-vcn-config.md.
#
# Prérequis (machine locale) :
#   pip install oci-cli && oci setup config
#   sudo apt install jq   (ou brew install jq)
#
# Usage :
#   bash deploy/oci_ingress_setup.sh --security-list-ocid ocid1.securitylist.oc1..
#
# Règles ajoutées (idempotent, par description) :
#   TCP 25565, UDP 25565, TCP 8443 — source 0.0.0.0/0
# =============================================================================
set -euo pipefail

SL_ID=""
usage() { sed -n 's/^# \{0,1\}//p' "$0" | sed -n '3,18p'; }

while [[ $# -gt 0 ]]; do
    case "$1" in
        --security-list-ocid) SL_ID="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Argument inconnu : $1" >&2; exit 1 ;;
    esac
done
[[ -n "$SL_ID" ]] || { usage; exit 1; }
[[ "$SL_ID" == ocid1.securitylist.* ]] || { echo "OCID de security list invalide." >&2; exit 1; }

command -v oci >/dev/null 2>&1 || { echo "OCI CLI absent : pip install oci-cli" >&2; exit 1; }
command -v jq  >/dev/null 2>&1 || { echo "jq absent (apt install jq)" >&2; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "[1/4] Lecture de la security list..."
oci network security-list get --security-list-id "$SL_ID" > "${TMP}/sl.json"

echo "[2/4] Construction des règles à ajouter..."
oci network security-list get --security-list-id "$SL_ID" \
    --query 'data."ingress-security-rules"' --raw-output > "${TMP}/existing.json"

make_rule() { # protocole_num port description
    jq -n --arg src "0.0.0.0/0" --arg proto "$1" --arg port "$2" --arg desc "$3" \
        '{description: $desc, protocol: $proto, isStateless: false, source: $src,
          sourceType: "CIDR", tcpOptions: (if $proto == "6" then
            {destinationPortRange: {max: ($port | tonumber), min: ($port | tonumber)}} else null end),
          udpOptions: (if $proto == "17" then
            {destinationPortRange: {max: ($port | tonumber), min: ($port | tonumber)}} else null end)}'
}

DESC_TCP="oracle-minecraft-setup TCP 25565"
DESC_UDP="oracle-minecraft-setup UDP 25565"
DESC_CRAFTY="oracle-minecraft-setup TCP 8443"

EXISTING_COUNT="$(jq --arg d "$DESC_TCP" '[.[] | select(.description == $d)] | length' "${TMP}/existing.json")"
if [[ "$EXISTING_COUNT" != "0" ]]; then
    echo "[2/4] Règles déjà présentes (description identique) — rien à faire."
    exit 0
fi

{
    make_rule 6  25565 "$DESC_TCP"
    make_rule 17 25565 "$DESC_UDP"
    make_rule 6  8443  "$DESC_CRAFTY"
} > "${TMP}/new.json"

echo "[3/4] Fusion des règles existantes et nouvelles..."
jq -s '.[0] + .[1]' "${TMP}/existing.json" "${TMP}/new.json" > "${TMP}/merged.json"

echo "[4/4] Mise à jour de la security list..."
oci network security-list update --security-list-id "$SL_ID" \
    --ingress-security-rules "file://${TMP}/merged.json" --force >/dev/null

echo "Terminé : Ingress Rules TCP/UDP 25565 et TCP 8443 ajoutées (0.0.0.0/0)."
