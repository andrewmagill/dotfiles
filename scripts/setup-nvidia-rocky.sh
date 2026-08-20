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
# Failure model (see scripts/README.md for the full rationale):
#   * PREFLIGHT: every check that can fail runs before anything is changed, and
#     the checks encode the ways a driver install can leave a machine unbootable
#     into a working desktop: wrong kernel running, no matching kernel-devel, a
#     staged offline update waiting to fire on the very reboot we recommend, or
#     Secure Boot silently rejecting the unsigned module.
#   * ROLLBACK: once changes begin, any failure triggers an automatic
#     `dnf history rollback` to the pre-script transaction, so a half-installed
#     driver never survives to the reboot. What this can and cannot protect
#     against is documented in the README.
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

# =============================================================================
# Preflight — read-only checks, in "cheapest and most fundamental first" order.
# Nothing below this section runs a single state-changing command until the
# confirmation prompt, so a preflight failure always leaves the machine as-is.
# =============================================================================

command -v dnf >/dev/null 2>&1 || die "dnf not found; this script targets Rocky/RHEL."

# NVIDIA GPU present? PCI vendor 10de. Refuse otherwise — no point, and a wrong
# machine shouldn't get nouveau blacklisted.
lspci -nn 2>/dev/null | grep -qiE '\[10de:' \
  || die "No NVIDIA GPU (PCI vendor 10de) detected; refusing to install the driver."

# Secure Boot: unsigned akmod modules won't load with SB on -> black screen.
# An earlier version only checked when mokutil happened to be installed, which
# silently skipped the guard on minimal installs — exactly when it matters.
# Now: legacy BIOS can't do Secure Boot at all; on UEFI prefer mokutil, and
# fall back to reading the SecureBoot EFI variable directly (its payload is
# 4 attribute bytes followed by 1 value byte; 1 = enabled). A missing variable
# means the firmware doesn't implement Secure Boot, i.e. it's off.
secure_boot_enabled() {
  [[ -d /sys/firmware/efi ]] || return 1
  if command -v mokutil >/dev/null 2>&1; then
    mokutil --sb-state 2>/dev/null | grep -qi 'enabled'
    return
  fi
  local vars=(/sys/firmware/efi/efivars/SecureBoot-*)
  [[ -r "${vars[0]:-}" ]] || return 1
  [[ "$(od -An -tu1 -j4 -N1 "${vars[0]}" 2>/dev/null | tr -d ' ')" == "1" ]]
}
if secure_boot_enabled; then
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

# A staged systemd offline update (KDE Discover / GNOME Software "install on
# restart") applies itself on the NEXT boot — the very reboot this script tells
# you to do. During that update the screen can sit black/idle for minutes, and
# with nouveau freshly blacklisted it's easy to mistake for a hang and
# power-cycle, interrupting rpm mid-transaction (which is how you end up with a
# half-installed kernel). Refuse until it has been applied.
if [[ -L /system-update || -e /system-update ]]; then
  die "A staged offline update is pending (/system-update exists). Reboot to let
       it apply FIRST — the screen may look idle for a while; do NOT power off —
       then re-run this script."
fi

running_kernel="$(uname -r)"

# akmods builds the module for the RUNNING kernel, but the next boot starts the
# NEWEST INSTALLED kernel. If those differ, the reboot lands on a kernel with no
# nvidia module and a blacklisted nouveau — a low-res, driverless desktop.
# Require them to match; "reboot first" is the fix, not something to work around.
newest_kernel="$(rpm -q kernel-core --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' 2>/dev/null | sort -V | tail -n1 || true)"
if [[ -n "$newest_kernel" && "$newest_kernel" != "$running_kernel" ]]; then
  die "Running kernel ($running_kernel) is not the newest installed
       ($newest_kernel). Reboot into the newest kernel first, then re-run."
fi

# The akmod build needs kernel-devel matching the RUNNING kernel. Left to its
# own devices dnf pulls the NEWEST kernel-devel, and on a not-fully-updated
# machine that silently mismatches and the build fails. Verify the matching
# package is installed or still downloadable before touching anything, and
# install it by exact version later. (repoquery is read-only; it may download
# repo metadata, nothing more.)
if ! rpm -q "kernel-devel-${running_kernel}" >/dev/null 2>&1; then
  log "Checking repos for kernel-devel-${running_kernel} (read-only)"
  if ! dnf repoquery --quiet "kernel-devel-${running_kernel}" 2>/dev/null | grep -q .; then
    die "kernel-devel-${running_kernel} is not installed and not available in the
       repos — the running kernel is likely older than the repos carry. Run
       'sudo dnf upgrade -y', reboot into the new kernel, then re-run this script."
  fi
fi

# --- confirm ----------------------------------------------------------------
el="$(rpm -E %rhel)"   # major EL version, e.g. 10
cat <<EOF

  This will configure the proprietary NVIDIA driver on THIS machine:
    * enable EPEL + CRB + RPM Fusion (free & nonfree) for EL${el}
    * install: akmod-nvidia  xorg-x11-drv-nvidia-cuda  nvidia-settings
    * build the kernel module (akmods) and blacklist nouveau
  A REBOOT is required afterward.

  If anything fails along the way, all package changes are rolled back
  automatically (dnf history rollback), leaving the machine as it is now.

