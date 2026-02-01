#!/usr/bin/env bash

# ShipNode Doctor - Pre-flight diagnostic checks

cmd_doctor() {
    info "Running ShipNode diagnostics..."
    echo ""

    local has_errors=false
    local has_warnings=false

    # Local checks
    info "Local environment:"
    check_local_config || has_errors=true
    check_local_env || has_warnings=true
    check_local_node || has_errors=true
    check_local_package_json || has_warnings=true
    echo ""

    # Config validation (if config exists)
    if [ -f "shipnode.conf" ]; then
        info "Configuration validation:"
        check_health_check_path || has_warnings=true
        echo ""
    fi

    # SSH connectivity
    info "SSH connectivity:"
    if ! check_ssh_connection; then
        has_errors=true
        warn "Cannot perform remote checks - SSH connection failed"
        echo ""
    else
        echo ""

        # Remote checks (batched)
        info "Remote environment:"
        check_remote_environment || has_errors=true
        echo ""
    fi

    # Summary
    echo ""
    if [ "$has_errors" = true ]; then
        error "Diagnostics completed with errors. Please fix the issues above."
    elif [ "$has_warnings" = true ]; then
        warn "Diagnostics completed with warnings. Review the warnings above."
        echo ""
        info "System is functional but some optional features may be unavailable."
    else
        success "All diagnostics passed! System is ready for deployment."
    fi
}

