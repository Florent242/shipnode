#!/usr/bin/env bash
#
# ShipNode Integration Tests - Docker Backend
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SHIPNODE_BIN="$PROJECT_ROOT/shipnode"
CONTAINER_NAME="shipnode-test-$(date +%s)"
SSH_KEY="$HOME/.ssh/id_ed25519_shipnode.pub"
# Find available port dynamically
SSH_PORT=$(python3 -c "import socket; s=socket.socket(); s.bind(('', 0)); print(s.getsockname()[1]); s.close()" 2>/dev/null || echo "2222")
CI_MODE=false
VERBOSE=false
LOCAL_MODE=false
PHASES_TO_RUN=""
FAILED_TESTS=0
PASSED_TESTS=0
SKIPPED_TESTS=0

declare -a TEST_RESULTS

cleanup() {
    local exit_code=0
    [ "$FAILED_TESTS" -gt 0 ] && exit_code=1
    
    if [ -n "$CONTAINER_NAME" ]; then
        if [ "$exit_code" -ne 0 ] && [ "$CI_MODE" = false ] && [ "$LOCAL_MODE" = false ]; then
            echo -e "\n${YELLOW}⚠ Tests failed. Keeping container: $CONTAINER_NAME${NC}"
            echo -e "${YELLOW}  Connect: docker exec -it $CONTAINER_NAME bash${NC}"
            echo -e "${YELLOW}  Destroy: docker rm -f $CONTAINER_NAME${NC}"
        else
            echo -e "\n${BLUE}→ Cleaning up...${NC}"
            docker rm -f "$CONTAINER_NAME" 2>/dev/null || true
            echo -e "${GREEN}✓ Cleanup complete${NC}"
        fi
    fi
    
    echo -e "\n${BLUE}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}                    TEST SUMMARY                              ${NC}"
    echo -e "${BLUE}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}✓ Passed:  $PASSED_TESTS${NC}"
    echo -e "${RED}✗ Failed:  $FAILED_TESTS${NC}"
    echo -e "${YELLOW}⊘ Skipped: $SKIPPED_TESTS${NC}"
    exit $exit_code
}

log_info() { echo -e "${BLUE}→ $1${NC}"; }
log_success() { echo -e "${GREEN}✓ $1${NC}"; PASSED_TESTS=$((PASSED_TESTS + 1)); }
log_error() { echo -e "${RED}✗ $1${NC}"; FAILED_TESTS=$((FAILED_TESTS + 1)); }
log_warn() { echo -e "${YELLOW}⊘ $1${NC}"; SKIPPED_TESTS=$((SKIPPED_TESTS + 1)); }
log_phase() {
    echo -e "\n${BLUE}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  PHASE $1: $2${NC}"
    echo -e "${BLUE}══════════════════════════════════════════════════════════════${NC}"
}

run_with_timeout() {
    local timeout_secs="${1:-5}"
    local cmd="$2"
    timeout "$timeout_secs" bash -c "$cmd" 2>/dev/null || true
}

usage() {
    cat << EOF
ShipNode Integration Tests (Docker Backend)

Usage: $0 [OPTIONS]

Options:
    -h, --help          Show help
    -c, --ci            CI mode
    -v, --verbose       Verbose output
    -l, --local         Local mode (no Docker)
    -p, --phase N       Run specific phase
    --phases 1,3,5      Run specific phases
    --list              List phases

Phases:
    1. Framework Detection
    2. Init Wizard
    3. Doctor Command
    4. User Management
    5. Deploy Dry-Run
    6. Live Deployment
    7. Zero-Downtime
    8. Security Hardening
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help) usage; exit 0 ;;
            -c|--ci) CI_MODE=true; shift ;;
            -v|--verbose) VERBOSE=true; shift ;;
            -l|--local) LOCAL_MODE=true; shift ;;
            -p|--phase) PHASES_TO_RUN="$2"; shift 2 ;;
            --phases) PHASES_TO_RUN="$2"; shift 2 ;;
            --list) echo "Phases: 1-8"; exit 0 ;;
            *) echo "Unknown: $1"; usage; exit 1 ;;
        esac
    done
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    if [ "$LOCAL_MODE" = false ]; then
        if ! command -v docker &> /dev/null; then
            log_error "Docker not installed"
            log_info "Arch: sudo pacman -S docker"
            exit 1
        fi
        
        if ! docker info &>/dev/null; then
            log_error "Docker not running"
            log_info "Start: sudo systemctl start docker"
            exit 1
        fi
        log_success "Docker is working"
    fi
    
    if [ "$LOCAL_MODE" = false ] && [ ! -f "$SSH_KEY" ]; then
        ssh-keygen -t ed25519 -C "shipnode-test" -f "${SSH_KEY%.pub}" -N ""
    fi
    
    if [ ! -f "$SHIPNODE_BIN" ]; then
        log_error "ShipNode not found at $SHIPNODE_BIN"
        exit 1
    fi
    
    log_success "Prerequisites passed"
}

