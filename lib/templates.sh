#!/usr/bin/env bash
#
# ShipNode Templates
# Predefined configurations for popular frameworks
#

# Template registry (bash 3 compatible - no associative arrays)
TEMPLATE_NAMES="express nestjs fastify koa hapi hono adonisjs nextjs nuxt remix astro react vue svelte angular solid custom"

# Backend Templates

template_express() {
    echo "APP_TYPE=backend"
    echo "BACKEND_PORT=3000"
    echo "HEALTH_CHECK_PATH=/health"
    echo "BUILD_DIR=dist"
}

template_nestjs() {
    echo "APP_TYPE=backend"
    echo "BACKEND_PORT=3000"
    echo "HEALTH_CHECK_PATH=/api/health"
    echo "BUILD_DIR=dist"
}

template_fastify() {
    echo "APP_TYPE=backend"
    echo "BACKEND_PORT=3000"
    echo "HEALTH_CHECK_PATH=/health"
    echo "BUILD_DIR=dist"
}

template_koa() {
    echo "APP_TYPE=backend"
    echo "BACKEND_PORT=3000"
    echo "HEALTH_CHECK_PATH=/health"
    echo "BUILD_DIR=dist"
}

template_hapi() {
    echo "APP_TYPE=backend"
    echo "BACKEND_PORT=3000"
    echo "HEALTH_CHECK_PATH=/health"
    echo "BUILD_DIR=dist"
}

template_hono() {
    echo "APP_TYPE=backend"
    echo "BACKEND_PORT=3000"
    echo "HEALTH_CHECK_PATH=/health"
    echo "BUILD_DIR=dist"
}

template_adonisjs() {
    echo "APP_TYPE=backend"
    echo "BACKEND_PORT=3333"
    echo "HEALTH_CHECK_PATH=/health"
    echo "BUILD_DIR=build"
}

# Fullstack Templates

template_nextjs() {
    echo "APP_TYPE=backend"
    echo "BACKEND_PORT=3000"
    echo "HEALTH_CHECK_PATH=/api/health"
    echo "BUILD_DIR=.next"
}

template_nuxt() {
    echo "APP_TYPE=backend"
    echo "BACKEND_PORT=3000"
    echo "HEALTH_CHECK_PATH=/api/health"
    echo "BUILD_DIR=.output"
}

template_remix() {
    echo "APP_TYPE=backend"
    echo "BACKEND_PORT=3000"
    echo "HEALTH_CHECK_PATH=/healthcheck"
    echo "BUILD_DIR=build"
}

template_astro() {
    echo "APP_TYPE=backend"
    echo "BACKEND_PORT=4321"
    echo "HEALTH_CHECK_PATH=/api/health"
    echo "BUILD_DIR=dist"
}

# Frontend Templates

template_react() {
    echo "APP_TYPE=frontend"
    echo "BUILD_DIR=dist"
}

template_vue() {
    echo "APP_TYPE=frontend"
    echo "BUILD_DIR=dist"
}

template_svelte() {
    echo "APP_TYPE=frontend"
    echo "BUILD_DIR=dist"
}

template_angular() {
    echo "APP_TYPE=frontend"
    echo "BUILD_DIR=dist"
}

template_solid() {
    echo "APP_TYPE=frontend"
    echo "BUILD_DIR=dist"
}

template_custom() {
    echo "APP_TYPE=backend"
    echo "BACKEND_PORT=3000"
    echo "HEALTH_CHECK_PATH=/health"
    echo "BUILD_DIR=dist"
}

# Get template data
get_template() {
    local template_name="$1"

    # Check if template exists
    if ! echo "$TEMPLATE_NAMES" | grep -qw "$template_name"; then
        return 1
    fi

    # Call template function
    "template_${template_name}"
}

# List all available templates
list_templates() {
    cat << 'EOF'
Available templates:

Backend:
  express     - Express.js REST API (port 3000, /health)
  nestjs      - NestJS framework (port 3000, /api/health)
  fastify     - Fastify web framework (port 3000, /health)
  koa         - Koa.js framework (port 3000, /health)
  hapi        - Hapi.js framework (port 3000, /health)
  hono        - Hono web framework (port 3000, /health)
  adonisjs    - AdonisJS framework (port 3333, /health)

Fullstack:
  nextjs      - Next.js application (port 3000, /api/health)
  nuxt        - Nuxt.js application (port 3000, /api/health)
  remix       - Remix application (port 3000, /healthcheck)
  astro       - Astro with SSR (port 4321, /api/health)

Frontend:
  react       - React SPA (static)
  vue         - Vue.js SPA (static)
  svelte      - Svelte SPA (static)
  angular     - Angular SPA (static)
  solid       - SolidJS SPA (static)
  custom      - Custom configuration

Usage:
  shipnode init --template <name>

Example:
  shipnode init --template express
EOF
}
