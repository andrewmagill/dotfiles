#!/usr/bin/env bash
# Opt-in provisioning: silence the "Unmaintained driver is detected: cnic /
# bnx2i" kernel warnings on a machine with NO iSCSI storage.
#
#   scripts/disable-iscsi-offload-rocky.sh
#
# Root cause: the iSCSI initiator services load EVERY hardware-offload transport
# at boot (bnx2i/cnic for Broadcom, be2iscsi for Emulex, cxgb4i for Chelsio) even
# with no such HBA present. The deprecated Broadcom pair then prints the warning.
# Fix: block those offload modules and disable the unused initiator services.
# Usage, verification, and rollback: scripts/README.md.
#
# NOT called by bootstrap.sh: it changes system module/service state, so it's
# run-when-you-mean-it. It only touches OFFLOAD transports — plain software iSCSI
# (iscsi_tcp) is left alone, and it's reversible.

set -euo pipefail

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mWARN:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

readonly MODPROBE_CONF="/etc/modprobe.d/blacklist-iscsi-offload.conf"

command -v systemctl >/dev/null 2>&1 || die "systemd (systemctl) required; this targets Rocky/RHEL."

# SAFETY: never run on a machine that actually uses iSCSI. iscsiadm returns
# non-zero when there are no sessions / no configured nodes, so a zero exit here
# means iSCSI IS in use.
if command -v iscsiadm >/dev/null 2>&1; then
  if sudo iscsiadm -m session >/dev/null 2>&1; then
    die "Active iSCSI session(s) detected — this machine USES iSCSI. Aborting."
  fi
  if sudo iscsiadm -m node >/dev/null 2>&1; then
    die "Configured iSCSI node(s) found — this machine may use iSCSI. Aborting."
  fi
fi

# Block the offload transports. `install ... /bin/false` beats a plain
# `blacklist`: the iSCSI services modprobe these EXPLICITLY, which blacklist
# wouldn't stop. Writing the file every run is fine (idempotent).
log "Writing $MODPROBE_CONF"
sudo tee "$MODPROBE_CONF" >/dev/null <<'EOF'
# No iSCSI storage on this host, and no Broadcom/Emulex/Chelsio HBAs.
# The iSCSI initiator services otherwise modprobe every offload transport at
# boot, which drags in the deprecated cnic/bnx2i drivers ("Unmaintained driver
# is detected" warnings). Block them explicitly (install ... /bin/false stops
# even an explicit modprobe, not just modalias autoload).
install bnx2i     /bin/false
install cnic      /bin/false
install be2iscsi  /bin/false
install cxgb4i    /bin/false
install libcxgbi  /bin/false
EOF

# Disable the unused initiator services/sockets. Names vary across EL releases,
# so loop and ignore any that don't exist on this box.
log "Disabling unused iSCSI initiator services"
for unit in \
  iscsi-onboot.service iscsi-starter.service \
  iscsid.socket iscsiuio.socket \
  iscsid.service iscsiuio.service iscsi.service; do
  sudo systemctl disable --now "$unit" 2>/dev/null || true
done

# Unload the deprecated pair now if present (bnx2i holds cnic; modprobe -r
# resolves the order). Harmless if they're already gone.
if lsmod | grep -qE '^(bnx2i|cnic)\b'; then
  log "Unloading bnx2i/cnic"
  sudo modprobe -r bnx2i cnic 2>/dev/null \
    || warn "Couldn't unload now (in use?); they'll stay unloaded after a reboot."
fi

log "Done. The warnings won't recur on the next boot."
log "Verify:  lsmod | grep -Ei 'bnx2i|cnic'   (should be empty)"