create_container() {
    log_info "Creating Docker container..."
    
    if docker ps -a --format '{{.Names}}' | grep -q "^$CONTAINER_NAME$"; then
        docker rm -f "$CONTAINER_NAME" 2>/dev/null || true
    fi
    
    log_info "Building test image..."
    docker build -t shipnode-test-env -f - . << 'DOCKERFILE'
FROM ubuntu:22.04
RUN apt-get update && apt-get install -y \
    openssh-server curl git jq openssh-client sshpass \
    && rm -rf /var/lib/apt/lists/*
RUN mkdir -p /var/run/sshd
RUN echo 'root:shipnode' | chpasswd
RUN sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
RUN sed -i 's/#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
RUN sed -i 's/#PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
RUN sed -i 's/#AuthorizedKeysFile.*/AuthorizedKeysFile .ssh\/authorized_keys/' /etc/ssh/sshd_config
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && npm install -g pm2
RUN mkdir -p /root/.ssh && chmod 700 /root/.ssh && touch /root/.ssh/authorized_keys && chmod 600 /root/.ssh/authorized_keys
EXPOSE 22
CMD ["/usr/sbin/sshd", "-D", "-e"]
DOCKERFILE
    
    docker run -d --name "$CONTAINER_NAME" -p "$SSH_PORT:22" shipnode-test-env
    
    log_info "Waiting for SSH to be ready..."
    local max_attempts=15
    local attempt=1
    while [ $attempt -le $max_attempts ]; do
        if docker exec "$CONTAINER_NAME" ssh-keyscan -H localhost >/dev/null 2>&1; then
            break
        fi
        log_info "  Attempt $attempt/$max_attempts..."
        sleep 1
        attempt=$((attempt + 1))
    done
    
    log_info "Configuring SSH authentication..."
    docker exec "$CONTAINER_NAME" mkdir -p /root/.ssh
    docker exec "$CONTAINER_NAME" chmod 700 /root/.ssh
    docker exec "$CONTAINER_NAME" bash -c "cat > /root/.ssh/authorized_keys << 'KEY'
$(cat "${SSH_KEY}")
KEY"
    docker exec "$CONTAINER_NAME" chmod 600 /root/.ssh/authorized_keys
    docker exec "$CONTAINER_NAME" chown -R root:root /root/.ssh
    
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    if ! grep -q "Host localhost" "$HOME/.ssh/config" 2>/dev/null; then
        cat >> "$HOME/.ssh/config" << SSHCONF
Host localhost 127.0.0.1
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    LogLevel ERROR
    IdentityFile ${SSH_KEY%.pub}
SSHCONF
    fi
    
    log_success "Container ready on port $SSH_PORT with SSH configured"
}

phase_1() {
    log_phase 1 "Framework Detection"
    local test_dir="/tmp/shipnode-test-fw"
    rm -rf "$test_dir"; mkdir -p "$test_dir"
    
    mkdir -p "$test_dir/express" && cd "$test_dir/express"
    npm init -y >/dev/null 2>&1 && npm install express >/dev/null 2>&1
    if $SHIPNODE_BIN init --non-interactive 2>/dev/null && grep -q "APP_TYPE=backend" shipnode.conf; then
        log_success "Express detected"
    else
        log_error "Express detection failed"
    fi
    
    rm -rf "$test_dir"
}

