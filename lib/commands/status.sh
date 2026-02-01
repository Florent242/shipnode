cmd_status() {
    load_config

    if [ "$APP_TYPE" = "backend" ]; then
        info "Checking PM2 status for $PM2_APP_NAME..."
        remote_exec "pm2 status $PM2_APP_NAME"
    else
        info "Checking frontend files..."
        remote_exec "ls -lh $REMOTE_PATH | head -20"
    fi
}

# View logs (backend only)
cmd_logs() {
    load_config

    if [ "$APP_TYPE" != "backend" ]; then
        error "Logs command only available for backend apps"
    fi

    info "Streaming logs for $PM2_APP_NAME (Ctrl+C to exit)..."
    ssh_cmd -p "$SSH_PORT" "$SSH_USER@$SSH_HOST" "pm2 logs $PM2_APP_NAME"
}

# Restart app (backend only)
cmd_restart() {
    load_config

    if [ "$APP_TYPE" != "backend" ]; then
        error "Restart command only available for backend apps"
    fi

    info "Restarting $PM2_APP_NAME..."
    remote_exec "pm2 restart $PM2_APP_NAME"
    success "App restarted"
}

# Stop app (backend only)
cmd_stop() {
    load_config

    if [ "$APP_TYPE" != "backend" ]; then
        error "Stop command only available for backend apps"
    fi

    info "Stopping $PM2_APP_NAME..."
    remote_exec "pm2 stop $PM2_APP_NAME"
    success "App stopped"
}

# Clear deployment lock
