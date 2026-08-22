# Opening the Oracle network ports (VCN) — MANDATORY STEP

> 🇬🇧 English | [🇫🇷 Version française](../oci-vcn-config.md)

## Why this step is mandatory

Your VM is protected by **two firewalls** in a row:

| Level | Where it's configured | Who configures it |
|---|---|---|
| 1. VCN Security List (Oracle's cloud) | Oracle web console (or OCI CLI) | **You, once** (this guide) |
| 2. iptables (the Ubuntu VM) | `deploy/configure_iptables.sh` | The installer, automatically |

By default the VCN only allows port 22 (SSH). Until the Ingress Rules are
opened, your server is invisible from Minecraft even if everything else
works. **Budget 3 minutes.**

## Method A — Oracle console (recommended)

1. Sign in at <https://cloud.oracle.com>.
2. ☰ menu (top left) → **Networking** → **Virtual Cloud Networks**.
3. Click your VCN (default name looks like `vcn-20260822-1234...`).
4. In the **Resources** column, click **Security Lists**, then
   **Default Security List for ...**.
5. Click **Add Ingress Rules** and add the three rules below (use
   *Add Another Rule* to enter them in one go):

   | Field | Rule 1 | Rule 2 | Rule 3 |
   |---|---|---|---|
   | Source Type | CIDR | CIDR | CIDR |
   | Source CIDR | `0.0.0.0/0` | `0.0.0.0/0` | `0.0.0.0/0` |
   | IP Protocol | TCP | UDP | TCP |
   | Source Port Range | *(empty)* | *(empty)* | *(empty)* |
   | Destination Port Range | `25565` | `25565` | `8443` |
   | Description | Minecraft TCP | Minecraft UDP | Crafty Panel |

6. Click **Add Ingress Rules**. Takes effect immediately.

> Port 22 (SSH) is already open by default — don't change it.
> `0.0.0.0/0` means “from any address on the Internet”, which is required
> for your friends to connect.

## Method B — OCI CLI script (optional)

If you installed the OCI CLI (`pip install oci-cli && oci setup config`) and `jq`:

```bash
bash deploy/oci_ingress_setup.sh --security-list-ocid ocid1.securitylist.oc1...
```

The OCID is in the console: VCN → Security Lists → your security list →
the **OCID** field (copy button). The script is idempotent: re-running it
creates no duplicates.

## Verifying it works

1. The server must be running: `./utils/monitor.sh` → `active`.
2. From your computer, test the port:
   - Windows PowerShell: `Test-NetConnection <VM_IP> -Port 25565` → `TcpTestSucceeded : True`
   - Linux/macOS: `nc -vz <VM_IP> 25565` → `succeeded`
3. In Minecraft: Multiplayer → Add Server → `<VM_IP>:25565`.

If the server's ping icon stays crossed out, see
[troubleshooting.md](troubleshooting.md) (the “Connection timed out”
section) for the full diagnostic tree (VCN → iptables → service).