# Check if shipnode.conf exists and required vars are set
check_local_config() {
    if [ ! -f "shipnode.conf" ]; then
        echo "  ✗ shipnode.conf not found"
        return 1
    fi

    # Try to load config
    set +e
    source shipnode.conf 2>/dev/null
    local source_result=$?
    set -e

    if [ $source_result -ne 0 ]; then
        echo "  ✗ shipnode.conf has syntax errors"
        return 1
    fi

    # Check required variables
    local missing_vars=()
    [ -z "$APP_TYPE" ] && missing_vars+=("APP_TYPE")
    [ -z "$SSH_USER" ] && missing_vars+=("SSH_USER")
    [ -z "$SSH_HOST" ] && missing_vars+=("SSH_HOST")
    [ -z "$REMOTE_PATH" ] && missing_vars+=("REMOTE_PATH")

    if [ ${#missing_vars[@]} -gt 0 ]; then
        echo "  ✗ shipnode.conf missing required variables: ${missing_vars[*]}"
        return 1
    fi

    echo "  ✓ shipnode.conf exists and is valid"
    return 0
}

# Check if .env exists
check_local_env() {
    if [ ! -f ".env" ]; then
        echo "  ⚠ .env file not found"
        return 1
    fi
    echo "  ✓ .env file exists"
    return 0
}

# Check if node is available locally
check_local_node() {
    if ! command -v node &> /dev/null; then
        echo "  ✗ node not found in PATH"
        return 1
    fi
    local node_version=$(node --version)
    echo "  ✓ node available ($node_version)"
    return 0
}

# Check if package.json exists
check_local_package_json() {
    if [ ! -f "package.json" ]; then
        echo "  ⚠ package.json not found"
        return 1
    fi

    # Detect package manager
    local pkg_manager=$(detect_pkg_manager)
    echo "  ✓ package.json exists (detected: $pkg_manager)"
    return 0
}

# Check if HEALTH_CHECK_PATH starts with / (if set)
check_health_check_path() {
    if [ ! -f "shipnode.conf" ]; then
        return 0
    fi

    set +e
    source shipnode.conf 2>/dev/null
    set -e

    if [ -n "$HEALTH_CHECK_PATH" ] && [[ ! "$HEALTH_CHECK_PATH" =~ ^/ ]]; then
        echo "  ⚠ HEALTH_CHECK_PATH should start with '/' (currently: $HEALTH_CHECK_PATH)"
        return 1
    fi

    echo "  ✓ Configuration values are valid"
    return 0
}

# Test SSH connection
check_ssh_connection() {
    if [ ! -f "shipnode.conf" ]; then
        echo "  ✗ Cannot test SSH - shipnode.conf not found"
        return 1
    fi

    set +e
    source shipnode.conf 2>/dev/null
    set -e

    if [ -z "$SSH_USER" ] || [ -z "$SSH_HOST" ]; then
        echo "  ✗ Cannot test SSH - SSH_USER or SSH_HOST not set"
        return 1
    fi

    local ssh_port="${SSH_PORT:-22}"

    # Test connection with 5 second timeout
    if remote_exec "exit" &>/dev/null; then
        echo "  ✓ SSH connection successful ($SSH_USER@$SSH_HOST:$ssh_port)"
        return 0
    else
        echo "  ✗ SSH connection failed ($SSH_USER@$SSH_HOST:$ssh_port)"
        return 1
    fi
}

# Check remote environment (batched checks)
check_remote_environment() {
    if [ ! -f "shipnode.conf" ]; then
        return 1
    fi

    set +e
    source shipnode.conf 2>/dev/null
    set -e

    local ssh_port="${SSH_PORT:-22}"
    local pkg_manager=$(detect_pkg_manager)

    # Single batched SSH call for all remote checks
    local remote_output
    remote_output=$(remote_exec bash << 'REMOTE_CHECKS'
        # Check node
        if command -v node &> /dev/null; then
            echo "NODE_OK:$(node --version)"
        else
            echo "NODE_MISSING"
        fi

        # Check PM2
        if command -v pm2 &> /dev/null; then
            echo "PM2_OK:$(pm2 --version)"
        else
            echo "PM2_MISSING"
        fi

        # Check Caddy
        if systemctl is-active caddy &> /dev/null 2>&1; then
            echo "CADDY_OK:systemctl"
        elif pgrep caddy &> /dev/null; then
            echo "CADDY_OK:process"
        else
            echo "CADDY_STOPPED"
        fi

        # Check disk space
        disk_avail=$(df / | tail -1 | awk '{print $4}')
        echo "DISK:$disk_avail"

        # Check package managers
        command -v npm &> /dev/null && echo "PKG_NPM_OK"
        command -v yarn &> /dev/null && echo "PKG_YARN_OK"
        command -v pnpm &> /dev/null && echo "PKG_PNPM_OK"
        command -v bun &> /dev/null && echo "PKG_BUN_OK"
REMOTE_CHECKS
    )

    local has_errors=false

    # Parse node check
    if echo "$remote_output" | grep -q "NODE_OK:"; then
        local node_version=$(echo "$remote_output" | grep "NODE_OK:" | cut -d: -f2)
        echo "  ✓ node available ($node_version)"
    else
        echo "  ✗ node not found"
        has_errors=true
    fi

    # Parse PM2 check
    if echo "$remote_output" | grep -q "PM2_OK:"; then
        local pm2_version=$(echo "$remote_output" | grep "PM2_OK:" | cut -d: -f2)
        echo "  ✓ PM2 available ($pm2_version)"
    else
        echo "  ✗ PM2 not found"
        has_errors=true
    fi

    # Parse Caddy check
    if echo "$remote_output" | grep -q "CADDY_OK:"; then
        echo "  ✓ Caddy is running"
    else
        echo "  ⚠ Caddy is not running"
    fi

    # Parse disk space
    if echo "$remote_output" | grep -q "DISK:"; then
        local disk_kb=$(echo "$remote_output" | grep "DISK:" | cut -d: -f2)
        local disk_mb=$((disk_kb / 1024))
        if [ $disk_mb -lt 500 ]; then
            echo "  ⚠ Low disk space: ${disk_mb}MB available"
        else
            echo "  ✓ Disk space OK (${disk_mb}MB available)"
        fi
    fi

    # Parse package manager check
    case "$pkg_manager" in
        bun)
            if echo "$remote_output" | grep -q "PKG_BUN_OK"; then
                echo "  ✓ bun available"
            else
                echo "  ✗ bun not found (detected from bun.lockb)"
                has_errors=true
            fi
            ;;
        pnpm)
            if echo "$remote_output" | grep -q "PKG_PNPM_OK"; then
                echo "  ✓ pnpm available"
            else
                echo "  ✗ pnpm not found (detected from pnpm-lock.yaml)"
                has_errors=true
            fi
            ;;
        yarn)
            if echo "$remote_output" | grep -q "PKG_YARN_OK"; then
                echo "  ✓ yarn available"
            else
                echo "  ✗ yarn not found (detected from yarn.lock)"
                has_errors=true
            fi
            ;;
        npm)
            if echo "$remote_output" | grep -q "PKG_NPM_OK"; then
                echo "  ✓ npm available"
            else
                echo "  ✗ npm not found"
                has_errors=true
            fi
            ;;
    esac

    [ "$has_errors" = true ] && return 1
    return 0
}