EOF
if [[ "$ASSUME_YES" -ne 1 ]]; then
  read -rp "Proceed? [y/N] " reply
  [[ "$reply" =~ ^[Yy]$ ]] || die "Cancelled."
fi

# =============================================================================
# Rollback arming. From here to the end, the EXIT trap guarantees that any
# failure — a dnf error, a failed akmods build, the final verification, even a
# Ctrl-C — unwinds every dnf transaction the script made. An EXIT trap (rather
# than ERR) also catches `die` and `set -e` exits.
#
# What it covers: everything dnf did (repos, packages, the akmods-built kmod
# rpm), plus re-disabling CRB (a config edit dnf history doesn't track).
# What it can't cover: a power loss in the middle of an rpm write — that needs
# filesystem snapshots (see README), not a shell script.
# =============================================================================

# The most recent dnf transaction ID *before* our changes: first data row of
# `dnf history list` whose first |-separated column is a number. Everything
# after this ID is ours to undo.
pre_tx="$(sudo dnf history list 2>/dev/null \
  | awk -F'|' '$1 ~ /^[[:space:]]*[0-9]+[[:space:]]*$/ {gsub(/[[:space:]]/,"",$1); print $1; exit}')"
[[ -n "$pre_tx" ]] || warn "Couldn't read the dnf history position — automatic rollback disabled for this run."

# `dnf config-manager --set-enabled crb` is a repo-file edit, invisible to
# dnf history — remember whether we're the ones turning it on.
crb_was_enabled=0
dnf repolist --enabled 2>/dev/null | grep -qiE '^crb\b' && crb_was_enabled=1

changes_begun=0
success=0
on_exit() {
  local rc=$?
  trap - EXIT
  (( success )) && exit "$rc"
  (( changes_begun )) || exit "$rc"   # failed in preflight/confirm: nothing to undo
  warn "Install did not complete — rolling back package changes."
  if [[ -n "$pre_tx" ]] && sudo dnf history rollback "$pre_tx" -y; then
    # Undoing the packages restores nouveau's files; rebuild the initramfs so
    # the next boot actually uses them (mirrors the manual rollback in the
    # README — the nvidia %postun mostly handles this, this is the guarantee).
    (( crb_was_enabled )) || sudo dnf config-manager --set-disabled crb || true
    sudo dracut --force || warn "initramfs rebuild failed; run: sudo dracut --force"
    warn "Rollback complete — the machine is back to its pre-script state."
  else
    warn "AUTOMATIC ROLLBACK FAILED (or was disabled). Roll back manually:"
    warn "  sudo dnf history list        # undo everything after ID ${pre_tx:-<unknown>}"
    warn "  sudo dnf remove '*nvidia*' && sudo dracut --force"
  fi
  exit "$rc"
}
trap on_exit EXIT

# --- repos ------------------------------------------------------------------
# dnf-plugins-core provides `dnf config-manager`; EPEL + CRB satisfy RPM Fusion
# build/runtime deps (RPM Fusion on EL requires both).
changes_begun=1
log "Enabling EPEL, CRB, and dnf plugins"
sudo dnf install -y dnf-plugins-core epel-release
sudo dnf config-manager --set-enabled crb

log "Enabling RPM Fusion (free + nonfree) for EL${el}"
sudo dnf install -y \
  "https://mirrors.rpmfusion.org/free/el/rpmfusion-free-release-${el}.noarch.rpm" \
  "https://mirrors.rpmfusion.org/nonfree/el/rpmfusion-nonfree-release-${el}.noarch.rpm"

# --- driver -----------------------------------------------------------------
# kernel-devel-<running>  : pinned to the RUNNING kernel so akmods can't mismatch
#                           (satisfying the dep ourselves stops dnf pulling newest)
# akmod-nvidia            : the driver as an auto-rebuilding akmod
# xorg-x11-drv-nvidia-cuda: CUDA runtime libs (libcuda) + nvidia-smi
# nvidia-settings         : the control-panel GUI
# The nvidia packages blacklist nouveau and regenerate the initramfs in a
# post-install step, so no manual dracut edit is needed here.
log "Installing kernel-devel-${running_kernel} + akmod-nvidia + CUDA runtime + nvidia-settings"
sudo dnf install -y "kernel-devel-${running_kernel}" \
  akmod-nvidia xorg-x11-drv-nvidia-cuda nvidia-settings

# Build the module now, and treat a failed build as a hard failure. An earlier
# version warned and hoped the boot-time retry would succeed — but a build that
# fails here fails at boot for the same reason, and by then nouveau is
# blacklisted and you're staring at a low-res, driverless desktop. Failing here
# instead triggers the automatic rollback above.
log "Building the NVIDIA kernel module for ${running_kernel} (can take a few minutes)"
sudo akmods --force --kernels "$running_kernel"

# Point of no return is only crossed on PROOF: the module must exist for the
# running kernel. modinfo failing here means the reboot would break the
# desktop, so it's a failure (-> rollback), not a warning.
log "Verifying the built module"
modinfo -k "$running_kernel" nvidia >/dev/null 2>&1 \
  || die "akmods reported success but no nvidia module exists for ${running_kernel}."
log "NVIDIA kernel module built: $(modinfo -k "$running_kernel" -F version nvidia 2>/dev/null)"

success=1
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
