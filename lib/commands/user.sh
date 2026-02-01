cmd_user_sync() {
    load_config

    local yaml_file="users.yml"

    if [ ! -f "$yaml_file" ]; then
        error "users.yml not found. Create it first with user definitions."
    fi

    info "Syncing users from users.yml..."

    # Ensure .shipnode directory exists
    remote_exec "mkdir -p $REMOTE_PATH/.shipnode"

    # Initialize users.json if it doesn't exist
    remote_exec bash << ENDSSH
        if [ ! -f $REMOTE_PATH/.shipnode/users.json ]; then
            echo '{"users":[]}' > $REMOTE_PATH/.shipnode/users.json
        fi
ENDSSH

    # Parse users.yml
    local users_data=$(parse_users_yaml "$yaml_file")

    if [ -z "$users_data" ]; then
        warn "No users found in users.yml"
        return 0
    fi

    # Process each user
    while IFS='|' read -r username email password sudo authorized_key authorized_key_file authorized_keys; do
        # Validate username
        if ! validate_username "$username"; then
            warn "Invalid username: $username (skipping)"
            continue
        fi

        # Validate email
        if [ -z "$email" ]; then
            warn "No email for user: $username (skipping)"
            continue
        fi

        # Validate password if provided
        if [ -n "$password" ] && ! validate_password_hash "$password"; then
            warn "Invalid password hash for user: $username (skipping)"
            continue
        fi

        # Create user
        local result=$(create_remote_user "$username" "$email" "$password")
        local user_exists=false

        if [ "$result" = "EXISTS" ]; then
            user_exists=true
            info "User exists: $username (updating SSH keys if provided)"
        fi

        local auth_method=""

        # Setup SSH if keys provided
        if [ -n "$authorized_key" ] || [ -n "$authorized_key_file" ] || [ -n "$authorized_keys" ]; then
            setup_user_ssh_dir "$username"
            auth_method="ssh-key"

            # Add inline authorized key
            if [ -n "$authorized_key" ]; then
                if validate_ssh_key "$authorized_key"; then
                    add_user_ssh_key "$username" "$authorized_key"
                else
                    warn "Invalid SSH key for user: $username"
                fi
            fi

            # Add key from file
            if [ -n "$authorized_key_file" ]; then
                local key_content=$(read_key_file "$authorized_key_file")
                if [ -n "$key_content" ] && validate_ssh_key "$key_content"; then
                    add_user_ssh_key "$username" "$key_content"
                else
                    warn "Invalid or missing SSH key file: $authorized_key_file"
                fi
            fi

            # Add multiple keys
            if [ -n "$authorized_keys" ]; then
                IFS=':::' read -ra KEYS <<< "$authorized_keys"
                for key in "${KEYS[@]}"; do
                    if validate_ssh_key "$key"; then
                        add_user_ssh_key "$username" "$key"
                    else
                        warn "Invalid SSH key in authorized_keys for user: $username"
                    fi
                done
            fi
        elif [ -n "$password" ]; then
            auth_method="password"
        else
            warn "User $username has no password or SSH keys (skipping)"
            continue
        fi

        # Skip these steps for existing users
        if [ "$user_exists" = false ]; then
            # Grant deploy permissions
            grant_deploy_permissions "$username"

            # Grant sudo if requested
            if [ "$sudo" = "true" ]; then
                grant_sudo_access "$username"
            fi

            # Record user in users.json
            remote_exec bash << ENDSSH
                cd $REMOTE_PATH/.shipnode
                CURRENT_DATE=\$(date -Is)
                jq ".users += [{\"username\":\"$username\",\"email\":\"$email\",\"auth\":\"$auth_method\",\"sudo\":$sudo,\"created_at\":\"\$CURRENT_DATE\"}]" users.json > users.json.tmp
                mv users.json.tmp users.json
ENDSSH

            # Report creation
            local sudo_msg=""
            [ "$sudo" = "true" ] && sudo_msg=", sudo enabled"

            if [ "$auth_method" = "password" ]; then
                success "Created user: $username (password auth, must change on first login$sudo_msg)"
            else
                success "Created user: $username (SSH key added$sudo_msg)"
            fi
        else
            # Report update for existing user
            success "Updated SSH keys for existing user: $username"
        fi

    done <<< "$users_data"

    success "User sync complete"
}

cmd_user_list() {
    load_config

    info "Listing provisioned users..."

    # Check if users.json exists
    local has_users=$(remote_exec "[ -f $REMOTE_PATH/.shipnode/users.json ] && echo 'yes' || echo 'no'")

    if [ "$has_users" = "no" ]; then
        warn "No users provisioned yet. Run 'shipnode user sync' first."
        return 0
    fi

    # Fetch and display users
    remote_exec bash << ENDSSH
        echo ""
        printf "%-15s %-30s %-12s %-8s %s\n" "USERNAME" "EMAIL" "AUTH" "SUDO" "CREATED"
        echo "==================================================================================="

        cat $REMOTE_PATH/.shipnode/users.json | jq -r '.users[] | "\(.username)|\(.email)|\(.auth)|\(.sudo)|\(.created_at)"' | while IFS='|' read -r username email auth sudo created; do
            # Format created date
            created_short=$(echo "$created" | cut -d'T' -f1)
            sudo_text="no"
            [ "$sudo" = "true" ] && sudo_text="yes"

            printf "%-15s %-30s %-12s %-8s %s\n" "$username" "$email" "$auth" "$sudo_text" "$created_short"
        done

        echo ""
        total=$(cat $REMOTE_PATH/.shipnode/users.json | jq '.users | length')
        echo "Total: $total users"
ENDSSH
}

cmd_user_remove() {
    local username=$1

    if [ -z "$username" ]; then
        error "Usage: shipnode user remove <username>"
    fi

    load_config

    warn "This will revoke access for user: $username"
    read -p "Continue? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        info "Cancelled"
        return 0
    fi

    info "Revoking access for: $username..."

    # Revoke access
    revoke_user_access "$username"

    # Remove from users.json
    remote_exec bash << ENDSSH
        if [ -f $REMOTE_PATH/.shipnode/users.json ]; then
            cd $REMOTE_PATH/.shipnode
            jq ".users = [.users[] | select(.username != \"$username\")]" users.json > users.json.tmp
            mv users.json.tmp users.json
        fi
ENDSSH

    success "Access revoked for: $username"
}

