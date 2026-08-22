# Guide Débutant — Serveur Minecraft gratuit sur Oracle Cloud

## Sommaire
1. Introduction
2. Qu'est-ce qu'un serveur Minecraft ?
3. Qu'est-ce qu'Oracle Cloud et pourquoi c'est vraiment gratuit ?
4. Prérequis (5 minutes de lecture)
5. Créer un compte Oracle Cloud
6. Créer la machine virtuelle (VM)
7. Lancer setup.sh (5 minutes)
8. Ouvrir les ports du VCN (3 minutes — OBLIGATOIRE)
9. Se connecter avec Minecraft
10. Installer les mods côté joueur (CurseForge)
11. Inviter ses amis
12. Administrer au quotidien (sauvegardes, surveillance, mise à jour)
13. FAQ

---

## 1. Introduction

Objectif : un serveur Minecraft moddé, gratuit, allumé 24h/24, contrôlable
depuis une simple page web (Crafty), en moins de 15 minutes au total — dont
5 minutes de configuration technique grâce à `setup.sh`.

## 2. Qu'est-ce qu'un serveur Minecraft ?

En solo, le monde tourne sur votre PC et s'arrête quand vous fermez le jeu.
Un serveur dédié est un ordinateur qui fait tourner le monde en permanence :
vos amis s'y connectent quand ils veulent, le monde persiste, et vous choisissez
les mods/règles. C'est « votre appartement » plutôt que « votre chambre ».

## 3. Qu'est-ce qu'Oracle Cloud et pourquoi c'est vraiment gratuit ?

Oracle Cloud Infrastructure (OCI) loue des ordinateurs dans des datacenters.
Leur offre **Always Free** inclut, à vie et sans engagement :

| Ressource | Quota gratuit (2026) | Pour Minecraft |
|---|---|---|
| CPU (ARM Ampere A1) | 2 OCPU | Suffisant pour 3-10 joueurs |
| RAM | 12 Go | Largement (les hébergeurs gratuits donnent 1-2 Go) |
| Disque | 200 Go | Un monde moddé = 5-30 Go |
| Sortie réseau | 10 To/mois | Illimité en pratique |

C'est de l'acquisition commerciale : Oracle espère que vous passerez au payant
plus tard. Le palier gratuit ne se ferme pas au bout de 12 mois (contrairement
à AWS/Azure). La carte bancaire demandée à l'inscription sert uniquement de
vérification d'identité : aucune somme n'est prélevée tant que vous restez
dans ces quotas (ne cochez jamais « Upgrade to Pay As You Go » par accident).

## 4. Prérequis

- Minecraft **Java Edition** (~30 €, achat unique — PAS Bedrock/console/mobile).
- Une carte bancaire pour la vérification Oracle (pré-autorisation ~1 $ remboursée).
- Un terminal : Linux, macOS, ou **Git Bash sur Windows** (inclus avec Git pour
  Windows). Sur Windows : installez Git pour Windows, clic droit dans un dossier
  → « Open Git Bash here ».
- 15 minutes.

## 5. Créer un compte Oracle Cloud

1. <https://cloud.oracle.com> → **Start for free**.
2. Email, mot de passe, nom, pays, téléphone (vérification SMS).
3. Vérification par carte bancaire (aucun débit ; les cartes virtuelles
   jetables sont souvent refusées).
4. Choix de la **région (Home Region)** : c'est définitif. Depuis la France :
   UK South (Londres) ou Germany Central (Francfort) pour un ping de 15-35 ms.
5. Attendez l'email de confirmation (parfois 30 min), puis connectez-vous.

## 6. Créer la machine virtuelle (VM)

Dans la console : menu ☰ → **Compute** → **Instances** → **Create instance**.

- **Name** : ce que vous voulez (ex. `minecraft`).
- **Image and Shape** :
  - Edit → Image : **Ubuntu** 22.04 ou 24.04 (pas « Minimal »).
  - Edit → Shape : **Ampere** → **VM.Standard.A1.Flex** avec :
    - OCPUs : **2**
    - Memory : **12 GB**
    (C'est l'intégralité du quota gratuit ; si le bouton reste bloqué à moins,
    votre compte est peut-être encore en cours de validation.)
- **Networking** : laissez par défaut, vérifiez **Assign a public IPv4 address**.
- **Add SSH keys** : ⚠️ étape critique —
  1. « Generate a key pair »
  2. **Save Private Key** → conservez ce fichier (`ssh-key-2026-XX-XX.key`)
     précieusement : sans lui, plus aucun accès à la VM.
  3. **Save Public Key** (auto-upload ou upload manuel).
