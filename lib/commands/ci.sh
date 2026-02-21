has_gh() {
    command -v gh &> /dev/null
}

install_gh() {
    if has_gh; then
        return 0
    fi

    info "GitHub CLI (gh) not found. Installing..."

    local os_info pkg_manager
    IFS='|' read -r os_info pkg_manager <<< "$(detect_os)"

    local install_success=false
    local log_file="/tmp/shipnode_gh_install_$$.log"

    case "$pkg_manager" in
        apt)
            info "Using apt to install GitHub CLI..."
            {
                type -p curl >/dev/null || (sudo apt update && sudo apt install curl -y)
                curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
                && sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
                && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
                && sudo apt update \
                && sudo apt install gh -y
            } &> "$log_file" && install_success=true
            ;;
        dnf|yum)
            info "Using $pkg_manager to install GitHub CLI..."
            sudo "$pkg_manager" install gh -y &> "$log_file" && install_success=true
            ;;
        brew)
            info "Using Homebrew to install GitHub CLI..."
            brew install gh &> "$log_file" && install_success=true
            ;;
        apk)
            info "Using apk to install GitHub CLI..."
            sudo apk add --no-cache github-cli &> "$log_file" && install_success=true
            ;;
        pacman)
            info "Using pacman to install GitHub CLI..."
            sudo pacman -S --noconfirm github-cli &> "$log_file" && install_success=true
            ;;
        *)
            warn "Unsupported package manager: $pkg_manager"
            info "Please install GitHub CLI manually: https://github.com/cli/cli#installation"
            return 1
            ;;
    esac

    if [ "$install_success" = true ] && has_gh; then
        success "GitHub CLI installed successfully! ($(gh --version 2>&1 | head -n1))"
        rm -f "$log_file"
        return 0
    else
        warn "Failed to install GitHub CLI automatically"
        if [ -f "$log_file" ]; then
            warn "Installation log available at: $log_file"
        fi
        info "Please install GitHub CLI manually: https://github.com/cli/cli#installation"
        return 1
    fi
}

cmd_ci() {
    local subcommand="${1:-}"

    case "$subcommand" in
        github)
            cmd_ci_github
            ;;
        env-sync)
            cmd_ci_env_sync
            ;;
        *)
            error "Unknown CI command: $subcommand\nAvailable: github, env-sync"
            ;;
    esac
}

cmd_ci_github() {
    local workflow_path=".github/workflows/shipnode-deploy.yml"
    local workflow_dir=".github/workflows"

    # Check if already exists
    if [ -f "$workflow_path" ]; then
        warn "Workflow already exists at $workflow_path"
        read -p "Overwrite? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            info "Aborted."
            return 0
        fi
    fi

    # Create directory if needed
    if [ ! -d "$workflow_dir" ]; then
        mkdir -p "$workflow_dir"
        info "Created $workflow_dir directory"
    fi

    # Detect package manager
    local pkg_manager="npm"
    if [ -f "pnpm-lock.yaml" ]; then
        pkg_manager="pnpm"
    elif [ -f "yarn.lock" ]; then
        pkg_manager="yarn"
    elif [ -f "bun.lockb" ]; then
        pkg_manager="bun"
    fi

    # Generate cache and install commands based on package manager
    local cache_cmd=""
    local install_cmd=""
    case "$pkg_manager" in
        pnpm)
            cache_cmd="cache: 'pnpm'"
            install_cmd="pnpm install --frozen-lockfile"
            ;;
        yarn)
            cache_cmd="cache: 'yarn'"
            install_cmd="yarn install --frozen-lockfile"
            ;;
        bun)
            cache_cmd=""
            install_cmd="bun install"
            ;;
        *)
            cache_cmd="cache: 'npm'"
            install_cmd="npm ci"
            ;;
    esac

    # Generate workflow file
    cat > "$workflow_path" << EOF
name: Deploy with ShipNode

on:
  push:
    branches: [ main, master ]
  workflow_dispatch:

jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          ${cache_cmd}

      - name: Install dependencies
        run: ${install_cmd}

      - name: Build application
        run: ${pkg_manager} run build
        # Remove this step if your app doesn't have a build script

      - name: Install ShipNode
        run: |
          curl -fsSL https://shipnode.dev/install.sh | bash

      - name: Setup SSH
        uses: webfactory/ssh-agent@v0.9.0
        with:
          ssh-private-key: \\\${{ secrets.SHIPNODE_SSH_KEY }}
          log-public-key: false

      - name: Add host to known hosts
        run: |
          mkdir -p ~/.ssh
          ssh-keyscan -p \\\${{ secrets.SHIPNODE_SSH_PORT }} \\\${{ secrets.SHIPNODE_SSH_HOST }} >> ~/.ssh/known_hosts

      - name: Deploy with ShipNode
        env:
          SHIPNODE_SSH_HOST: \\\${{ secrets.SHIPNODE_SSH_HOST }}
          SHIPNODE_SSH_USER: \\\${{ secrets.SHIPNODE_SSH_USER }}
          SHIPNODE_SSH_PORT: \\\${{ secrets.SHIPNODE_SSH_PORT }}
        run: |
          shipnode deploy
