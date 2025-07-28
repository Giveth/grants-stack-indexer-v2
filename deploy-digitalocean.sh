#!/bin/bash

# DigitalOcean Deployment Script for Grants Stack Indexer v2
# This script helps deploy the application to a single DigitalOcean droplet

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
COMPOSE_FILE="docker compose.production.yml"
ENV_FILE=".env"

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_requirements() {
    log_info "Checking requirements..."
    
    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please install Docker first."
        exit 1
    fi

    # Check if .env file exists
    if [ ! -f "$ENV_FILE" ]; then
        log_error ".env file not found. Please copy .env.production to .env and configure it."
        exit 1
    fi
    
    # Check if Caddyfile exists
    if [ ! -f "Caddyfile" ]; then
        log_error "Caddyfile not found. Please ensure Caddyfile is in the project root."
        exit 1
    fi
    
    log_success "All requirements met!"
}

setup_firewall() {
    log_info "Setting up firewall rules..."
    
    # Enable UFW if not already enabled
    if ! ufw status | grep -q "Status: active"; then
        log_info "Enabling UFW firewall..."
        ufw --force enable
    fi
    
    # Allow SSH (important!)
    ufw allow ssh
    
    # Allow HTTP and HTTPS
    ufw allow 80/tcp
    ufw allow 443/tcp
    
    # Deny all other incoming traffic by default
    ufw --force default deny incoming
    ufw --force default allow outgoing
    
    log_success "Firewall configured!"
}

build_and_deploy() {
    log_info "Building and deploying application..."
    
    # Pull latest images
    log_info "Pulling latest Docker images..."
    docker compose -f $COMPOSE_FILE pull
    
    # Build custom images
    log_info "Building custom application images..."
    docker compose -f $COMPOSE_FILE build --no-cache
    
    # Stop existing containers
    log_info "Stopping existing containers..."
    docker compose -f $COMPOSE_FILE down
    
    # Start services
    log_info "Starting services..."
    docker compose -f $COMPOSE_FILE up -d
    
    log_success "Application deployed!"
}

check_health() {
    log_info "Checking service health..."
    
    # Wait for services to start
    sleep 30
    
    # Check if containers are running
    if docker compose -f $COMPOSE_FILE ps | grep -q "Up"; then
        log_success "Containers are running!"
    else
        log_error "Some containers failed to start. Check logs with: docker compose -f $COMPOSE_FILE logs"
        exit 1
    fi
    
    # Check Caddy health
    if curl -f http://localhost/health &> /dev/null; then
        log_success "Caddy is responding!"
    else
        log_warning "Caddy health check failed. It might still be starting up."
    fi
}

show_status() {
    log_info "Current deployment status:"
    echo ""
    docker compose -f $COMPOSE_FILE ps
    echo ""
    log_info "To view logs: docker compose -f $COMPOSE_FILE logs -f [service_name]"
    log_info "To restart: docker compose -f $COMPOSE_FILE restart [service_name]"
    log_info "To stop all: docker compose -f $COMPOSE_FILE down"
}

# Main execution
case "${1:-deploy}" in
    "deploy")
        log_info "Starting DigitalOcean deployment..."
        check_requirements
        setup_firewall
        build_and_deploy
        check_health
        show_status
        log_success "Deployment completed successfully!"
        ;;
    "status")
        show_status
        ;;
    "logs")
        docker compose -f $COMPOSE_FILE logs -f "${2:-}"
        ;;
    "restart")
        log_info "Restarting services..."
        docker compose -f $COMPOSE_FILE restart "${2:-}"
        log_success "Services restarted!"
        ;;
    "stop")
        log_info "Stopping all services..."
        docker compose -f $COMPOSE_FILE down
        log_success "All services stopped!"
        ;;
    "update")
        log_info "Updating deployment..."
        docker compose -f $COMPOSE_FILE pull
        docker compose -f $COMPOSE_FILE build --no-cache
        docker compose -f $COMPOSE_FILE up -d
        check_health
        log_success "Update completed!"
        ;;
    *)
        echo "Usage: $0 {deploy|status|logs|restart|stop|update}"
        echo ""
        echo "Commands:"
        echo "  deploy  - Full deployment (default)"
        echo "  status  - Show current status"
        echo "  logs    - Show logs (optionally specify service name)"
        echo "  restart - Restart services (optionally specify service name)"
        echo "  stop    - Stop all services"
        echo "  update  - Update and restart services"
        exit 1
        ;;
esac
