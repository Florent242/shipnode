# ============================================================================

# Legacy non-interactive init (backward compatibility)
cmd_init_legacy() {
    if [ -f "shipnode.conf" ]; then
        read -p "shipnode.conf already exists. Overwrite? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            info "Aborted."
            exit 0
        fi
    fi

    cat > shipnode.conf << 'EOF'
# App type: "backend" or "frontend"
APP_TYPE=backend

# SSH Connection
SSH_USER=root
SSH_HOST=your-server-ip
SSH_PORT=22

# Remote path
REMOTE_PATH=/var/www/myapp

# Backend-specific
PM2_APP_NAME=myapp
BACKEND_PORT=3000

# Frontend-specific (optional)
DOMAIN=myapp.com

# Zero-downtime deployment (optional)
ZERO_DOWNTIME=true
KEEP_RELEASES=5

# Health checks for backend (optional)
HEALTH_CHECK_ENABLED=true
HEALTH_CHECK_PATH=/health
HEALTH_CHECK_TIMEOUT=30
HEALTH_CHECK_RETRIES=3
EOF

    success "Created shipnode.conf"
    info "Edit shipnode.conf with your server details, then run: shipnode deploy"

    # Optionally generate users.yml
    echo ""
    if prompt_yes_no "Add deployment users?"; then
        init_users_yaml
    else
        info "Skipped users.yml - create later with 'shipnode user sync'"
    fi
}

