# Dépannage — problèmes courants

Arbre de diagnostic universel : **VCN → iptables → service → Java/mods**.
Chaque section suit ce fil.

## « Connection timed out » (le plus fréquent)

Le paquet n'atteint pas la VM. Dans l'ordre :

1. **VCN** : les Ingress Rules sont-elles ouvertes ? (`docs/oci-vcn-config.md`)
   Console → Networking → VCN → Security Lists → vous devez voir TCP 25565,
   UDP 25565, TCP 8443 en source `0.0.0.0/0`.
2. **iptables** : sur les VM Oracle, **ufw ne fonctionne pas** (conflit avec les
   règles OCI). Le setup utilise iptables directement. Vérifiez :
   `ssh ubuntu@IP 'sudo iptables -L INPUT -n --line-numbers | grep 25565'`
   → deux règles ACCEPT doivent apparaître AVANT la ligne REJECT.
   Réparez : relancez `./setup.sh` (idempotent) ou
   `ssh ubuntu@IP 'sudo bash /opt/minecraft/bin/remote_provision.sh ...'`.
3. **Service démarré ?** `./utils/monitor.sh` → doit afficher `active` et le
   port 25565 en écoute (`ss -tln | grep 25565`).
4. **La VM tourne ?** Console Oracle → Compute → Instances → statut Running.
   Après un arrêt Oracle, l'IP publique peut changer : refaites `./setup.sh`.

## « Connection refused » / « No route to host »

Le port est fermé ou le serveur est éteint : étapes 2 et 3 ci-dessus.
« No route to host » est typiquement la règle REJECT d'iptables qui vous
renvoie un refus : règle ACCEPT manquante ou placée après le REJECT.

## Forge : « Error: Could not find or load main class »

Cause : tentative de lancement avec `java -jar server.jar`. Depuis Forge
1.17, le lancement passe obligatoirement par `@unix_args.txt`. Le projet
génère `/opt/minecraft/server/start.sh` correct ; ne lancez jamais le jar
directement. Vérifiez :
`ssh ubuntu@IP 'cat /opt/minecraft/server/start.sh'` → la ligne `exec java
@user_jvm_args.txt @libraries/.../unix_args.txt nogui` doit être présente.

## Crash / « Out of Memory » (OOM Killer)

La VM a 12 Go ; la JVM est plafonnée à 8 Go. Si vous avez augmenté `-Xmx`
au-delà, le noyau Linux tue Java. Diagnostic :
`ssh ubuntu@IP 'journalctl -u minecraft -n 50'` (cherchez `oom-killer`).
Correctif : `-Xmx8G` maximum dans `user_jvm_args.txt`, puis
`ssh ubuntu@IP 'sudo systemctl restart minecraft'`.

## Lag / « Can't keep up! »

1. Réduire `view-distance` et `simulation-distance` à 6 dans
   `/opt/minecraft/server.properties` (via Crafty ou sed + restart).
2. Trop de mods pour 2 OCPU : retirez les gros mods, préférez les packs légers.
3. Vérifier les TPS : `./utils/monitor.sh` (19-20 = parfait, < 15 = problème).
4. Premier démarrage d'un monde moddé : c'est normal pendant 5-10 minutes.

## « IO Netty Error » / rejet de mods à la connexion

Mods différents entre serveur et joueur. Chaque joueur doit avoir EXACTEMENT
le même modpack (même version). Le plus simple : réinstallez le modpack côté
joueur via CurseForge ; côté serveur, `./utils/update.sh` avec le server pack
officiel. Comparez : `ssh ubuntu@IP 'ls /opt/minecraft/server/mods | wc -l'`.

## Crafty inaccessible (https://IP:8443)

1. Ingress Rule TCP 8443 ouverte ? (VCN)
2. `ssh ubuntu@IP 'sudo docker ps'` → conteneur `crafty_controller` « Up » ?
3. `ssh ubuntu@IP 'sudo docker logs --tail 50 crafty_controller'`.
4. Certificat auto-signé : l'avertissement du navigateur est normal.

## « Out of capacity » à la création de la VM

Région saturée : réessayez à une autre heure, un autre jour, ou choisissez
une autre région (région définitive : créez éventuellement un nouveau compte
avec une autre adresse email — la limite « Out of capacity » est par région).

## SSH : « Permission denied (publickey) »

Mauvaise clé ou mauvaise IP. Testez :
`ssh -i /chemin/vers/ssh-key-*.key ubuntu@IP` — l'utilisateur est toujours
`ubuntu` sur les images Ubuntu d'Oracle. Permissions de la clé : `chmod 600`.

## Tout réinstaller

`./uninstall.sh` puis `./setup.sh`. Le monde est sauvegardé si vous acceptez
la sauvegarde finale proposée. En dernier recours : supprimez la VM depuis la
console Oracle et recommencez le guide débutant à l'étape 6.
