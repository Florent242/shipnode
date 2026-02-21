#!/usr/bin/env bash

# ShipNode Doctor - Pre-flight diagnostic checks

cmd_doctor() {
    # Check for --security flag
    local security_mode=false
    if [ "$1" = "--security" ]; then
        security_mode=true
    fi

    if [ "$security_mode" = true ]; then
        cmd_doctor_security
        return
    fi

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
    if [ -f "$SHIPNODE_CONFIG_FILE" ]; then
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

# Security audit - non-destructive checks only
cmd_doctor_security() {
    info "Running security audit..."
    echo ""

    local has_warnings=false
    local has_info=false

    # Local security checks
    info "Local security checks:"
    check_local_file_permissions || has_warnings=true
    echo ""

    # SSH connectivity required for remote checks
    if ! check_ssh_connection_quiet; then
        warn "Cannot perform remote security checks - SSH connection failed"
        echo ""
    else
        echo ""

        # Remote security checks
        info "Remote security checks:"
        check_ssh_security || has_warnings=true
        check_firewall_status || has_info=true
        check_fail2ban_status || has_info=true
        echo ""
    fi

    # Summary
    echo ""
    if [ "$has_warnings" = true ]; then
        warn "Security audit completed with warnings. Review the issues above."
        echo ""
        info "Run 'shipnode harden' for interactive security hardening."
    elif [ "$has_info" = true ]; then
        info "Security audit completed with informational notices."
        echo ""
        info "No critical issues found. Review the notices above."
    else
        success "Security audit passed! No issues found."
    fi
}

# Check if config file exists and required vars are set
check_local_config() {
    if [ ! -f "$SHIPNODE_CONFIG_FILE" ]; then
        echo "  ✗ $SHIPNODE_CONFIG_FILE not found"
        return 1
    fi

    # Try to load config
    set +e
    source "$SHIPNODE_CONFIG_FILE" 2>/dev/null
    local source_result=$?
    set -e

    if [ $source_result -ne 0 ]; then
        echo "  ✗ $SHIPNODE_CONFIG_FILE has syntax errors"
        return 1
    fi

    # Check required variables
    local missing_vars=()
    [ -z "$APP_TYPE" ] && missing_vars+=("APP_TYPE")
    [ -z "$SSH_USER" ] && missing_vars+=("SSH_USER")
    [ -z "$SSH_HOST" ] && missing_vars+=("SSH_HOST")
    [ -z "$REMOTE_PATH" ] && missing_vars+=("REMOTE_PATH")

    if [ ${#missing_vars[@]} -gt 0 ]; then
        echo "  ✗ $SHIPNODE_CONFIG_FILE missing required variables: ${missing_vars[*]}"
        return 1
    fi

    echo "  ✓ $SHIPNODE_CONFIG_FILE exists and is valid"
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
    if [ ! -f "$SHIPNODE_CONFIG_FILE" ]; then
        return 0
    fi

    set +e
    source "$SHIPNODE_CONFIG_FILE" 2>/dev/null
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
    if [ ! -f "$SHIPNODE_CONFIG_FILE" ]; then
        echo "  ✗ Cannot test SSH - $SHIPNODE_CONFIG_FILE not found"
        return 1
    fi

    set +e
    source "$SHIPNODE_CONFIG_FILE" 2>/dev/null
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
    if [ ! -f "$SHIPNODE_CONFIG_FILE" ]; then
        return 1
    fi

    set +e
    source "$SHIPNODE_CONFIG_FILE" 2>/dev/null
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

# Quiet SSH connection check (no output)
check_ssh_connection_quiet() {
    if [ ! -f "$SHIPNODE_CONFIG_FILE" ]; then
        return 1
    fi

    set +e
    source "$SHIPNODE_CONFIG_FILE" 2>/dev/null
    set -e

    if [ -z "$SSH_USER" ] || [ -z "$SSH_HOST" ]; then
        return 1
    fi

    remote_exec "exit" &>/dev/null
}

# Check local file permissions for sensitive files
check_local_file_permissions() {
    local has_issues=false

    # Check config file permissions
    if [ -f "$SHIPNODE_CONFIG_FILE" ]; then
        local conf_perms
        conf_perms=$(stat -c "%a" "$SHIPNODE_CONFIG_FILE" 2>/dev/null || stat -f "%Lp" "$SHIPNODE_CONFIG_FILE" 2>/dev/null)
        if [ -n "$conf_perms" ]; then
            # Check if permissions are too permissive (readable by group/others)
            local other_read=$((conf_perms % 10 / 1))
            local group_read=$(((conf_perms / 10) % 10 / 1))
            
            if [ "$other_read" -ge 4 ] || [ "$group_read" -ge 4 ]; then
                echo "  ⚠ $SHIPNODE_CONFIG_FILE has overly permissive permissions ($conf_perms)"
                echo "      Recommendation: Run 'chmod 600 $SHIPNODE_CONFIG_FILE'"
                has_issues=true
            else
                echo "  ✓ $SHIPNODE_CONFIG_FILE permissions are secure ($conf_perms)"
            fi
        fi
    fi

    # Check .env file permissions
    if [ -f ".env" ]; then
        local env_perms
        env_perms=$(stat -c "%a" .env 2>/dev/null || stat -f "%Lp" .env 2>/dev/null)
        if [ -n "$env_perms" ]; then
            local other_read=$((env_perms % 10 / 1))
            local group_read=$(((env_perms / 10) % 10 / 1))
            
            if [ "$other_read" -ge 4 ] || [ "$group_read" -ge 4 ]; then
                echo "  ⚠ .env file has overly permissive permissions ($env_perms)"
                echo "      Recommendation: Run 'chmod 600 .env'"
                has_issues=true
            else
                echo "  ✓ .env file permissions are secure ($env_perms)"
            fi
        fi
    fi

    # Check users.yml file permissions
    if [ -f "users.yml" ]; then
        local users_perms
        users_perms=$(stat -c "%a" users.yml 2>/dev/null || stat -f "%Lp" users.yml 2>/dev/null)
        if [ -n "$users_perms" ]; then
            local other_read=$((users_perms % 10 / 1))
            local group_read=$(((users_perms / 10) % 10 / 1))
            
            if [ "$other_read" -ge 4 ] || [ "$group_read" -ge 4 ]; then
                echo "  ⚠ users.yml has overly permissive permissions ($users_perms)"
                echo "      Recommendation: Run 'chmod 600 users.yml'"
                has_issues=true
            else
                echo "  ✓ users.yml permissions are secure ($users_perms)"
            fi
        fi
    fi

    [ "$has_issues" = true ] && return 1
    return 0
}

# Check SSH configuration security
check_ssh_security() {
    local has_issues=false

    # Fetch SSH configuration from remote server
    local ssh_config
    ssh_config=$(remote_exec "cat /etc/ssh/sshd_config 2>/dev/null || echo 'SSHD_CONFIG_MISSING'")

    if [ "$ssh_config" = "SSHD_CONFIG_MISSING" ]; then
        echo "  ⚠ Could not read /etc/ssh/sshd_config"
        return 1
    fi

    # Check PermitRootLogin
    local root_login
    root_login=$(echo "$ssh_config" | grep -i "^PermitRootLogin" | tail -1 | awk '{print $2}')
    if [ -z "$root_login" ]; then
        root_login="prohibit-password"  # Default in modern OpenSSH
    fi
    
    case "$root_login" in
        yes|prohibit-password)
            echo "  ⚠ PermitRootLogin is enabled ($root_login)"
            echo "      Recommendation: Set 'PermitRootLogin no' in /etc/ssh/sshd_config"
            has_issues=true
            ;;
        no)
            echo "  ✓ PermitRootLogin is disabled"
            ;;
        *)
            echo "  ℹ PermitRootLogin setting: $root_login"
            ;;
    esac

    # Check PasswordAuthentication
    local pass_auth
    pass_auth=$(echo "$ssh_config" | grep -i "^PasswordAuthentication" | tail -1 | awk '{print $2}')
    if [ -z "$pass_auth" ]; then
        pass_auth="yes"  # Default
    fi

    case "$pass_auth" in
        yes)
            echo "  ⚠ PasswordAuthentication is enabled"
            echo "      Recommendation: Set 'PasswordAuthentication no' in /etc/ssh/sshd_config"
            has_issues=true
            ;;
        no)
            echo "  ✓ PasswordAuthentication is disabled"
            ;;
    esac

    # Check SSH Port
    local ssh_port
    ssh_port=$(echo "$ssh_config" | grep -i "^Port" | tail -1 | awk '{print $2}')
    if [ -z "$ssh_port" ]; then
        ssh_port="22"  # Default
    fi

    if [ "$ssh_port" = "22" ]; then
        echo "  ℹ SSH is running on default port 22"
        echo "      Recommendation: Consider changing to a non-standard port for security by obscurity"
    else
        echo "  ✓ SSH is running on non-default port $ssh_port"
    fi

    [ "$has_issues" = true ] && return 1
    return 0
}