EOF

    success "Created GitHub Actions workflow: $workflow_path"
    echo
    info "Required GitHub Secrets:"
    echo
    echo "  SHIPNODE_SSH_KEY      - SSH private key for server access"
    echo "  SHIPNODE_SSH_HOST     - Server hostname or IP address"
    echo "  SHIPNODE_SSH_USER     - SSH username"
    echo "  SHIPNODE_SSH_PORT     - SSH port (usually 22)"
    echo
    info "Add these secrets in your repository settings:"
    echo "  Settings > Secrets and variables > Actions > Repository secrets"
    echo
    info "ShipNode configuration should be in shipnode.conf at repository root"
    echo
    info "Tip: Run 'shipnode ci env-sync' to sync shipnode.conf values to GitHub secrets"
    echo
}

cmd_ci_env_sync() {
    local sync_all=false
    local env_file="${ENV_FILE:-.env}"

    # Parse arguments
    for arg in "$@"; do
        case "$arg" in
            --all)
                sync_all=true
                ;;
            --env-file)
                env_file="$2"
                shift
                ;;
        esac
    done

    load_config

    # Check for GitHub CLI
    if ! has_gh; then
        install_gh || error "GitHub CLI (gh) is required for this command"
    fi

    # Check if we're in a git repo with GitHub remote
    if ! git remote -v &> /dev/null || ! git remote -v | grep -q "github.com"; then
        error "Not a GitHub repository. This command requires a repository hosted on GitHub."
    fi

    # Check if authenticated with GitHub
    if ! gh auth status &> /dev/null; then
        warn "Not authenticated with GitHub"
        info "Please run: gh auth login"
        error "Authentication required to manage repository secrets"
    fi

    info "Syncing environment variables to GitHub secrets..."
    echo

    local secrets_set=0
    local secrets_skipped=0
    local secrets_failed=0

    # Required secrets from shipnode.conf
    declare -A secrets_map
    secrets_map["SHIPNODE_SSH_HOST"]="$SSH_HOST"
    secrets_map["SHIPNODE_SSH_USER"]="$SSH_USER"
    secrets_map["SHIPNODE_SSH_PORT"]="$SSH_PORT"

    info "=== ShipNode Configuration Secrets ==="
    echo

    for secret_name in "${!secrets_map[@]}"; do
        local secret_value="${secrets_map[$secret_name]}"

        if [ -z "$secret_value" ]; then
            warn "Skipping $secret_name: value not set in shipnode.conf"
            ((secrets_skipped++))
            continue
        fi

        info "Setting $secret_name..."
        if gh secret set "$secret_name" --body "$secret_value" 2>/dev/null; then
            success "Set $secret_name"
            ((secrets_set++))
        else
            warn "Failed to set $secret_name"
            ((secrets_failed++))
        fi
    done

    # Sync .env file if it exists
    if [ -f "$env_file" ]; then
        echo
        info "=== Environment File Secrets ($env_file) ==="
        echo

        if [ "$sync_all" = false ]; then
            warn "The following secrets will be synced from $env_file:"
            echo
            while IFS= read -r line || [[ -n "$line" ]]; do
                # Skip comments and empty lines
                [[ "$line" =~ ^[[:space:]]*# ]] && continue
                [[ -z "$line" ]] && continue

                # Extract variable name
                if [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)= ]]; then
                    local var_name="${BASH_REMATCH[1]}"
                    echo "  - $var_name"
                fi
            done < "$env_file"
            echo
            read -p "Proceed with syncing these secrets? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                info "Skipping .env file sync"
            else
                sync_all=true
            fi
        fi

        if [ "$sync_all" = true ]; then
            while IFS= read -r line || [[ -n "$line" ]]; do
                # Skip comments and empty lines
                [[ "$line" =~ ^[[:space:]]*# ]] && continue
                [[ -z "$line" ]] && continue

                # Extract variable name and value
                if [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
                    local var_name="${BASH_REMATCH[1]}"
                    local var_value="${BASH_REMATCH[2]}"

                    # Remove quotes if present
                    if [[ "$var_value" =~ ^\"(.*)\"$ ]] || [[ "$var_value" =~ ^\'(.*)\'$ ]]; then
                        var_value="${BASH_REMATCH[1]}"
                    fi

                    if [ -n "$var_value" ]; then
                        info "Setting $var_name..."
                        if gh secret set "$var_name" --body "$var_value" 2>/dev/null; then
                            success "Set $var_name"
                            ((secrets_set++))
                        else
                            warn "Failed to set $var_name"
                            ((secrets_failed++))
                        fi
                    else
                        warn "Skipping $var_name: empty value"
                        ((secrets_skipped++))
                    fi
                fi
            done < "$env_file"
        fi
    else
        echo
        warn "Environment file not found: $env_file"
        warn "Set ENV_FILE in shipnode.conf to specify a different file"
    fi

    echo
    info "=== Results ==="
    echo "  Set: $secrets_set"
    echo "  Skipped: $secrets_skipped"
    echo "  Failed: $secrets_failed"
    echo

    # Special handling for SSH key - we can't read the private key from config
    if ! gh secret list 2>/dev/null | grep -q "SHIPNODE_SSH_KEY"; then
        warn "SHIPNODE_SSH_KEY is not set"
        info "Please set it manually with: gh secret set SHIPNODE_SSH_KEY < ~/.ssh/id_rsa"
        echo
    fi

    info "GitHub Secrets configured. The workflow can now access these values."
}
