#!/usr/bin/env bash
# Opt-in provisioning: proprietary NVIDIA driver + CUDA runtime on Rocky/RHEL,
# via RPM Fusion's akmod-nvidia (auto-rebuilds the kernel module on kernel
# updates). Replaces the open `nouveau` driver.
#
#   scripts/setup-nvidia-rocky.sh [-y|--yes]
#
# This is DELIBERATELY not called by bootstrap.sh: it swaps the live display
# driver and requires a reboot, so it's run-when-you-mean-it, not part of the
# unattended flow. The packages come from a third-party repo (RPM Fusion), which
# is why they're here and not in packages/dnf.txt.
#
# Secure Boot note: RPM Fusion akmod modules are UNSIGNED. With Secure Boot
# enabled they won't load until you enroll a signing key (MOK) — this script
# refuses to run in that case rather than risk a black screen. Disable Secure
# Boot in UEFI, or follow RPM Fusion's kmodgenca/mokutil signing guide first.

set -euo pipefail

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mWARN:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

ASSUME_YES=0
[[ "${1:-}" == "-y" || "${1:-}" == "--yes" ]] && ASSUME_YES=1

# --- guards -----------------------------------------------------------------
command -v dnf >/dev/null 2>&1 || die "dnf not found; this script targets Rocky/RHEL."

# NVIDIA GPU present? PCI vendor 10de. Refuse otherwise — no point, and a wrong
# machine shouldn't get nouveau blacklisted.
lspci -nn 2>/dev/null | grep -qiE '\[10de:' \
  || die "No NVIDIA GPU (PCI vendor 10de) detected; refusing to install the driver."

# Secure Boot: unsigned akmod modules won't load with SB on -> black screen.
if command -v mokutil >/dev/null 2>&1 && mokutil --sb-state 2>/dev/null | grep -qi 'enabled'; then
  warn "Secure Boot is ENABLED. RPM Fusion's akmod modules are unsigned and will"
  warn "not load until you enroll a signing key (MOK), which this script does not"
  warn "set up. Disable Secure Boot in UEFI, or sign the module first."
  die  "Aborting to avoid booting to a black screen."
fi

# Idempotent: nothing to do if the driver is already installed.
if rpm -q akmod-nvidia >/dev/null 2>&1; then
  log "akmod-nvidia already installed — nothing to do."
  log "Verify with: nvidia-smi   (reboot first if you just installed it)"
  exit 0
fi

# --- confirm ----------------------------------------------------------------
el="$(rpm -E %rhel)"   # major EL version, e.g. 10
cat <<EOF

  This will configure the proprietary NVIDIA driver on THIS machine:
    * enable EPEL + CRB + RPM Fusion (free & nonfree) for EL${el}
    * install: akmod-nvidia  xorg-x11-drv-nvidia-cuda  nvidia-settings
    * build the kernel module (akmods) and blacklist nouveau
  A REBOOT is required afterward.

EOF
if [[ "$ASSUME_YES" -ne 1 ]]; then
  read -rp "Proceed? [y/N] " reply
  [[ "$reply" =~ ^[Yy]$ ]] || die "Cancelled."
fi

# --- repos ------------------------------------------------------------------
# dnf-plugins-core provides `dnf config-manager`; EPEL + CRB satisfy RPM Fusion
# build/runtime deps (RPM Fusion on EL requires both).
log "Enabling EPEL, CRB, and dnf plugins"
sudo dnf install -y dnf-plugins-core epel-release
sudo dnf config-manager --set-enabled crb

log "Enabling RPM Fusion (free + nonfree) for EL${el}"
sudo dnf install -y \
  "https://mirrors.rpmfusion.org/free/el/rpmfusion-free-release-${el}.noarch.rpm" \
  "https://mirrors.rpmfusion.org/nonfree/el/rpmfusion-nonfree-release-${el}.noarch.rpm"

# --- driver -----------------------------------------------------------------
# akmod-nvidia            : the driver as an auto-rebuilding akmod (+ pulls kernel-devel)
# xorg-x11-drv-nvidia-cuda: CUDA runtime libs (libcuda) + nvidia-smi
# nvidia-settings         : the control-panel GUI
# The nvidia packages blacklist nouveau and regenerate the initramfs in a
# post-install step, so no manual dracut edit is needed here.
log "Installing akmod-nvidia + CUDA runtime + nvidia-settings"
sudo dnf install -y akmod-nvidia xorg-x11-drv-nvidia-cuda nvidia-settings

# Build the module now so the next boot comes up on nvidia instead of spending
# the first boot still on nouveau while akmods builds in the background.
log "Building the NVIDIA kernel module for $(uname -r) (can take a few minutes)"
sudo akmods --force --kernels "$(uname -r)" \
  || warn "akmods build reported an issue; it will retry automatically at boot."

if modinfo -F version nvidia >/dev/null 2>&1; then
  log "NVIDIA kernel module built: $(modinfo -F version nvidia 2>/dev/null)"
else
  warn "NVIDIA module not visible yet; it should finish building during boot."
fi

cat <<'EOF'

  Done. Next steps:
    1. Reboot:   sudo systemctl reboot
    2. Verify after reboot:
         nvidia-smi                                  # driver + GPU status
         lspci -k -d ::0300 | grep -i 'in use'       # -> nvidia (not nouveau)
         cat /sys/module/nvidia_drm/parameters/modeset   # -> Y (KMS on, good for Wayland)

  Want the full CUDA *toolkit* (nvcc, headers) for compiling CUDA code? That's a
  separate step via NVIDIA's repo; this installed only the runtime.

  Rollback to nouveau:
    sudo dnf remove '*nvidia*'
    sudo dracut --force
    sudo systemctl reboot
EOF