# Check firewall status
check_firewall_status() {
    local has_info=false

    # Check if ufw is available and active
    local ufw_status
    ufw_status=$(remote_exec "sudo ufw status 2>/dev/null || echo 'UFW_NOT_FOUND'")

    if [ "$ufw_status" != "UFW_NOT_FOUND" ]; then
        if echo "$ufw_status" | grep -q "Status: active"; then
            echo "  ✓ UFW firewall is active"
            
            # Check if SSH port is allowed
            if echo "$ufw_status" | grep -q "22/tcp\|SSH"; then
                echo "  ✓ SSH port is allowed in UFW"
            else
                echo "  ⚠ SSH port may not be explicitly allowed in UFW"
                has_info=true
            fi
            
            # Check if HTTP/HTTPS are allowed
            if echo "$ufw_status" | grep -q "80/tcp\|80,443/tcp\|Nginx Full\|Apache Full"; then
                echo "  ✓ HTTP/HTTPS ports are allowed in UFW"
            else
                echo "  ℹ HTTP/HTTPS ports not explicitly allowed (may use different firewall)"
                has_info=true
            fi
        else
            echo "  ⚠ UFW is installed but not active"
            echo "      Recommendation: Run 'sudo ufw enable' to activate the firewall"
            has_info=true
        fi
        return 0
    fi

    # Check if firewalld is running
    local firewalld_status
    firewalld_status=$(remote_exec "systemctl is-active firewalld 2>/dev/null || echo 'inactive'")
    
    if [ "$firewalld_status" = "active" ]; then
        echo "  ✓ firewalld is active"
        return 0
    fi

    # Check iptables directly
    local iptables_rules
    iptables_rules=$(remote_exec "sudo iptables -L -n 2>/dev/null | head -5 || echo 'IPTABLES_NOT_AVAILABLE'")
    
    if [ "$iptables_rules" != "IPTABLES_NOT_FOUND" ] && echo "$iptables_rules" | grep -q "Chain INPUT"; then
        if echo "$iptables_rules" | grep -q "DROP"; then
            echo "  ✓ iptables has active rules with DROP policies"
        else
            echo "  ℹ iptables has rules but no explicit DROP policy detected"
            has_info=true
        fi
    else
        echo "  ⚠ No active firewall detected (UFW, firewalld, or iptables)"
        echo "      Recommendation: Enable UFW with 'shipnode harden' or manually configure iptables"
        has_info=true
    fi

    [ "$has_info" = true ] && return 1
    return 0
}