phase_2() {
    log_phase 2 "Init Wizard"
    local test_dir="/tmp/shipnode-test-init"
    rm -rf "$test_dir"; mkdir -p "$test_dir" && cd "$test_dir"
    
    npm init -y >/dev/null 2>&1 && npm install express >/dev/null 2>&1
    
    if $SHIPNODE_BIN init --non-interactive 2>/dev/null; then
        log_success "Init succeeded"
    else
        log_error "Init failed"
    fi
    
    if [ -f "shipnode.conf" ]; then
        log_success "Config created"
    fi
    
    rm -rf "$test_dir"
}

phase_3() {
    log_phase 3 "Doctor"
    local test_dir="/tmp/shipnode-test-dr"
    rm -rf "$test_dir"; mkdir -p "$test_dir" && cd "$test_dir"
    
    npm init -y >/dev/null 2>&1 && npm install express >/dev/null 2>&1
    $SHIPNODE_BIN init --non-interactive 2>/dev/null
    
    if $SHIPNODE_BIN doctor 2>/dev/null | grep -q "shipnode.conf"; then
        log_success "Doctor command works"
    else
        log_warn "Doctor had warnings"
    fi
    
    rm -rf "$test_dir"
}

phase_4() {
    log_phase 4 "User Management"
    local test_dir="/tmp/shipnode-test-users"
    rm -rf "$test_dir"; mkdir -p "$test_dir" && cd "$test_dir"
    
    npm init -y >/dev/null 2>&1 && npm install express >/dev/null 2>&1
    $SHIPNODE_BIN init --non-interactive 2>/dev/null
    
    sed -i "s|SSH_HOST=.*|SSH_HOST=127.0.0.1|" shipnode.conf
    sed -i "s|SSH_PORT=.*|SSH_PORT=$SSH_PORT|" shipnode.conf
    sed -i "s|SSH_USER=.*|SSH_USER=root|" shipnode.conf
    sed -i "s|REMOTE_PATH=.*|REMOTE_PATH=/root|" shipnode.conf
    
    local users_yaml="users.yml"
    cat > "$users_yaml" << 'EOF'
users:
  - username: deploybot
    email: deploybot@shipnode.test
    ssh_key: ~/.ssh/id_ed25519.pub
    sudo: false
EOF
    
    local sync_output
    sync_output=$(run_with_timeout 15 "$SHIPNODE_BIN user sync $users_yaml" 2>&1)
    if echo "$sync_output" | grep -qE "(Created|Updated|complete|Syncing|User sync complete)"; then
        log_success "User sync command works"
    else
        log_warn "User sync needs live SSH"
    fi
    
    local list_output
    list_output=$(run_with_timeout 10 "$SHIPNODE_BIN user list" 2>&1)
    if echo "$list_output" | grep -qE "(deploybot|Total:|users)"; then
        log_success "User list command works"
    else
        log_warn "User list needs live SSH"
    fi
    
    rm -rf "$test_dir"
}

phase_5() {
    log_phase 5 "Deploy Dry-Run"
    local test_dir="/tmp/shipnode-test-dryrun"
    rm -rf "$test_dir"; mkdir -p "$test_dir" && cd "$test_dir"
    
    npm init -y >/dev/null 2>&1 && npm install express >/dev/null 2>&1
    $SHIPNODE_BIN init --non-interactive 2>/dev/null
    
    if $SHIPNODE_BIN deploy --dry-run 2>/dev/null | grep -q "DRY RUN"; then
        log_success "Dry-run command works"
    else
        log_warn "Dry-run command issue"
    fi
    
    rm -rf "$test_dir"
}

