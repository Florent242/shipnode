cmd_rollback() {
    load_config

    if [ "$ZERO_DOWNTIME" != "true" ]; then
        error "Rollback only available with zero-downtime deployment enabled"
    fi

    local steps_back=${1:-1}

    info "Fetching release history..."

    # Get target release
    local target_release=$(remote_exec bash << ENDSSH
        cd $REMOTE_PATH/.shipnode
        cat releases.json | jq -r ".[-$((steps_back + 1))].timestamp // empty"
ENDSSH
)

    if [ -z "$target_release" ]; then
        error "No release found to rollback to (requested $steps_back steps back)"
    fi

    # Confirm rollback
    warn "This will rollback to release: $target_release"
    read -p "Continue? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        info "Rollback cancelled"
        exit 0
    fi

    # Perform rollback
    rollback_to_release "$target_release"

    # Run health check for backend
    if [ "$APP_TYPE" = "backend" ] && [ "$HEALTH_CHECK_ENABLED" = "true" ]; then
        sleep 3
        if perform_health_check; then
            success "Rollback successful and health check passed"
        else
            warn "Rollback completed but health check failed"
        fi
    else
        success "Rollback successful"
    fi
}

# List available releases
cmd_releases() {
    load_config

    if [ "$ZERO_DOWNTIME" != "true" ]; then
        error "Releases command only available with zero-downtime deployment enabled"
    fi

    info "Fetching releases..."

    remote_exec bash << ENDSSH
        cd $REMOTE_PATH

        # Get current release
        CURRENT=""
        if [ -L current ]; then
            CURRENT=\$(readlink current | xargs basename)
        fi

        echo ""
        echo "Available releases:"
        echo "==================="

        cd .shipnode
        cat releases.json | jq -r '.[] | "\(.timestamp) - \(.date) - \(.status)"' | while read line; do
            timestamp=\$(echo \$line | cut -d' ' -f1)
            if [ "\$timestamp" = "\$CURRENT" ]; then
                echo "→ \$line (current)"
            else
                echo "  \$line"
            fi
        done

        echo ""
        echo "Total: \$(cat releases.json | jq 'length') releases"
ENDSSH
}

# Migrate existing deployment to release structure