# Check fail2ban status
check_fail2ban_status() {
    local has_info=false

    # Check if fail2ban is installed
    local fail2ban_installed
    fail2ban_installed=$(remote_exec "command -v fail2ban-server 2>/dev/null || echo 'NOT_INSTALLED'")

    if [ "$fail2ban_installed" = "NOT_INSTALLED" ]; then
        echo "  ℹ fail2ban is not installed"
        echo "      Recommendation: Install fail2ban for brute-force protection (use 'shipnode harden')"
        has_info=true
    else
        # Check if fail2ban service is running
        local fail2ban_status
        fail2ban_status=$(remote_exec "sudo systemctl is-active fail2ban 2>/dev/null || sudo service fail2ban status 2>/dev/null | grep -i running || echo 'NOT_RUNNING'")
        
        if [ "$fail2ban_status" = "active" ] || echo "$fail2ban_status" | grep -q "running"; then
            echo "  ✓ fail2ban is installed and running"
            
            # Get list of active jails
            local jails
            jails=$(remote_exec "sudo fail2ban-client status 2>/dev/null | grep 'Jail list' || echo ''")
            if [ -n "$jails" ]; then
                echo "      $jails"
            fi
        else
            echo "  ℹ fail2ban is installed but not running"
            echo "      Recommendation: Start fail2ban with 'sudo systemctl start fail2ban'"
            has_info=true
        fi
    fi

    [ "$has_info" = true ] && return 1
    return 0
}
