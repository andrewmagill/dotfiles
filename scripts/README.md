# Optional provisioning scripts

Machine-specific setup steps that are **deliberately kept out of `bootstrap.sh`**.
They change system state (kernel modules, services, third-party repos) and some
require a reboot, so they're *run-when-you-mean-it* rather than part of the
unattended bootstrap flow. They're also not Stow packages — nothing here lands in
`$HOME`; it's system configuration.

Each script is guarded (bails on the wrong machine), idempotent (safe to re-run),
and reversible (rollback steps below).

---

## `setup-nvidia-rocky.sh` — proprietary NVIDIA driver + CUDA (Rocky/RHEL)

Replaces the open `nouveau` driver with NVIDIA's proprietary driver via RPM
Fusion's `akmod-nvidia` (which auto-rebuilds the kernel module on every kernel
update), plus the CUDA runtime.

**Prerequisites**
- An NVIDIA GPU (the script refuses otherwise).
- **Secure Boot disabled.** RPM Fusion's akmod modules are unsigned and won't load
  with Secure Boot on; the script aborts rather than risk a black screen. To use
  it with Secure Boot on, enroll a signing key (MOK) first. (The check works with
  or without `mokutil` — it falls back to reading the EFI variable directly.)
- **A fully updated machine, rebooted into its newest kernel.** The driver module
  is built for the *running* kernel, but the next boot starts the *newest
  installed* kernel — the script requires those to match, and requires a matching
  `kernel-devel` to exist, before it changes anything.
- **No pending offline update.** If KDE Discover / GNOME Software has an update
  staged to "install on restart" (`/system-update` exists), the script refuses:
  that update would run on the very reboot the script asks for, with the screen
  sitting black for minutes right after nouveau was blacklisted — an invitation
  to power-cycle and corrupt the update mid-write. Apply it first, then re-run.

**Run**
```sh
scripts/setup-nvidia-rocky.sh      # prompts before doing anything; -y to skip
sudo systemctl reboot
```

**What it installs:** `akmod-nvidia` (driver, auto-rebuilding), and
`xorg-x11-drv-nvidia-cuda` (CUDA runtime + `nvidia-smi`), and `nvidia-settings`.
It enables EPEL + CRB + RPM Fusion, builds the module immediately, and blacklists
nouveau (via the packages' post-install step).

**Failure model — preflight, then automatic rollback**

The script is structured so the *point of no return comes last, behind proof*:

1. **Preflight (read-only).** Every check that can fail runs before any change:
   GPU present, Secure Boot off, no staged offline update, running kernel ==
   newest installed, matching `kernel-devel` installed or available. A preflight
   failure leaves the machine untouched.
2. **Changes under a rollback trap.** Before the first install, the script
   records the current `dnf history` transaction ID. From then on, *any* failure
   (a dnf error, a failed akmods build, Ctrl-C) triggers
   `dnf history rollback <id>`, which unwinds every package transaction the
   script made — driver, repos, the akmods-built kmod rpm — then re-disables CRB
   if the script enabled it and rebuilds the initramfs. You're back where you
   started instead of rebooting into a driverless, low-res desktop.
3. **Success requires proof.** The module build is a hard failure if it fails
   (no "it'll retry at boot" optimism — a build that fails now fails at boot
   too), and the script only reports success after `modinfo` confirms a loadable
   module exists for the running kernel.

*Limits:* rollback relies on dnf, so it cannot protect against a power loss in
the middle of an rpm write — no shell script can. Crash-proof system changes
need filesystem snapshots (LVM/Btrfs + `boom` boot entries) or a transactional
OS (rpm-ostree, `transactional-update`). For a driver install, preflight +
rollback is the pragmatic middle.

**Verify after reboot**
```sh
nvidia-smi                                       # driver + GPU status
lspci -k -d ::0300 | grep -i 'in use'            # -> nvidia (not nouveau)
cat /sys/module/nvidia_drm/parameters/modeset    # -> Y (KMS on; good for Wayland)
```

**Rollback to nouveau**
```sh
sudo dnf remove '*nvidia*'
sudo dracut --force
sudo systemctl reboot
```

> This installs the CUDA *runtime* only. The full toolkit (`nvcc`, headers) for
> compiling CUDA code is a separate step via NVIDIA's official repo.

---

## `disable-iscsi-offload-rocky.sh` — silence cnic/bnx2i warnings (Rocky/RHEL)

Stops the boot-time kernel warnings:

```
Warning: Unmaintained driver is detected: cnic
Warning: Unmaintained driver is detected: bnx2i
```

These are Broadcom NetXtreme II iSCSI **offload** drivers for enterprise storage
HBAs the machine doesn't have. They load because the iSCSI initiator services
pull in *every* offload transport at boot, even with no iSCSI configured. The
script blocks the offload modules (`bnx2i`, `cnic`, `be2iscsi`, `cxgb4i`,
`libcxgbi`) and disables the unused initiator services. Plain software iSCSI
(`iscsi_tcp`) is left untouched.

**Safety:** it refuses to run if the machine actually uses iSCSI (checks for any
active session or configured node via `iscsiadm`).

**Run**
```sh
scripts/disable-iscsi-offload-rocky.sh
```

**Verify**
```sh
lsmod | grep -Ei 'bnx2i|cnic'                  # empty
journalctl -k -b 0 | grep -i unmaintained      # empty on the next boot
```

**Rollback** (if you ever attach an iSCSI target)
```sh
sudo rm /etc/modprobe.d/blacklist-iscsi-offload.conf
sudo systemctl enable --now iscsid.socket iscsiuio.socket
```
