cmd_unlock() {
    load_config

    info "Checking for deployment lock on $SSH_USER@$SSH_HOST..."

    local lock_info
    lock_info=$(remote_exec bash -s "$REMOTE_PATH" << 'ENDSSH'
        REMOTE_PATH="$1"
        LOCK_FILE="$REMOTE_PATH/.shipnode/deploy.lock"

        if [ -f "$LOCK_FILE" ]; then
            LOCK_AGE=$(( $(date +%s) - $(stat -c %Y "$LOCK_FILE") ))
            echo "FOUND:${LOCK_AGE}"
        else
            echo "NOTFOUND"
        fi
ENDSSH
    )

    if [[ "$lock_info" == "NOTFOUND" ]]; then
        info "No deployment lock found"
        return 0
    fi

    local lock_age
    lock_age=$(echo "$lock_info" | cut -d: -f2)

    warn "Found deployment lock (age: ${lock_age}s)"
    read -p "Clear this lock? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        info "Lock not cleared"
        return 0
    fi

    remote_exec "rm -f $REMOTE_PATH/.shipnode/deploy.lock"
    success "Deployment lock cleared"
}

# Rollback to previous release