# Template-based initialization
cmd_init_template() {
    local template_name="$1"

    # Check for existing config
    if [ -f "shipnode.conf" ]; then
        warn "shipnode.conf already exists"
        if ! prompt_yes_no "Overwrite?"; then
            info "Aborted"
            return 0
        fi
    fi

    # Load template data
    local template_data
    template_data=$(get_template "$template_name")

    if [ $? -ne 0 ] || [ -z "$template_data" ]; then
        error "Unknown template: $template_name"
        echo ""
        list_templates
        return 1
    fi

    # Parse template data
    local app_type backend_port health_check_path build_dir
    while IFS='=' read -r key value; do
        case "$key" in
            APP_TYPE) app_type="$value" ;;
            BACKEND_PORT) backend_port="$value" ;;
            HEALTH_CHECK_PATH) health_check_path="$value" ;;
            BUILD_DIR) build_dir="$value" ;;
        esac
    done <<< "$template_data"

    # Welcome banner
    echo ""
    if [ "$USE_GUM" = true ]; then
        gum style \
            --border double \
            --border-foreground 212 \
            --align center \
            --width 50 \
            --margin "1 0" \
            --padding "1 2" \
            "ShipNode Template Setup" \
            "" \
            "Template: $template_name"
    else
        echo -e "${BLUE}╔════════════════════════════════════╗${NC}"
        echo -e "${BLUE}║  ShipNode Template Setup           ║${NC}"
        echo -e "${BLUE}║  Template: $(printf '%-24s' "$template_name") ║${NC}"
        echo -e "${BLUE}╚════════════════════════════════════╝${NC}"
    fi
    echo ""

    info "Using template: $template_name"
    info "App type: $app_type"
    [ -n "$backend_port" ] && info "Port: $backend_port"
    [ -n "$health_check_path" ] && info "Health check: $health_check_path"
    echo ""

    # Show tip about Gum if not installed
    show_gum_tip

    # Prompt for SSH connection details
    info "Server connection details"
    if [ "$USE_GUM" = false ]; then
        echo "Enter SSH credentials for your deployment server"
    fi
    echo ""

    local ssh_user ssh_host ssh_port

    # SSH User
    if [ "$USE_GUM" = true ]; then
        ssh_user=$(gum input --placeholder "root" --prompt "SSH user: " --value "root")
    else
        echo "  (The SSH user to connect with - typically 'root' or your username)"
        prompt_with_default "SSH user" "root" "ssh_user"
    fi

    # SSH Host with validation
    while true; do
        if [ "$USE_GUM" = true ]; then
            ssh_host=$(gum input --placeholder "192.168.1.100 or server.example.com" --prompt "SSH host: ")
        else
            echo "  (Your server's IP address or domain name - e.g. 192.168.1.100 or server.example.com)"
            read -p "SSH host (IP or hostname): " ssh_host
        fi

        if validate_ip_or_hostname "$ssh_host"; then
            break
        else
            warn "Invalid IP or hostname"
        fi
    done

    # SSH Port with validation
    while true; do
        if [ "$USE_GUM" = true ]; then
            local port_input
            port_input=$(gum input --placeholder "22" --prompt "SSH port: " --value "22")
            ssh_port="${port_input:-22}"
        else
            echo "  (SSH port - default is 22)"
            read -p "SSH port [22]: " ssh_port
            ssh_port="${ssh_port:-22}"
        fi

        if validate_port "$ssh_port"; then
            break
        else
            warn "Invalid port number"
        fi
    done

    # Deployment path
    echo ""
    info "Deployment configuration"
    echo ""
    local remote_path app_name

    # Try to get app name from package.json
    if [ -f "package.json" ] && command -v jq &> /dev/null; then
        app_name=$(jq -r '.name // empty' package.json 2>/dev/null \
            | sed -E 's/^@[^/]+\///' \
            | tr ' ' '-' \
            | sed -E 's/[^A-Za-z0-9._-]+/-/g' \
            | sed -E 's/-+/-/g' \
            | sed -E 's/^-+|-+$//g')
    fi

    if [ -z "$app_name" ]; then
        app_name=$(basename "$PWD")
    fi

    if [ "$USE_GUM" = true ]; then
        remote_path=$(gum input --placeholder "/var/www/$app_name" --prompt "Deployment path: " --value "/var/www/$app_name")
    else
        echo "  (Directory on the server where your app will be deployed)"
        prompt_with_default "Remote deployment path" "/var/www/$app_name" "remote_path"
    fi

    # Backend-specific: PM2 app name
    local pm2_app_name domain
    if [ "$app_type" = "backend" ]; then
        echo ""
        pm2_app_name="$app_name"

        # PM2 process name with validation
        while true; do
            if [ "$USE_GUM" = true ]; then
                pm2_app_name=$(gum input --placeholder "$app_name" --prompt "PM2 process name: " --value "$app_name")
            else
                read -p "PM2 process name [$app_name]: " pm2_input
                pm2_app_name="${pm2_input:-$app_name}"
            fi

            if validate_pm2_app_name "$pm2_app_name"; then
                break
            else
                warn "Invalid PM2 process name"
            fi
        done

        # Optional domain for backend
        while true; do
            if [ "$USE_GUM" = true ]; then
                domain=$(gum input --placeholder "api.myapp.com (optional)" --prompt "Domain: ")
            else
                echo "  (Optional: Your domain name for HTTPS - e.g. api.myapp.com)"
                read -p "Domain (optional, press Enter to skip): " domain
            fi

            if [ -z "$domain" ] || validate_domain "$domain"; then
                break
            else
                warn "Invalid domain"
            fi
        done
    fi

    # Frontend-specific: domain is required
    if [ "$app_type" = "frontend" ]; then
        echo ""
        info "Frontend configuration"
        if [ "$USE_GUM" = false ]; then
            echo "Note: Domain is required for frontend deployments (needed for Caddy web server)"
        fi
        echo ""

        while true; do
            if [ "$USE_GUM" = true ]; then
                domain=$(gum input --placeholder "myapp.com" --prompt "Domain (required): ")
            else
                echo "  (Your domain name - e.g. myapp.com or www.myapp.com)"
                read -p "Domain: " domain
            fi

            if [ -n "$domain" ] && validate_domain "$domain"; then
                break
            elif [ -z "$domain" ]; then
                warn "Domain is required for frontend deployments"
            else
                warn "Invalid domain"
            fi
        done
    fi

    # Use defaults for advanced options
    local zero_downtime="true"
    local keep_releases="5"
    local health_enabled="true"
    local health_timeout="30"
    local health_retries="3"

    # Configuration summary
    echo ""
    if [ "$USE_GUM" = true ]; then
        gum style \
            --border rounded \
            --border-foreground 99 \
            --padding "1 2" \
            --margin "1 0" \
            "Configuration Summary" \
            "" \
            "Template:      $template_name" \
            "App Type:      $app_type" \
            "SSH:           $ssh_user@$ssh_host:$ssh_port" \
            "Remote Path:   $remote_path" \
            $([ "$app_type" = "backend" ] && echo "PM2 Name:      $pm2_app_name") \
            $([ "$app_type" = "backend" ] && echo "Backend Port:  $backend_port") \
            $([ -n "$domain" ] && echo "Domain:        $domain") \
            "Zero-downtime: $zero_downtime" \
            $([ "$app_type" = "backend" ] && [ "$health_enabled" = "true" ] && echo "Health Checks: $health_check_path (${health_timeout}s, $health_retries retries)")
    else
        echo -e "${BLUE}════════════════════════════════════${NC}"
        echo -e "${BLUE}Configuration Summary${NC}"
        echo -e "${BLUE}════════════════════════════════════${NC}"
        echo "Template:      $template_name"
        echo "App Type:      $app_type"
        echo "SSH:           $ssh_user@$ssh_host:$ssh_port"
        echo "Remote Path:   $remote_path"

        if [ "$app_type" = "backend" ]; then
            echo "PM2 Name:      $pm2_app_name"
            echo "Backend Port:  $backend_port"
        fi

        [ -n "$domain" ] && echo "Domain:        $domain"
        echo "Zero-downtime: $zero_downtime"

        if [ "$app_type" = "backend" ] && [ "$health_enabled" = "true" ]; then
            echo "Health Checks: $health_check_path (${health_timeout}s timeout, ${health_retries} retries)"
        fi

        echo -e "${BLUE}════════════════════════════════════${NC}"
    fi
    echo ""

    # Final confirmation
    if [ "$USE_GUM" = true ]; then
        if ! gum confirm "Create shipnode.conf with these settings?"; then
            warn "Configuration cancelled"
            return 1
        fi
    else
        if ! prompt_yes_no "Create shipnode.conf with these settings?" "y"; then
            warn "Configuration cancelled"
            return 1
        fi
    fi

    # Write configuration file
    cat > shipnode.conf <<EOF