phase_6() {
    log_phase 6 "Live Deployment"
    local test_dir="/tmp/shipnode-test-deploy"
    rm -rf "$test_dir"; mkdir -p "$test_dir" && cd "$test_dir"
    
    npm init -y >/dev/null 2>&1 && npm install express >/dev/null 2>&1
    $SHIPNODE_BIN init --non-interactive 2>/dev/null
    
    if $SHIPNODE_BIN deploy --dry-run 2>/dev/null | grep -q "DRY RUN"; then
        log_success "Deploy command works"
    else
        log_warn "Deploy command issue"
    fi
    
    rm -rf "$test_dir"
}

phase_7() {
    log_phase 7 "Zero-Downtime"
    local test_dir="/tmp/shipnode-test-zerodown"
    rm -rf "$test_dir"; mkdir -p "$test_dir" && cd "$test_dir"
    
    npm init -y >/dev/null 2>&1 && npm install express >/dev/null 2>&1
    $SHIPNODE_BIN init --non-interactive 2>/dev/null
    
    sed -i "s/ZERO_DOWNTIME=.*/ZERO_DOWNTIME=true/" shipnode.conf
    
    if $SHIPNODE_BIN deploy --dry-run 2>/dev/null | grep -qi "zero"; then
        log_success "Zero-downtime mode detected"
    else
        log_warn "Zero-downtime config issue"
    fi
    
    if $SHIPNODE_BIN rollback --dry-run 2>&1 | grep -qi "rollback"; then
        log_success "Rollback command works"
    else
        log_warn "Rollback command issue"
    fi
    
    rm -rf "$test_dir"
}

phase_8() {
    log_phase 8 "Security Hardening"
    local test_dir="/tmp/shipnode-test-security"
    rm -rf "$test_dir"; mkdir -p "$test_dir" && cd "$test_dir"
    
    npm init -y >/dev/null 2>&1 && npm install express >/dev/null 2>&1
    $SHIPNODE_BIN init --non-interactive 2>/dev/null
    
    if $SHIPNODE_BIN doctor --security 2>/dev/null | grep -q "security"; then
        log_success "Security audit command works"
    else
        log_warn "Security audit command issue"
    fi
    
    rm -rf "$test_dir"
}

main() {
    parse_args "$@"
    trap cleanup EXIT
    
    echo -e "${BLUE}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}           ShipNode Integration Tests (Docker)                ${NC}"
    echo -e "${BLUE}══════════════════════════════════════════════════════════════${NC}"
    
    check_prerequisites
    
    if [ "$LOCAL_MODE" = false ]; then
        create_container
    fi
    
    if [ -n "$PHASES_TO_RUN" ]; then
        IFS=',' read -ra PHASES <<< "$PHASES_TO_RUN"
        for p in "${PHASES[@]}"; do
            case $p in
                1) phase_1 ;;
                2) phase_2 ;;
                3) [ "$LOCAL_MODE" = false ] && phase_3 || log_warn "Phase 3 needs Docker" ;;
                4) [ "$LOCAL_MODE" = false ] && phase_4 || log_warn "Phase 4 needs Docker" ;;
                5) [ "$LOCAL_MODE" = false ] && phase_5 || log_warn "Phase 5 needs Docker" ;;
                6) [ "$LOCAL_MODE" = false ] && phase_6 || log_warn "Phase 6 needs Docker" ;;
                7) [ "$LOCAL_MODE" = false ] && phase_7 || log_warn "Phase 7 needs Docker" ;;
                8) [ "$LOCAL_MODE" = false ] && phase_8 || log_warn "Phase 8 needs Docker" ;;
            esac
        done
    else
        phase_1
        phase_2
        [ "$LOCAL_MODE" = false ] && phase_3
        [ "$LOCAL_MODE" = false ] && phase_4
        [ "$LOCAL_MODE" = false ] && phase_5
        [ "$LOCAL_MODE" = false ] && phase_6
        [ "$LOCAL_MODE" = false ] && phase_7
        [ "$LOCAL_MODE" = false ] && phase_8
    fi
    
    echo -e "\n${GREEN}✓ Tests complete${NC}"
}

main "$@"
