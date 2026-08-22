# Ouvrir les ports du réseau Oracle (VCN) — ÉTAPE OBLIGATOIRE

## Pourquoi cette étape est indispensable

Votre VM est protégée par **deux pare-feu** successifs :

| Niveau | Où ça se règle | Qui le configure |
|---|---|---|
| 1. VCN Security List (le cloud Oracle) | Console web Oracle (ou OCI CLI) | **Vous, une seule fois** (ce guide) |
| 2. iptables (la VM Ubuntu) | `deploy/configure_iptables.sh` | Le script d'installation, automatiquement |

Par défaut, le VCN n'autorise que le port 22 (SSH). Tant que les Ingress Rules
ne sont pas ouvertes, votre serveur est invisible depuis Minecraft, même si
tout le reste fonctionne. **Comptez 3 minutes.**

## Méthode A — Console Oracle (recommandée)

1. Connectez-vous sur <https://cloud.oracle.com>.
2. Menu ☰ (en haut à gauche) → **Networking** → **Virtual Cloud Networks**.
3. Cliquez sur votre VCN (nom par défaut du type `vcn-20260822-1234...`).
4. Dans la colonne **Resources**, cliquez sur **Security Lists**, puis sur
   **Default Security List for ...**.
5. Cliquez sur **Add Ingress Rules** et ajoutez les trois règles suivantes
   (utilisez *Add Another Rule* pour les saisir en une fois) :

   | Champ | Règle 1 | Règle 2 | Règle 3 |
   |---|---|---|---|
   | Source Type | CIDR | CIDR | CIDR |
   | Source CIDR | `0.0.0.0/0` | `0.0.0.0/0` | `0.0.0.0/0` |
   | IP Protocol | TCP | UDP | TCP |
   | Source Port Range | *(vide)* | *(vide)* | *(vide)* |
   | Destination Port Range | `25565` | `25565` | `8443` |
   | Description | Minecraft TCP | Minecraft UDP | Crafty Panel |

6. Cliquez sur **Add Ingress Rules**. L'effet est immédiat.

> Le port 22 (SSH) est déjà ouvert par défaut — ne le modifiez pas.
> `0.0.0.0/0` signifie « depuis n'importe quelle adresse Internet », ce qui est
> nécessaire pour que vos amis se connectent.

## Méthode B — Script OCI CLI (optionnel)

Si vous avez installé l'OCI CLI (`pip install oci-cli && oci setup config`) et `jq` :

```bash
bash deploy/oci_ingress_setup.sh --security-list-ocid ocid1.securitylist.oc1...
```

L'OCID se trouve dans la console : VCN → Security Lists → votre security list →
champ **OCID** (bouton copier). Le script est idempotent : le relancer ne crée
pas de doublons.

## Vérifier que ça marche

1. Le serveur doit être démarré : `./utils/monitor.sh` → `active`.
2. Depuis votre PC, testez le port :
   - Windows PowerShell : `Test-NetConnection <IP_VM> -Port 25565` → `TcpTestSucceeded : True`
   - Linux/macOS : `nc -vz <IP_VM> 25565` → `succeeded`
3. Dans Minecraft : Multijoueur → Ajouter un serveur → `<IP_VM>:25565`.

Si l'icône ping du serveur reste barrée, voir `docs/troubleshooting.md`
(section « Connection timed out ») pour l'arbre de diagnostic complet
(VCN → iptables → service).
