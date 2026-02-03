#!/bin/bash
# -----------------------------------------------------------------------------
# AAP Bootstrap Script
#
# Runs on first boot to complete AAP installation.
# This script is executed by the aap-install.service systemd unit.
# -----------------------------------------------------------------------------

set -euo pipefail

LOG_FILE="/var/log/aap-install.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

log "Starting AAP installation..."

# Change to AAP directory
cd /opt/aap

# Check if setup.sh exists
if [[ ! -f ./setup.sh ]]; then
    log "ERROR: setup.sh not found in /opt/aap"
    exit 1
fi

# Check if inventory exists
if [[ ! -f ./inventory ]]; then
    log "ERROR: inventory file not found in /opt/aap"
    exit 1
fi

log "Running AAP setup..."
./setup.sh -- -e '@inventory' 2>&1 | tee -a "$LOG_FILE"

log "AAP installation complete!"

# Verify services are running
log "Verifying AAP services..."
systemctl status automation-controller --no-pager || true
systemctl status redis --no-pager || true
systemctl status nginx --no-pager || true

log "AAP bootstrap complete. Access the web UI at https://$(hostname -f)"