# ShipNode Configuration
# Generated from template: $template_name

# Application type
APP_TYPE=$app_type

# SSH Connection
SSH_USER=$ssh_user
SSH_HOST=$ssh_host
SSH_PORT=$ssh_port

# Deployment path
REMOTE_PATH=$remote_path
EOF

    # Backend-specific settings
    if [ "$app_type" = "backend" ]; then
        cat >> shipnode.conf <<EOF

# Backend settings
PM2_APP_NAME=$pm2_app_name
BACKEND_PORT=$backend_port
EOF
    fi

    # Domain (for both types if provided)
    if [ -n "$domain" ]; then
        cat >> shipnode.conf <<EOF

# Domain
DOMAIN=$domain
EOF
    fi

    # Zero-downtime settings
    cat >> shipnode.conf <<EOF

# Zero-downtime deployment
ZERO_DOWNTIME=$zero_downtime
KEEP_RELEASES=$keep_releases
EOF

    # Health check settings (backend only)
    if [ "$app_type" = "backend" ] && [ "$health_enabled" = "true" ]; then
        cat >> shipnode.conf <<EOF

# Health checks
HEALTH_CHECK_ENABLED=$health_enabled
HEALTH_CHECK_PATH=$health_check_path
HEALTH_CHECK_TIMEOUT=$health_timeout
HEALTH_CHECK_RETRIES=$health_retries
EOF
    fi

    success "Created shipnode.conf"

    # Users.yml wizard
    echo ""
    if prompt_yes_no "Add deployment users now?"; then
        init_users_yaml
    else
        info "You can add users later with: shipnode user sync"
    fi

    echo ""
    success "Initialization complete!"
    info "Next steps:"
    echo "  1. Review shipnode.conf"
    echo "  2. Run: shipnode setup"
    echo "  3. Run: shipnode deploy"
}

