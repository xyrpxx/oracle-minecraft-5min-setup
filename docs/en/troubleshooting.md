# Troubleshooting — common problems

> 🇬🇧 English | [🇫🇷 Version française](../troubleshooting.md)

Universal diagnostic tree: **VCN → iptables → service → Java/mods**.
Each section follows that thread.

## “Connection timed out” (most common)

The packet never reaches the VM. In order:

1. **VCN**: are the Ingress Rules open? ([vcn-setup.md](vcn-setup.md))
   Console → Networking → VCN → Security Lists → you must see TCP 25565,
   UDP 25565, TCP 8443 with source `0.0.0.0/0`.
2. **iptables**: on Oracle VMs, **ufw does not work** (conflict with OCI's
   rules). This project uses iptables directly. Check:
   `ssh ubuntu@IP 'sudo iptables -L INPUT -n --line-numbers | grep 25565'`
   → two ACCEPT rules must appear BEFORE the REJECT line.
   Fix: re-run `./setup.sh` (idempotent) or
   `ssh ubuntu@IP 'sudo bash /opt/minecraft/bin/remote_provision.sh ...'`.
3. **Service running?** `./utils/monitor.sh` → must show `active` with
   port 25565 listening (`ss -tln | grep 25565`).
4. **VM running?** Oracle console → Compute → Instances → status Running.
   After an Oracle stop, the public IP may change: re-run `./setup.sh`.

## “Connection refused” / “No route to host”

Port closed or server down: steps 2 and 3 above. “No route to host” is
typically iptables' REJECT rule answering you: a missing ACCEPT rule, or
one placed after the REJECT.

## Forge: “Error: Could not find or load main class”

Cause: launching with `java -jar server.jar`. Since Forge 1.17, startup
must go through `@unix_args.txt`. This project generates a correct
`/opt/minecraft/server/start.sh`; never launch the jar directly. Check:
`ssh ubuntu@IP 'cat /opt/minecraft/server/start.sh'` → the line
`exec java @user_jvm_args.txt @libraries/.../unix_args.txt nogui` must be
present.

## Crash / “Out of Memory” (OOM killer)

The VM has 12 GB; the JVM is capped at 8 GB. If you raised `-Xmx` beyond
that, the Linux kernel kills Java. Diagnose:
`ssh ubuntu@IP 'journalctl -u minecraft -n 50'` (look for `oom-killer`).
Fix: `-Xmx8G` maximum in `user_jvm_args.txt`, then
`ssh ubuntu@IP 'sudo systemctl restart minecraft'`.

## Lag / “Can't keep up!”

1. Lower `view-distance` and `simulation-distance` to 6 in
   `/opt/minecraft/server.properties` (via Crafty or sed + restart).
2. Too many mods for 2 OCPUs: drop the heavy mods, prefer lighter packs.
3. Check TPS: `./utils/monitor.sh` (19–20 = perfect, < 15 = problem).
4. First start of a modded world: normal for 5–10 minutes.

## “IO Netty Error” / mod rejection on join

Server and client mods differ. Every player must have EXACTLY the same
modpack (same version). Simplest: reinstall the modpack on the player side
via CurseForge; on the server side, `./utils/update.sh` with the official
server pack. Compare:
`ssh ubuntu@IP 'ls /opt/minecraft/server/mods | wc -l'`.

## Crafty unreachable (https://IP:8443)

1. TCP 8443 ingress rule open? (VCN)
2. `ssh ubuntu@IP 'sudo docker ps'` → container `crafty_controller` “Up”?
3. `ssh ubuntu@IP 'sudo docker logs --tail 50 crafty_controller'`.
4. Self-signed certificate: the browser warning is normal.

## “Out of capacity” when creating the VM

Saturated region: retry at another time/day, or pick another region
(regions are permanent: possibly create a new account with another email —
the “Out of capacity” limit is per region).

## SSH: “Permission denied (publickey)”

Wrong key or wrong IP. Test:
`ssh -i /path/to/ssh-key-*.key ubuntu@IP` — the user is always `ubuntu`
on Oracle's Ubuntu images. Key permissions: `chmod 600`.

## Reinstalling everything

`./uninstall.sh` then `./setup.sh`. The world is saved if you accept the
final backup offered by the uninstaller. Last resort: delete the VM from
the Oracle console and restart the beginner guide at step 6.
