#!/usr/bin/env bash
# ==============================================================================
# Omarchy Auto-Backup & Git Push Engine (auto-backup.sh)
# Exports active system state and pushes updates to remote Git repository.
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/auto-backup.log"

log_info()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO]  $1" | tee -a "$LOG_FILE"; }
log_warn()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARN]  $1" | tee -a "$LOG_FILE"; }
log_error() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $1" | tee -a "$LOG_FILE"; }

log_info "============================================================"
log_info "  Starting Automatic Omarchy Backup & Sync"
log_info "============================================================"

# 1. Run Export Script
if [[ -x "$SCRIPT_DIR/export.sh" ]]; then
    log_info "Running state export..."
    "$SCRIPT_DIR/export.sh" >> "$LOG_FILE" 2>&1 || log_warn "export.sh completed with warnings."
else
    log_error "export.sh not found or not executable in $SCRIPT_DIR"
    exit 1
fi

cd "$SCRIPT_DIR"

# 2. Check for Git changes
if [[ -n "$(git status --porcelain)" ]]; then
    log_info "Changes detected in system state/manifests. Creating commit..."
    git add .
    git commit -m "Auto-backup on login ($(date '+%Y-%m-%d %H:%M:%S'))" >> "$LOG_FILE" 2>&1
else
    log_info "No local state changes detected."
fi

# 3. Check for unpushed commits
UNPUSHED=$(git log @{u}..HEAD 2>/dev/null || echo "untracked")
if [[ -n "$UNPUSHED" ]]; then
    log_info "Unpushed commits present. Waiting for network connectivity..."
    
    # Wait up to 30 seconds for network connection
    MAX_ATTEMPTS=6
    ATTEMPT=0
    CONNECTED=false
    while [[ $ATTEMPT -lt $MAX_ATTEMPTS ]]; do
        if ping -c 1 -W 2 github.com &>/dev/null; then
            CONNECTED=true
            break
        fi
        ATTEMPT=$((ATTEMPT + 1))
        sleep 5
    done

    if [[ "$CONNECTED" == true ]]; then
        log_info "Network available. Pushing updates to remote repository..."
        BRANCH=$(git rev-parse --abbrev-ref HEAD)
        if git push origin "$BRANCH" >> "$LOG_FILE" 2>&1; then
            log_info "Successfully pushed backup to remote repository ($BRANCH)."
        else
            log_error "Failed to push backup to remote repository."
        fi
    else
        log_warn "Network unavailable after timeout. Commit saved locally and will be pushed on next login."
    fi
else
    log_info "Remote repository is already up to date."
fi

log_info "============================================================"
log_info "  Auto-Backup Complete"
log_info "============================================================"