# Interactive initialization wizard
cmd_init_interactive() {
    # Check for existing config
    if [ -f "shipnode.conf" ]; then
        warn "shipnode.conf already exists"
        if ! prompt_yes_no "Overwrite?"; then
            info "Aborted"
            return 0
        fi
    fi

    # Welcome banner
    echo ""
    if [ "$USE_GUM" = true ]; then
        gum style \
            --border double \
            --border-foreground 212 \
            --align center \
            --width 50 \
            --margin "1 0" \
            --padding "1 2" \
            "ShipNode Interactive Setup"
    else
        echo -e "${BLUE}╔════════════════════════════════════╗${NC}"
        echo -e "${BLUE}║  ShipNode Interactive Setup        ║${NC}"
        echo -e "${BLUE}╚════════════════════════════════════╝${NC}"
    fi
    echo ""

    # Show tip about Gum if not installed
    show_gum_tip

    # 0. Offer template option
    local use_template=""
    if [ "$USE_GUM" = true ]; then
        if gum confirm "Would you like to use a framework template?"; then
            use_template=$(gum choose \
                "express" "nestjs" "fastify" "koa" "hapi" "hono" "adonisjs" \
                "nextjs" "nuxt" "remix" "astro" \
                "react" "vue" "svelte" "angular" "solid" \
                "custom" \
                --header "Select a template:" \
                --cursor-prefix "→ " \
                --selected-prefix "✓ ")

            if [ -n "$use_template" ]; then
                cmd_init_template "$use_template"
                return $?
            fi
        fi
    else
        if prompt_yes_no "Would you like to use a framework template?"; then
            echo ""
            list_templates
            echo ""
            read -p "Enter template name (or press Enter to skip): " use_template

            if [ -n "$use_template" ]; then
                cmd_init_template "$use_template"
                return $?
            fi
        fi
    fi

    # 1. Framework detection
    local detected_framework detected_type
    IFS='|' read -r detected_framework detected_type <<< "$(detect_framework)"

    if [ "$detected_framework" != "none" ]; then
        info "Detected framework: $detected_framework"
        info "Suggested app type: $detected_type"
        echo ""
    fi

    # 2. Prompt for app type
    local app_type
    
    if [ "$USE_GUM" = true ]; then
        # Enhanced selection with Gum
        local header="Select application type:"
        if [ "$detected_type" != "unknown" ]; then
            header="Select application type (detected: $detected_type):"
        fi
        
        local selection
        selection=$(gum choose \
            "Backend (Node.js API with PM2)" \
            "Frontend (Static site)" \
            --header "$header" \
            --cursor-prefix "→ " \
            --selected-prefix "✓ ")
        
        case "$selection" in
            "Backend"*) app_type="backend" ;;
            "Frontend"*) app_type="frontend" ;;
            *) 
                # Default to detected type if available
                if [ "$detected_type" != "unknown" ]; then
                    app_type="$detected_type"
                else
                    app_type="backend"
                fi
                ;;
        esac
    else
        # Classic bash selection
        echo "Application type:"
        echo "  1) Backend (Node.js API with PM2)"
        echo "  2) Frontend (Static site)"
        echo ""
        
        while true; do
            if [ "$detected_type" != "unknown" ]; then
                read -p "Choose [1-2] (detected: $detected_type): " choice
            else
                read -p "Choose [1-2]: " choice
            fi
            
            case "$choice" in
                1|backend) app_type="backend"; break ;;
                2|frontend) app_type="frontend"; break ;;
                "") 
                    if [ "$detected_type" != "unknown" ]; then
                        app_type="$detected_type"
                        break
                    fi
                    warn "Please choose an option"
                    ;;
                *) warn "Invalid choice" ;;
            esac
        done
    fi
    
    # 3. SSH connection details
    echo ""
    info "Server connection details"
    if [ "$USE_GUM" = false ]; then
        echo "Enter SSH credentials for your deployment server"
    fi
    echo ""
    
    local ssh_user ssh_host ssh_port
    
    # SSH User
    if [ "$USE_GUM" = true ]; then
        ssh_user=$(gum input --placeholder "root" --prompt "SSH user: " --value "root")
    else
        echo "  (The SSH user to connect with - typically 'root' or your username)"
        prompt_with_default "SSH user" "root" "ssh_user"
    fi
    
    # SSH Host with validation
    while true; do
        if [ "$USE_GUM" = true ]; then
            ssh_host=$(gum input --placeholder "192.168.1.100 or server.example.com" --prompt "SSH host: ")
        else
            echo "  (Your server's IP address or domain name - e.g. 192.168.1.100 or server.example.com)"
            read -p "SSH host (IP or hostname): " ssh_host
        fi
        
        if validate_ip_or_hostname "$ssh_host"; then
            break
        else
            warn "Invalid IP or hostname"
        fi
    done
    
    # SSH Port with validation
    while true; do
        if [ "$USE_GUM" = true ]; then
            local port_input
            port_input=$(gum input --placeholder "22" --prompt "SSH port: " --value "22")
            ssh_port="${port_input:-22}"
        else
            echo "  (SSH port - default is 22)"
            read -p "SSH port [22]: " ssh_port
            ssh_port="${ssh_port:-22}"
        fi
        
        if validate_port "$ssh_port"; then
            break
        else
            warn "Invalid port number"
        fi
    done
    
    # 4. Deployment path
    echo ""
    info "Deployment configuration"
    echo ""
    local remote_path app_name
    
    # Try to get app name from package.json
    if [ -f "package.json" ] && command -v jq &> /dev/null; then
        app_name=$(jq -r '.name // empty' package.json 2>/dev/null \
            | sed -E 's/^@[^/]+\///' \
            | tr ' ' '-' \
            | sed -E 's/[^A-Za-z0-9._-]+/-/g' \
            | sed -E 's/-+/-/g' \
            | sed -E 's/^-+|-+$//g')
    fi
    
    if [ -z "$app_name" ]; then
        app_name=$(basename "$PWD")
    fi
    
    if [ "$USE_GUM" = true ]; then
        remote_path=$(gum input --placeholder "/var/www/$app_name" --prompt "Deployment path: " --value "/var/www/$app_name")
    else
        echo "  (Directory on the server where your app will be deployed)"
        prompt_with_default "Remote deployment path" "/var/www/$app_name" "remote_path"
    fi
    
    # 5. Backend-specific config
    local pm2_app_name backend_port domain
    if [ "$app_type" = "backend" ]; then
        echo ""
        info "Backend configuration"
        if [ "$USE_GUM" = false ]; then
            echo "Configure your Node.js backend application"
        fi
        echo ""
        
        pm2_app_name="$app_name"
        
        # PM2 process name with validation
        while true; do
            if [ "$USE_GUM" = true ]; then
                pm2_app_name=$(gum input --placeholder "$app_name" --prompt "PM2 process name: " --value "$app_name")
            else
                read -p "PM2 process name [$app_name]: " pm2_input
                pm2_app_name="${pm2_input:-$app_name}"
            fi
            
            if validate_pm2_app_name "$pm2_app_name"; then
                break
            else
                warn "Invalid PM2 process name"
            fi
        done
        
        # Try to detect port
        local suggested_port
        suggested_port=$(suggest_port)
        
        # Backend port with validation
        while true; do
            if [ "$USE_GUM" = true ]; then
                backend_port=$(gum input --placeholder "${suggested_port:-3000}" --prompt "Application port: " --value "${suggested_port:-3000}")
            else
                echo "  (Port your Node.js app will listen on - typically 3000, 5000, or 8080)"
                read -p "Application port [${suggested_port:-3000}]: " backend_port
                backend_port="${backend_port:-${suggested_port:-3000}}"
            fi
            
            if validate_port "$backend_port"; then
                break
            else
                warn "Invalid port number"
            fi
        done
        
        # Domain (optional)
        while true; do
            if [ "$USE_GUM" = true ]; then
                domain=$(gum input --placeholder "api.myapp.com (optional)" --prompt "Domain: ")
            else
                echo "  (Optional: Your domain name for HTTPS - e.g. api.myapp.com)"
                read -p "Domain (optional, press Enter to skip): " domain
            fi
            
            if [ -z "$domain" ] || validate_domain "$domain"; then
                break
            else
                warn "Invalid domain"
            fi
        done
    fi
    
    # 6. Frontend-specific config
    if [ "$app_type" = "frontend" ]; then
        echo ""
        info "Frontend configuration"
        if [ "$USE_GUM" = false ]; then
            echo "Configure your static site deployment"
            echo ""
            echo "Note: Domain is required for frontend deployments (needed for Caddy web server)"
        fi
        echo ""
        
        # Domain is required for frontend
        while true; do
            if [ "$USE_GUM" = true ]; then
                domain=$(gum input --placeholder "myapp.com" --prompt "Domain (required): ")
            else
                echo "  (Your domain name - e.g. myapp.com or www.myapp.com)"
                read -p "Domain: " domain
            fi
            
            if [ -n "$domain" ] && validate_domain "$domain"; then
                break
            elif [ -z "$domain" ]; then
                warn "Domain is required for frontend deployments"
            else
                warn "Invalid domain"
            fi
        done
    fi
    
    # Use defaults for advanced options
    local zero_downtime="true"
    local keep_releases="5"
    local health_enabled="true"
    local health_path="/health"
    local health_timeout="30"
    local health_retries="3"
    
    # 7. Configuration summary
    echo ""
    if [ "$USE_GUM" = true ]; then
        gum style \
            --border rounded \
            --border-foreground 99 \
            --padding "1 2" \
            --margin "1 0" \
            "Configuration Summary" \
            "" \
            "App Type:      $app_type" \
            "SSH:           $ssh_user@$ssh_host:$ssh_port" \
            "Remote Path:   $remote_path" \
            $([ "$app_type" = "backend" ] && echo "PM2 Name:      $pm2_app_name") \
            $([ "$app_type" = "backend" ] && echo "Backend Port:  $backend_port") \
            $([ -n "$domain" ] && echo "Domain:        $domain") \
            "Zero-downtime: $zero_downtime" \
            $([ "$app_type" = "backend" ] && [ "$health_enabled" = "true" ] && echo "Health Checks: $health_path (${health_timeout}s, $health_retries retries)")
    else
        echo -e "${BLUE}════════════════════════════════════${NC}"
        echo -e "${BLUE}Configuration Summary${NC}"
        echo -e "${BLUE}════════════════════════════════════${NC}"
        echo "App Type:      $app_type"
        echo "SSH:           $ssh_user@$ssh_host:$ssh_port"
        echo "Remote Path:   $remote_path"
        
        if [ "$app_type" = "backend" ]; then
            echo "PM2 Name:      $pm2_app_name"
            echo "Backend Port:  $backend_port"
        fi
        
        [ -n "$domain" ] && echo "Domain:        $domain"
        echo "Zero-downtime: $zero_downtime"
        
        if [ "$app_type" = "backend" ] && [ "$health_enabled" = "true" ]; then
            echo "Health Checks: $health_path (${health_timeout}s timeout, ${health_retries} retries)"
        fi
        
        echo -e "${BLUE}════════════════════════════════════${NC}"
    fi
    echo ""
    
    # Final confirmation
    if [ "$USE_GUM" = true ]; then
        if ! gum confirm "Create shipnode.conf with these settings?"; then
            warn "Configuration cancelled"
            return 1
        fi
    else
        if ! prompt_yes_no "Create shipnode.conf with these settings?" "y"; then
            warn "Configuration cancelled"
            return 1
        fi
    fi
    
    # 8. Write configuration file
    cat > shipnode.conf <<EOF
