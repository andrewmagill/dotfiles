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
  it with Secure Boot on, enroll a signing key (MOK) first.

**Run**
```sh
scripts/setup-nvidia-rocky.sh      # prompts before doing anything; -y to skip
sudo systemctl reboot
```

**What it installs:** `akmod-nvidia` (driver, auto-rebuilding), and
`xorg-x11-drv-nvidia-cuda` (CUDA runtime + `nvidia-smi`), and `nvidia-settings`.
It enables EPEL + CRB + RPM Fusion, builds the module immediately, and blacklists
nouveau (via the packages' post-install step).

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
