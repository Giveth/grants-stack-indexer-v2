#!/bin/bash

# Load user's PATH and environment
source ~/.bashrc 2>/dev/null || true
source ~/.zshrc 2>/dev/null || true

# Add common paths where pnpm might be installed
export PATH="$HOME/.local/share/pnpm:$PATH"
export PATH="/usr/local/bin:$PATH"
export PATH="$HOME/.npm-global/bin:$PATH"

# Load environment variables safely (skip problematic lines)
if [ -f .env.production ]; then
    echo "Loading environment variables from .env.production..."
    # Filter out lines that might cause issues (JSON arrays, complex values)
    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$line" ]] && continue
        # Skip lines with JSON arrays or complex structures
        [[ "$line" =~ \[.*\] ]] && continue
        # Export simple key=value pairs
        if [[ "$line" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; then
            export "$line"
        fi
    done < .env.production
fi

# Use SSL but don't verify certificates - works with DigitalOcean managed databases
# This accepts any SSL certificate without verification
export DATABASE_URL="postgresql://${DATALAYER_PG_USER}:${DATALAYER_PG_PASSWORD}@${DATALAYER_PG_HOST}:${DATALAYER_PG_PORT}/${DATALAYER_PG_DATABASE}?sslmode=require"

# Set PostgreSQL environment variables to avoid certificate file lookups
export PGSSLMODE=require
export PGSSLCERT=""
export PGSSLKEY=""
export PGSSLROOTCERT=""

# Temporarily disable SSL certificate verification for Node.js
export NODE_TLS_REJECT_UNAUTHORIZED=0

# Check if required environment variables are set
if [[ "${DATALAYER_PG_HOST}" == "your-datalayer-db-host.db.ondigitalocean.com" ]] || [[ -z "${DATALAYER_PG_HOST}" ]]; then
    echo "❌ Error: Environment variables not properly loaded from .env.production"
    echo "Please check that .env.production exists and contains real values (not placeholders)"
    exit 1
fi

# Check if pnpm is installed
echo "Checking for pnpm..."
if ! command -v pnpm &> /dev/null; then
    echo "❌ Error: pnpm is not found in PATH"
    echo "Current PATH: $PATH"
    echo "Please install pnpm or ensure it's in your PATH"
    echo "You can install it with: curl -fsSL https://get.pnpm.io/install.sh | sh -"
    exit 1
else
    echo "✅ Found pnpm: $(which pnpm)"
    echo "✅ pnpm version: $(pnpm --version)"
fi

echo "Running database migrations..."
echo "Database: ${DATALAYER_PG_HOST}:${DATALAYER_PG_PORT}/${DATALAYER_PG_DATABASE}"
echo "⚠️  SSL certificate verification is disabled"

# Step 1: Cache migrations
echo "Step 1: Running cache migrations..."
cd scripts/migrations

# Install dependencies if needed
if [ ! -d "node_modules" ]; then
    echo "Installing dependencies..."
    pnpm install
fi

# Run cache migrations
pnpm db:cache:migrate

# Step 2: Bootstrap
echo "Step 2: Running bootstrap..."
cd ../bootstrap

# Install dependencies if needed
if [ ! -d "node_modules" ]; then
    echo "Installing bootstrap dependencies..."
    pnpm install
fi

# Run bootstrap
pnpm bootstrap:all

# Step 3: Main database migrations
echo "Step 3: Running main database migrations..."
cd ../migrations

# Run main migrations
pnpm db:migrate

echo "All migrations completed successfully!"