# ShipNode Configuration
# Generated by interactive wizard

# Application type
APP_TYPE=$app_type

# SSH Connection
SSH_USER=$ssh_user
SSH_HOST=$ssh_host
SSH_PORT=$ssh_port

# Deployment path
REMOTE_PATH=$remote_path
EOF

    # Backend-specific settings
    if [ "$app_type" = "backend" ]; then
        cat >> shipnode.conf <<EOF

# Backend settings
PM2_APP_NAME=$pm2_app_name
BACKEND_PORT=$backend_port
EOF
    fi

    # Domain (for both types if provided)
    if [ -n "$domain" ]; then
        cat >> shipnode.conf <<EOF

# Domain
DOMAIN=$domain
EOF
    fi

    # Zero-downtime settings
    cat >> shipnode.conf <<EOF

# Zero-downtime deployment
ZERO_DOWNTIME=$zero_downtime
KEEP_RELEASES=$keep_releases
EOF

    # Health check settings (backend only)
    if [ "$app_type" = "backend" ] && [ "$health_enabled" = "true" ]; then
        cat >> shipnode.conf <<EOF

# Health checks
HEALTH_CHECK_ENABLED=$health_enabled
HEALTH_CHECK_PATH=$health_path
HEALTH_CHECK_TIMEOUT=$health_timeout
HEALTH_CHECK_RETRIES=$health_retries
EOF
    fi

    success "Created shipnode.conf"
    
    # 9. Users.yml wizard
    echo ""
    if prompt_yes_no "Add deployment users now?"; then
        init_users_yaml
    else
        info "You can add users later with: shipnode user sync"
    fi
    
    echo ""
    success "Initialization complete!"
    info "Next steps:"
    echo "  1. Review shipnode.conf"
    echo "  2. Run: shipnode setup"
    echo "  3. Run: shipnode deploy"
}

# Initialize config file (router)
cmd_init() {
    # Handle --template flag
    if [ "$1" = "--template" ]; then
        if [ -z "$2" ]; then
            error "Template name required"
            echo ""
            list_templates
            return 1
        fi
        cmd_init_template "$2"
    elif [ "$1" = "--list-templates" ]; then
        list_templates
    elif [ "$1" = "--non-interactive" ]; then
        cmd_init_legacy
    else
        cmd_init_interactive
    fi
}

# Setup server (first-time)