- Cliquez **Create** (2-5 minutes), puis notez l'**IP publique** affichée
  sur la page de l'instance.

En cas d'erreur « Out of capacity » : réessayez plus tard ou changez de région
(voir troubleshooting).

## 7. Lancer setup.sh (5 minutes)

Dans un terminal (Git Bash sous Windows), dans le dossier du projet :

```bash
./setup.sh
```

Le script vous demande : l'IP publique, le chemin de la clé privée, le type de
serveur (Vanilla / Forge / Fabric / Modpack), la RAM (8 Go conseillé), le
nombre de joueurs, et si vous voulez le panel web Crafty. Il installe ensuite
tout sur la VM : Java 21, le serveur, le pare-feu, le démarrage automatique
(systemd), et affiche l'adresse de connexion finale.

Passez ensuite à l'étape 8 ci-dessous — sans elle, personne ne peut se connecter.

## 8. Oublis interdits : ouvrir les ports du VCN

Suivez `docs/oci-vcn-config.md` (3 minutes, des clics dans la console Oracle).
Résumé : VCN → Security Lists → Add Ingress Rules → TCP 25565, UDP 25565,
TCP 8443, source `0.0.0.0/0`.

## 9. Se connecter avec Minecraft

1. Minecraft Java Edition → **Multijoueur** → **Ajouter un serveur**.
2. Adresse : `IP_DE_VOTRE_VM:25565` (le `:25565` est optionnel mais explicite).
3. Rejoignez ! Si ça échoue : `docs/troubleshooting.md`.

Le panel Crafty (si installé) : `https://IP_DE_VOTRE_VM:8443` — acceptez
l'avertissement de certificat auto-signé, connectez-vous (identifiants
affichés par Crafty au premier lancement, visibles via
`ssh ubuntu@IP 'sudo docker logs crafty_controller'`) et changez le mot de passe.

## 10. Installer les mods côté joueur (CurseForge)

Un serveur moddé exige que **chaque joueur** ait exactement les mêmes mods.

1. Installez l'app **CurseForge** (<https://www.curseforge.com/download>).
2. Onglet Minecraft → Browse Modpacks → cherchez le modpack du serveur
   (ex. « Better Minecraft [Forge] » version **1.20.1**) → Install.
3. Lancez le jeu **depuis CurseForge** (bouton Play).

Pour un serveur Forge « custom » : mêmes versions de Minecraft ET de Forge
que le serveur (visible dans `./utils/monitor.sh` ou la console Crafty).

## 11. Inviter vos amis

Envoyez-leur ce message (adaptez) :

> 🎮 Serveur Minecraft moddé prêt !
> Adresse : `IP:25565`
> Il vous faut : Minecraft Java (~30 €, achat unique) + l'app CurseForge +
> le modpack « NOM » version 1.20.1 (Install, puis Play depuis CurseForge).
> Ensuite : Multijoueur → Ajouter un serveur → l'adresse ci-dessus.

Pensez à la whitelist pour un serveur privé :
`./security/whitelist_manager.sh add Pseudo`.

## 12. Administrer au quotidien

| Besoin | Commande |
|---|---|
| Sauvegarder | `./utils/backup.sh` |
| Restaurer | `./utils/restore.sh` |
| Surveiller (CPU, RAM, joueurs, TPS) | `./utils/monitor.sh` |
| Mettre à jour le serveur | `./utils/update.sh` |
| Sécuriser la VM | `./security/hardening.sh` |
| Gérer la whitelist | `./security/whitelist_manager.sh` |
| Tout supprimer | `./uninstall.sh` |

Le serveur redémarre tout seul après un crash ou un reboot de la VM (systemd).

## 13. FAQ

- **C'est vraiment gratuit ?** Oui — 0 €/mois dans les quotas Always Free ;
  seul coût : Minecraft Java (~30 €, une fois).
- **Combien de joueurs ?** Vanilla : 15-20 ; moddé léger : 5-10 ;
  gros modpacks : 3-5 avec 8 Go de RAM.
- **Le serveur tourne quand je ne joue pas ?** Oui, 24/7.
- **Je peux changer de modpack plus tard ?** Oui : `./utils/update.sh`.
- **Oracle peut-il couper l'offre ?** Le risque existe théoriquement ; en
  pratique l'offre existe depuis 2018. Vos sauvegardes (`utils/backup.sh`)
  restent récupérables à tout moment.
