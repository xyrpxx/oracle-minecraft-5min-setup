<div align="center">

# 🎮 Ton propre serveur Minecraft — gratuit, à vie

**Un serveur Minecraft moddé sur l'offre gratuite d'Oracle Cloud.**
Sans abonnement. Sans pub. Sans « le serveur s'éteint après 10 minutes ».

**12 Go de RAM** · **0 €/mois** · **en ligne 24h/24** · aucune compétence requise

[🇬🇧 English](README.md) · **🇫🇷 Français**

![Licence](https://img.shields.io/badge/licence-MIT-green)
![Coût](https://img.shields.io/badge/co%C3%BBt-0%E2%82%AC%2Fmois-success)
![Plateforme](https://img.shields.io/badge/fonctionne%20sur-Windows%20%7C%20macOS%20%7C%20Linux-blue)
![Assistant](https://img.shields.io/badge/assistant-Fran%C3%A7ais%20%7C%20English-informational)

</div>

---

## ⏱️ Commence ici — 4 petites étapes

Ta part : environ **15 minutes de clics**. L'assistant fait le reste.

### 1 · Télécharge ce projet

*1 minute*

Bouton vert **⟵ Code** (en haut à droite de cette page) → **Download ZIP** → dézippe le dossier.

### 2 · Lance l'installateur

*1 minute*

**Windows** — ouvre le dossier et **double-clique sur `start-windows.bat`**

**Mac / Linux** — ouvre un terminal dans ce dossier et tape :

```bash
bash setup.sh
```

### 3 · Suis l'assistant

*~10 minutes, surtout des formulaires*

Choisis le **Mode guide**. Il t'accompagne pour créer ton compte Oracle
gratuit et ta machine — et **attend entre chaque étape**, sans stress.

> 💡 **Appuie sur Entrée** à chaque question pour garder la réponse conseillée.
> Tu ne peux pas vraiment te tromper.

### 4 · Ouvre les ports

*3 minutes, une seule fois*

Trois clics dans la console Oracle pour que tes amis puissent se connecter.
L'assistant ouvre la bonne page et te montre exactement où cliquer.

### 🎉 C'est fini

L'installateur te donne **l'adresse de ton serveur** — la seule chose que
tes amis auront besoin de connaître. Colle-la dans Minecraft :
*Multijoueur → Ajouter un serveur*.

---

## 📦 Ce que tu obtiens

- **Une vraie machine dans le cloud** — 2 cœurs, 12 Go de RAM, 200 Go de disque
- **Toujours allumée** — joue 24h/24, redémarre toute seule après un crash
- **Des mods** — Forge, Fabric, Vanilla, ou un modpack prêt à l'emploi
- **Un tableau de bord web** (optionnel) — démarre/arrête et lis les logs comme un pro
- **Des filets de sécurité** — sauvegarde, restauration, surveillance et mises à jour en une commande

## 🧾 Ce qu'il te faut

- **Minecraft Java Edition** (~30 €, une fois — pas Bedrock/console/mobile)
- Une **carte bancaire** pour la vérification d'identité Oracle
  (rien n'est jamais prélevé en gratuit — une empreinte ~1 $ remboursée)
- **Windows** (avec [Git pour Windows](https://git-scm.com/download/win)), **Mac** ou **Linux**
- C'est tout. Vraiment.

> 💬 L'assistant parle **français et anglais** — il détecte ta langue tout seul.

---

## 🔍 Curieux ou bloqué ? Ouvre seulement ce dont tu as besoin

<details>
<summary><b>📖 Le tutoriel complet</b> — chaque clic, zéro devinette</summary>

<br>

**Étape 0 — le dossier sur ta machine.**
Installe d'abord [Git pour Windows](https://git-scm.com/download/win) si tu es
sous Windows (suivant → suivant → terminer). Récupère le projet :
bouton vert **Code** → **Download ZIP** → dézippe.

**Étape 1 — le compte Oracle** *(10 min, une fois)*

1. Va sur <https://cloud.oracle.com> → **Start for free**
2. Email + mot de passe (note-les), nom, pays, téléphone
3. Carte bancaire pour la vérification — rien n'est prélevé
4. **Région** : prends la plus proche de toi (choix définitif, influe sur le lag)
5. Attends l'email de confirmation (jusqu'à 30 min)

⚠️ Si Oracle propose **« Upgrade to Pay As You Go »** — **refuse**. Gratuit = 0 €.

**Étape 2 — la machine** *(10 min, une fois)*

Console → menu ☰ → **Compute → Instances → Create instance**, puis :

| Champ | À remplir |
|---|---|
| Image | **Ubuntu 22.04 ou 24.04** (pas *Minimal*) |
| Shape | **Ampere → VM.Standard.A1.Flex** · 2 OCPU · 12 Go |
| SSH keys | **Generate a key pair** → **Save Private Key** → **Save Public Key** |

⚠️ Le **fichier de clé privée** est la seule clé de ta machine.
Perdu = serveur perdu. Ne le renomme pas, ne le supprime pas.

Clique **Create**, attends 2–5 min le badge vert **Running**,
puis copie la **Public IP Address** (du genre `129.213.56.123`).

*Erreur « Out of capacity » ?* La région est pleine — réessaie plus tard
ou change de région.

**Étape 3 — l'installateur** *(~10 min)*

Double-clique sur `start-windows.bat` (ou `bash setup.sh`), choisis le
**Mode guide**, puis :

| Question | Conseillé | Pourquoi |
|---|---|---|
| Type de serveur | **Forge** | La voie classique pour jouer avec des mods |
| Version Minecraft | **1.20.1** | Le plus de mods dispo ; la 26.2 marche aussi |
| RAM | **8 Go** | Laisse 4 Go pour la machine elle-même |
| Joueurs | **10** | Confortable avec 12 Go |
| Panel Crafty | **Oui** | Gère le serveur depuis ton navigateur |

Il installe ensuite tout (Java, serveur, pare-feu, redémarrage auto),
démarre le serveur et affiche ton adresse.

**Étape 4 — ouvrir les ports** *(3 min, une fois)* — voir le
[guide dédié avec les clics exacts](docs/oci-vcn-config.md).

**Étape 5 — se connecter.** Minecraft → *Multijoueur → Ajouter un serveur* → `TON_IP:25565`.

**Étape 6 — les mods des joueurs.** Chacun installe l'app
[CurseForge](https://www.curseforge.com/download) → même modpack,
même version → toujours lancer le jeu depuis CurseForge.

**Étape 7 — deviens l'admin.** Rejoins ton serveur **une fois**, puis :

```bash
./utils/console.sh "op TonPseudo"
```

</details>

<details>
<summary><b>🛠️ Gérer ton serveur au quotidien</b> — pense-bête des commandes</summary>

<br>

| Je veux… | Je lance |
|---|---|
| Envoyer une commande de jeu (rendre quelqu'un admin, mettre le jour…) | `./utils/console.sh "op TonPseudo"` |
| Sauvegarder le monde | `./utils/backup.sh` |
| Restaurer une sauvegarde | `./utils/restore.sh` |
| Voir CPU / RAM / joueurs | `./utils/monitor.sh` |
| Mettre à jour Minecraft, Forge ou le modpack | `./utils/update.sh` |
| Réserver le serveur aux joueurs invités | `./security/whitelist_manager.sh add Pseudo` |
| Renforcer la sécurité (conseillé après l'install) | `./security/hardening.sh` |
| Tout supprimer proprement | `./uninstall.sh` |

Toutes ces commandes sont re-lançables — elles réparent plutôt qu'elles ne cassent.

</details>

<details>
<summary><b>🔧 Quelque chose ne marche pas ?</b> — les 7 corrections les plus fréquentes</summary>

<br>

| Symptôme | La solution |
|---|---|
| **Connection timed out** | Les ports ne sont pas ouverts → [guide 3 minutes](docs/oci-vcn-config.md) |
| **Connection refused** | Serveur arrêté → `./utils/monitor.sh`, puis relance via Crafty ou `ssh ubuntu@IP 'sudo systemctl start minecraft'` |
| **Crash / plus de mémoire** | La RAM a été montée au-delà de 8 Go → remets `-Xmx8G` dans `user_jvm_args.txt` et redémarre |
| **Lag, « Can't keep up! »** | Baisse `view-distance` à 6 dans `server.properties`, redémarre |
| **Joueur rejeté : mods différents** | Le client et le serveur n'ont pas le même modpack → même pack, même version |
| **SSH « Permission denied »** | Mauvaise clé ou mauvaise IP ; l'utilisateur est toujours `ubuntu` |
| **La page Crafty ne charge pas** | Vérifie que TCP 8443 est ouvert (VCN), puis `sudo docker logs crafty_controller` |

Arbre de diagnostic complet : [docs/troubleshooting.md](docs/troubleshooting.md)

</details>

<details>
<summary><b>❓ Les questions qu'on pose vraiment</b></summary>

<br>

**C'est vraiment gratuit ?**
Oui. Les ressources utilisées (2 cœurs, 12 Go de RAM, 200 Go de disque,
10 To de trafic) font partie de l'offre *Always Free* d'Oracle — sans date
de fin, sans prélèvement. Ton seul coût : Minecraft Java lui-même (~30 €, une fois).

**Pourquoi Oracle offre ça ?**
Du marketing — ils espèrent que tu passeras un jour au payant.
Tu ne leur dois rien tant que tu restes dans les quotas gratuits.

**Ça marche avec le dernier Minecraft (26.x) ?**
Oui. La version de Java requise est détectée automatiquement depuis les
métadonnées Mojang (Java 25 pour le 26.x — vérifié en démarrant réellement
un serveur 26.2 avec les fichiers de ce projet). Les versions Forge et
Fabric se résolvent aussi toutes seules. 1.20.1 reste la valeur par défaut
simplement parce qu'elle a le plus de mods.

**Combien de joueurs ?**
Vanilla : ~15–20. Modpack léger : 5–10. Gros modpack : 3–5.

**Ça tourne quand mon ordi est éteint ?**
Oui — c'est une machine dans le cloud. 24h/24, avec redémarrage automatique après crash.

**Oracle peut-il reprendre la main ?**
L'offre existe depuis 2018. Et tes sauvegardes (`./utils/backup.sh`) se
récupèrent sur ton ordinateur — ton monde t'appartient toujours.

</details>

<details>
<summary><b>🏗️ Fonctionnement & compatibilité</b> — pour les curieux</summary>

<br>

**L'architecture en une phrase :** `setup.sh` tourne sur ton ordinateur et
pilote ta machine cloud en SSH ; tout le gros du travail se passe là-bas,
via `deploy/remote_provision.sh`.

Garanties intégrées d'office :

- Le serveur tourne sous un utilisateur `minecraft` dédié — jamais en root
- Amorçage Forge moderne (`@unix_args.txt`, la seule façon correcte depuis la 1.17)
- Règles pare-feu insérées exactement là où les images Ubuntu d'Oracle les
  veulent (iptables brut — `ufw` échoue silencieusement sur Oracle)
- JVM réglée pour le processeur ARM (ZGC générationnel, mémoire réservée au démarrage)
- Chaque script est **idempotent** — le relancer répare, jamais ne duplique

| Couche | Vérifié contre |
|---|---|
| Ton ordinateur | Windows (Git Bash) · macOS (compatible bash 3.2) · Linux |
| Machine cloud | Ubuntu 22.04 / 24.04 LTS · ARM64 (Ampere A1) |
| Minecraft | 1.20.1 → **26.2** (Java 21 ou 25 auto-installé selon la version) |
| Qualité | 370+ assertions automatisées : `bash tests/run_tests.sh` |

</details>

<details>
<summary><b>📚 Toute la documentation</b></summary>

<br>

| Guide | Français | English |
|---|---|---|
| Guide débutant complet | [guide-debutant-fr.md](docs/guide-debutant-fr.md) | [getting-started.md](docs/en/getting-started.md) |
| Ouvrir les ports | [oci-vcn-config.md](docs/oci-vcn-config.md) | [vcn-setup.md](docs/en/vcn-setup.md) |
| Dépannage | [troubleshooting.md](docs/troubleshooting.md) | [troubleshooting.md](docs/en/troubleshooting.md) |

**Contribuer** — issues et PR bienvenues (un nouveau modpack = un simple
fichier JSON, et traduire les scripts de maintenance est une excellente
première PR). Lance la suite de tests avant de proposer.

**Licence** — [MIT](LICENSE)

</details>

---

<div align="center">

Fait pour les joueurs qui préfèrent jouer que configurer. 🎮

</div>
