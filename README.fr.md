# 🎮 Oracle Cloud Minecraft — Setup en 5 minutes

**[🇬🇧 English (full README)](README.md)** | **🇫🇷 Français**

Déployez un **serveur Minecraft moddé** (Forge 1.20.1 / Fabric / Vanilla / modpack) sur le **Always Free** d'Oracle Cloud : 2 OCPU ARM, **12 Go de RAM**, 200 Go de disque, **0 €/mois**, en ligne 24h/24 — sans compétence DevOps.

![Licence](https://img.shields.io/badge/licence-MIT-green)
![Coût](https://img.shields.io/badge/co%C3%BBt-0%E2%82%AC/mois-success)
![Plateforme](https://img.shields.io/badge/plateforme-Windows%20%7C%20macOS%20%7C%20Linux-blue)
![Langues](https://img.shields.io/badge/interface-FR%20%7C%20EN-informational)

---

## 🧒 Première fois de ta vie ? Suis juste ces 3 étapes

1. **Télécharge ce projet** : bouton vert **⟵ Code** en haut à droite → **Download ZIP** → dézippe le dossier.
2. **Ouvre le dossier obtenu et double-clique sur `start-windows.bat`** (Windows). Le programme te **guide ensuite étape par étape** : création du compte gratuit Oracle, création de la machine, configuration... avec la possibilité d'appuyer sur **Entrée** pour garder les réponses conseillées. (Sur Mac/Linux : ouvre un terminal dans le dossier et lance `bash setup.sh`.)
3. À la fin, le programme t'affiche **l'adresse de ton serveur** à donner à tes amis, et la dernière manipulation à faire (ouvrir les ports, 3 minutes).

> 🧑‍💻 Déjà à l'aise ? `bash setup.sh --mode expert` ou `--help` pour le mode scripté. L'interface détecte ta langue (français/anglais) ; force avec `--lang fr`.

---

## 📑 Ce que fait ce projet

Héberger un serveur Minecraft moddé coûte normalement **15–30 €/mois** (ou hébergeur gratuit : 1–2 Go de RAM, files d'attente, extinction automatique). Ce projet déploie le tien sur l'**Always Free d'Oracle** — vraiment gratuit, à vie, sans date de fin d'essai — et automatise *tout* :

| | Hébergeurs gratuits | Hébergeur payant | **Ce projet (OCI)** |
|---|---|---|---|
| RAM | 1–2 Go | 8 Go | **12 Go** |
| Prix | Gratuit | 15–30 €/mois | **0 €/mois** |
| File d'attente / veille | Oui | Non | **Non — 24/7** |
| Contrôle | Limité | Moyen | **Total** |
| Temps d'installation | ~10 min | ~15 min | **~10 min (guidé)** |

Coût réel : Minecraft **Java Edition** (~30 €, achat unique) + 0 €/mois.

## 📋 Ce qu'il te faut

- Minecraft **Java Edition** (pas Bedrock/console/mobile).
- Une **carte bancaire** pour la vérification d'identité Oracle (pré-autorisation ~1 $ remboursée ; **aucun prélèvement** en gratuit — demande l'autorisation d'un adulte si besoin).
- Un ordinateur sous **Windows** (avec [Git pour Windows](https://git-scm.com/download/win)), **macOS** ou **Linux**.
- Environ **25 minutes** au total (dont une grande partie d'attente).
- Aucune connaissance technique : l'installateur contient un **assistant guidé** avec des explications accessibles, en **français ou anglais** (détection automatique).

## 📚 Tutoriel complet (mode détaillé)

Le Mode guide de `setup.sh` suit exactement ces étapes et **attend entre chacune** — tu peux utiliser l'un ou l'autre. Version anglaise complète : [README.md](README.md).

### Étape 0 — Vérifier le matériel (2 minutes)

Sous Windows, installe d'abord [Git pour Windows](https://git-scm.com/download/win) (suivant, suivant, terminer). Récupère le projet : bouton vert **Code** → **Download ZIP** → dézippe (ou `git clone https://github.com/xyrpxx/oracle-minecraft-5min-setup.git`).

### Étape 1 — Créer ton compte Oracle (10 minutes, une seule fois)

1. Va sur <https://cloud.oracle.com> → **Start for free**.
2. Email + mot de passe (note-les !), nom, pays, téléphone (vérification SMS).
3. Carte bancaire pour vérification d'identité — **rien n'est prélevé** tant que tu restes en gratuit. Les cartes virtuelles jetables sont souvent refusées.
4. **Région (Home Region)** : choix définitif — prends la plus proche (UK South ou Germany Central depuis la France) pour le moins de lag.
5. Attends l'email de confirmation (jusqu'à 30 minutes), puis connecte-toi.

> ⚠️ Si Oracle propose **« Upgrade to Pay As You Go »** : REFUSE. Rester en gratuit = 0 €, garanti.

### Étape 2 — Créer la machine virtuelle (10 minutes, une seule fois)

Console Oracle : **menu ☰ → Compute → Instances → Create instance** :

| Champ | Quoi remplir |
|---|---|
| Name | Ce que tu veux (ex. `minecraft`) |
| Image *(Edit)* | **Ubuntu** 22.04 ou 24.04 — **pas** « Minimal » |
| Shape *(Edit)* | Onglet **Ampere** → **VM.Standard.A1.Flex** → OCPUs **2**, Memory **12 GB** |
| SSH keys ⚠️ | **Generate a key pair** → **Save Private Key** (garde ce fichier pour toujours — c'est la clé de ta machine !) → **Save Public Key** |
| Networking | Par défaut, avec **Assign a public IPv4 address** |

Clique **Create**, attends 2–5 minutes le statut vert **Running**, et note la **Public IP Address** (ex. `129.213.56.123`).

> Erreur **« Out of capacity »** : région saturée — réessaie plus tard ou change de région.

### Étape 3 — Lancer l'installateur (10 minutes)

**Windows** : double-clique sur **`start-windows.bat`**. **macOS/Linux/Git Bash** :

```bash
bash setup.sh
```

Choisis le **Mode guide**. Questions posées (Entrée = valeur conseillée) :

| Question | Signification | Conseillé |
|---|---|---|
| Type de serveur | Vanilla (sans mods), Forge (mods classiques), Fabric (léger) ou modpack | **Forge** pour des mods |
| Version Minecraft | Version du jeu — tout le monde doit avoir la même | **1.20.1** |
| RAM | Mémoire du serveur (8 max sur les 12 Go) | **8 Go** |
| Joueurs max | Places sur le serveur | **10** |
| Panel Crafty | Page web pour gérer le serveur avec des boutons | **Oui** |
| URL du server pack *(modpacks)* | Lien direct vers le fichier serveur du pack (CurseForge → Files → Additional Files → clic droit « Server Pack » → Copier l'adresse) | — |

L'installateur se connecte ensuite à ta machine, installe Java 21 + le serveur + le pare-feu + le redémarrage automatique, le démarre, et affiche **l'adresse de ton serveur**.

<details>
<summary>🖥️ Mode scripté / expert (sans questions)</summary>

```bash
bash setup.sh --mode expert --ip 1.2.3.4 --key ~/ssh-key-2026-08-22.key \
     --type forge --mc-version 1.20.1 --ram 8 --players 10 --crafty true --yes
# Aperçu sans toucher la VM : ajouter --dry-run
# Toutes les options : bash setup.sh --help
```
</details>

### Étape 4 — Ouvrir les ports réseau (obligatoire, 3 minutes)

Oracle protège chaque machine derrière un pare-feu cloud. L'installateur configure la machine elle-même ; **toi** tu dois cliquer 3 règles dans la console (une seule fois) :

**Networking → Virtual Cloud Networks → ton VCN → Security Lists → Default Security List → Add Ingress Rules :**

| | Règle 1 | Règle 2 | Règle 3 |
|---|---|---|---|
| Source CIDR | `0.0.0.0/0` | `0.0.0.0/0` | `0.0.0.0/0` |
| IP Protocol | TCP | UDP | TCP |
| Destination Port | `25565` | `25565` | `8443` |
| Description | Minecraft TCP | Minecraft UDP | Crafty Panel |

Guide détaillé : **[docs/oci-vcn-config.md](docs/oci-vcn-config.md)** (ou le [script OCI CLI](deploy/oci_ingress_setup.sh) pour automatiser).

### Étape 5 — Se connecter avec Minecraft (1 minute)

1. Minecraft **Java Edition** → **Multijoueur** → **Ajouter un serveur**.
2. Adresse : `TON_IP:25565`.
3. Rejoins ! 🎉 (Si ça échoue → [Dépannage](#-dépannage).)

Si tu as installé Crafty, le panel web est sur `https://TON_IP:8443` (accepte l'avertissement de certificat, puis change le mot de passe par défaut).

### Étape 6 — Les mods pour chaque joueur

Un serveur moddé exige que **chaque joueur ait exactement les mêmes mods** :

1. Installe l'app [CurseForge](https://www.curseforge.com/download).
2. Onglet **Minecraft** → **Browse Modpacks** → trouve le modpack du serveur (même version) → **Install**.
3. Lance toujours le jeu **depuis CurseForge** (bouton Play), puis connecte-toi comme ci-dessus.

### Étape 7 — Devenir l'admin du serveur

```bash
./utils/console.sh "op TonPseudo"
```

Cela te donne les pouvoirs d'opérateur en jeu (créatif, téléportation, commandes). Le même outil envoie n'importe quelle commande : `say Bonjour !`, `time set day`, `list`...

---

## ✅ Ce que l'installateur fait pour toi

| Étape | Fait automatiquement |
|---|---|
| Système | Java 21 (ARM64), paquets, utilisateur dédié `minecraft` sans privilèges |
| Serveur | Moteur Vanilla / Forge / Fabric / modpack, configuration optimisée |
| Performance | Flags JVM calibrés Ampere A1 (ZGC générationnel, plafond 8 Go) |
| Pare-feu | Règles iptables insérées avant le REJECT d'Oracle (**ufw proscrit sur OCI**) |
| Panel web | Crafty Controller via Docker Compose (optionnel) |
| Démarrage | Service systemd : auto-start + redémarrage après crash |
| Admin | Sauvegardes à chaud, restauration, supervision, whitelist, console |

## 🛠️ Gérer ton serveur

| Tâche | Commande |
|---|---|
| Commande de jeu / se mettre op | `./utils/console.sh "op TonPseudo"` |
| Sauvegarde (à chaud, avec rotation) | `./utils/backup.sh` (garder plus : `KEEP=14 ./utils/backup.sh`) |
| Restaurer une sauvegarde | `./utils/restore.sh` |
| Stats en direct (CPU, RAM, joueurs, TPS) | `./utils/monitor.sh` |
| Mettre à jour moteur / Forge / modpack | `./utils/update.sh` |
| Durcir la VM (SSH, fail2ban) | `./security/hardening.sh` |
| Gérer la whitelist | `./security/whitelist_manager.sh add Pseudo` |
| Tout supprimer | `./uninstall.sh` |

## 🔧 Dépannage

| Symptôme | Cause probable |
|---|---|
| « Connection timed out » | Règles VCN manquantes → [guide ports](docs/oci-vcn-config.md) |
| « Connection refused / No route to host » | Serveur arrêté ou règle pare-feu mal placée → [guide](docs/troubleshooting.md) |
| Forge « Could not find or load main class » | Jar lancé directement — utiliser le `start.sh` généré |
| Crash / Out of memory | `-Xmx` au-delà de 8 Go — l'OS tue Java ; rester à 8 max |
| Lag / « Can't keep up! » | Baisser `view-distance` à 6, vérifier les TPS via `./utils/monitor.sh` |
| Rejet de mods à la connexion | Modpacks client/serveur différents — même pack, même version |
| SSH « Permission denied » | Mauvaise clé/IP — l'utilisateur est toujours `ubuntu` |

Arbre de diagnostic complet : **[docs/troubleshooting.md](docs/troubleshooting.md)**.

## ❓ FAQ

- **C'est vraiment gratuit ?** Oui — les ressources Always Free utilisées (2 OCPU / 12 Go / 200 Go / 10 To sortants) coûtent 0 €/mois, sans limite de temps. Seul coût : Minecraft Java (~30 €, une fois).
- **Pourquoi Oracle est-il si généreux ?** Acquisition de clients — ils espèrent une future conversion payante. Tu ne dois rien tant que tu restes dans les quotas.
- **Combien de joueurs ?** Vanilla ~15–20 ; modpacks légers 5–10 ; gros packs 3–5 sur 12 Go.
- **Ça tourne quand je suis hors ligne ?** Oui, 24/7, avec redémarrage automatique après crash.
- **Oracle peut-il arrêter l'offre ?** Théoriquement ; elle existe depuis 2018. Tes sauvegardes (`utils/backup.sh`) restent les tiennes.
- **Quelles langues ?** L'installateur parle **français et anglais** (détection auto, `--lang fr|en` pour forcer). Documentation dans les deux langues — voir ci-dessous.

## 🏗️ Garanties techniques

- **Séparation stricte local/distant** — `setup.sh` tourne chez toi et pilote la VM en SSH ; tout le provisioning s'exécute sur la VM via `deploy/remote_provision.sh`.
- **Amorçage Forge moderne** — via `@unix_args.txt` (`java -jar` est cassé depuis Forge 1.17), build recommandé résolu dynamiquement via l'API Forge.
- **Pare-feu conscient d'OCI** — les images Ubuntu d'Oracle terminent leur chaîne iptables par un REJECT global qui neutralise ufw ; nos règles s'insèrent juste avant et persistent via `netfilter-persistent`.
- **JVM durcie pour ARM64** — `-Xms`=`-Xmx` ≤ 8 Go, ZGC générationnel, AlwaysPreTouch, sur OpenJDK 21.
- **Idempotence totale** — relancer n'importe quel script ne casse rien : ni config, ni règles pare-feu en double, ni mondes existants.
- **Moindre privilège** — le serveur tourne sous l'utilisateur dédié `minecraft`, jamais root ; Crafty isolé dans Docker.

## 💻 Compatibilité

| Couche | Vérifié contre |
|---|---|
| Ton ordinateur | Windows (Git Bash), macOS (compatible bash 3.2), Linux |
| La VM | Ubuntu 22.04 / 24.04 LTS, ARM64 (Ampere A1) |
| Java | OpenJDK 21 (ZGC générationnel) |
| Moteurs | Vanilla (piston-meta), Forge 1.17+ (unix_args), Fabric (meta API) |
| Panel | Crafty Controller 4 via Docker Compose (repli `get.docker.com`) |
| Tests | 350+ assertions via `bash tests/run_tests.sh` |

## 📖 Documentation

| Document | Français | English |
|---|---|---|
| Guide débutant | [docs/guide-debutant-fr.md](docs/guide-debutant-fr.md) | [docs/en/getting-started.md](docs/en/getting-started.md) |
| Ouvrir les ports VCN | [docs/oci-vcn-config.md](docs/oci-vcn-config.md) | [docs/en/vcn-setup.md](docs/en/vcn-setup.md) |
| Dépannage | [docs/troubleshooting.md](docs/troubleshooting.md) | [docs/en/troubleshooting.md](docs/en/troubleshooting.md) |
| README complet | *(ce fichier)* | [README.md](README.md) |

## 🤝 Contribuer

Issues et PR bienvenues : nouveaux modpacks (un fichier JSON dans `modpacks/`), corrections de docs, **nouvelles traductions**, idées d'optimisation. Lance `bash tests/run_tests.sh` avant d'ouvrir une PR. L'interface des scripts de maintenance est en français — toute aide pour les traduire est bienvenue.

## 📄 Licence

[MIT](LICENSE)
