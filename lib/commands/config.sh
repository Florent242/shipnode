# Load configuration
load_config() {
    if [ ! -f "shipnode.conf" ]; then
        error "shipnode.conf not found. Run 'shipnode init' first."
    fi

    info "Loading configuration..."

    # Source .env first if it exists (allows shipnode.conf to reference env vars)
    if [ -f ".env" ]; then
        info "Loading environment variables from .env..."
        set -a
        source .env 2>/dev/null || warn "Failed to parse .env file"
        set +a
    fi

    # Source the config file with error handling
    set -a
    if ! source shipnode.conf 2>&1; then
        error "Failed to parse shipnode.conf"
    fi
    set +a

    # Validate required variables
    if [ -z "$APP_TYPE" ]; then
        error "APP_TYPE not set in shipnode.conf"
    fi
    if [ -z "$SSH_USER" ]; then
        error "SSH_USER not set in shipnode.conf"
    fi
    if [ -z "$SSH_HOST" ]; then
        error "SSH_HOST not set in shipnode.conf"
    fi
    if [ -z "$REMOTE_PATH" ]; then
        error "REMOTE_PATH not set in shipnode.conf"
    fi

    # Set defaults
    SSH_PORT="${SSH_PORT:-22}"
    ZERO_DOWNTIME="${ZERO_DOWNTIME:-true}"
    KEEP_RELEASES="${KEEP_RELEASES:-5}"
    HEALTH_CHECK_ENABLED="${HEALTH_CHECK_ENABLED:-true}"
    HEALTH_CHECK_PATH="${HEALTH_CHECK_PATH:-/health}"
    HEALTH_CHECK_TIMEOUT="${HEALTH_CHECK_TIMEOUT:-30}"
    HEALTH_CHECK_RETRIES="${HEALTH_CHECK_RETRIES:-3}"

    # Validate APP_TYPE
    if [ "$APP_TYPE" != "backend" ] && [ "$APP_TYPE" != "frontend" ]; then
        error "APP_TYPE must be 'backend' or 'frontend'"
    fi

    # Backend-specific validation
    if [ "$APP_TYPE" = "backend" ]; then
        if [ -z "$PM2_APP_NAME" ]; then
            error "PM2_APP_NAME required for backend apps"
        fi
        if [ -z "$BACKEND_PORT" ]; then
            error "BACKEND_PORT required for backend apps"
        fi
    fi

    # Start SSH multiplex connection once per session
    if [ -z "${_SHIPNODE_MULTIPLEX_STARTED:-}" ]; then
        start_ssh_multiplex
        _SHIPNODE_MULTIPLEX_STARTED=1
    fi
}

# Interactive users.yml generation
