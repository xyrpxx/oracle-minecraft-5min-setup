# 🎮 Oracle Cloud Minecraft — Setup en 5 minutes

Déployez un **serveur Minecraft moddé** (Forge 1.20.1 / Fabric / Vanilla /
modpack) sur le **Always Free** d'Oracle Cloud : 2 OCPU ARM, **12 Go de RAM**,
200 Go de disque, **0 €/mois**, 24h/24 — sans compétence DevOps.

## 🧒 Première fois de ta vie ? Suis juste ces 3 étapes

1. **Télécharge ce projet** : bouton vert **⟵ Code** en haut à droite →
   **Download ZIP** → dézippe le dossier (clic droit → Extraire tout).
2. **Ouvre le dossier obtenu et double-clique sur `start-windows.bat`**
   (Windows). Le programme te **guide ensuite étape par étape** : création du
   compte gratuit Oracle, création de la machine, configuration... en français,
   avec la possibilité d'appuyer sur **Entrée** pour garder les réponses
   conseillées. (Sur Mac/Linux : ouvre un terminal dans le dossier et lance
   `bash setup.sh`.)
3. À la fin, le programme t'affiche **l'adresse de ton serveur** à donner à
   tes amis, et la dernière manipulation à faire (ouvrir les ports, 3 minutes).

> 🧑‍💻 Déjà à l'aise ? `./setup.sh --mode expert` ou `--help` pour le mode scripté.

> ⚠️ Prérequis : un compte Oracle Cloud et une VM Ubuntu ARM créés
> (le **Mode guide** t'accompagne si tu ne les as pas encore),
> Minecraft **Java Edition**. Après le setup, ouvrez les ports du VCN
> ([`docs/oci-vcn-config.md`](docs/oci-vcn-config.md), 3 minutes).

## Ce que fait le script

| Étape | Fait automatiquement |
|---|---|
| Système | Java 21 (ARM64), paquets, utilisateur dédié `minecraft` |
| Serveur | Vanilla / Forge / Fabric / modpack, configuration optimisée |
| Performance | Flags JVM calibrés Ampere A1 (ZGC générationnel, 8 Go max) |
| Pare-feu | iptables inséré avant le REJECT d'Oracle (ufw proscrit sur OCI) |
| Panel web | Crafty Controller (Docker Compose, optionnel) |
| Démarrage | Service systemd : auto-start et redémarrage après crash |
| Admin | Sauvegardes à chaud, restauration, supervision, whitelist |

## Comparatif

| Hébergeur | RAM | Prix | File d'attente | Contrôle |
|---|---|---|---|---|
| Aternos / Minehut | 1-2 Go | Gratuit | Oui | Limité |
| Hébergeur payant | 8 Go | 15-30 €/mois | Non | Moyen |
| **Ce projet (OCI)** | **12 Go** | **0 €/mois** | **Non** | **Total** |

Coût réel : Minecraft Java (~30 €, achat unique) + 0 €/mois.

## Scripts fournis

| Script | Rôle |
|---|---|
| `setup.sh` | Installation complète (Mode guide interactif, ou `--help` pour le mode scripté) |
| `start-windows.bat` | **Double-clic** sous Windows : lance l'installation guidée |
| `utils/console.sh` | Commandes admin en jeu : `./utils/console.sh "op TonPseudo"` |
| `utils/backup.sh` | Sauvegarde à chaud + rotation (`KEEP=14 ./utils/backup.sh`) |
| `utils/restore.sh` | Restauration d'une archive |
| `utils/monitor.sh` | CPU, RAM, disque, joueurs, TPS (`watch -n 5 ./utils/monitor.sh`) |
| `utils/update.sh` | Mise à jour moteur / Forge / modpack (préserve le monde) |
| `security/hardening.sh` | SSH durci, fail2ban, mises à jour auto |
| `security/whitelist_manager.sh` | `add` / `remove` / `list` |
| `uninstall.sh` | Suppression propre de tout ce qui a été installé |

## Documentation

- [Guide débutant complet](docs/guide-debutant-fr.md) — de zéro au premier bloc posé
- [Ouvrir les ports VCN](docs/oci-vcn-config.md) — étape obligatoire après le setup
- [Dépannage](docs/troubleshooting.md) — timed out, Forge, OOM, lag...

## Détails techniques (pour les curieux)

- **Séparation stricte local/distant** : `setup.sh` tourne chez vous et pilote
  la VM en SSH ; tout le provisioning s'exécute sur la VM via
  `deploy/remote_provision.sh` (idempotent, ré-exécutable sans risque).
- **Forge moderne** : lancement via `@unix_args.txt` — jamais `java -jar`.
- **Pare-feu OCI** : les images Ubuntu d'Oracle terminent leur chaîne iptables
  par un REJECT global qui neutralise ufw ; nous insérons donc nos règles
  directement avant ce REJECT puis persistons avec `netfilter-persistent`.
- **JVM ARM64** : `-Xms` = `-Xmx` ≤ 8 Go, ZGC générationnel, AlwaysPreTouch.

## Contribuer

Issues et PR bienvenues : nouveaux modpacks (fichier JSON dans `modpacks/`),
corrections de documentation, idées d'optimisation. Les scripts sont testés
(`bash tests/run_tests.sh`) — faites passer la suite avant de proposer une PR.

## Licence

[MIT](LICENSE)
