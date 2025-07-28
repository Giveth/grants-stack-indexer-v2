#!/bin/bash

# Load environment variables
if [ -f .env.production ]; then
    export $(cat .env.production | grep -v '^#' | xargs)
fi

# Use sslmode=require but disable certificate verification
# This is less secure but works with DigitalOcean's managed databases
export DATABASE_URL="postgresql://${DATALAYER_PG_USER}:${DATALAYER_PG_PASSWORD}@${DATALAYER_PG_HOST}:${DATALAYER_PG_PORT}/${DATALAYER_PG_DATABASE}?sslmode=require"

# Temporarily disable SSL certificate verification for Node.js
export NODE_TLS_REJECT_UNAUTHORIZED=0

echo "Running database migrations..."
echo "Database: ${DATALAYER_PG_HOST}:${DATALAYER_PG_PORT}/${DATALAYER_PG_DATABASE}"
echo "⚠️  SSL certificate verification is disabled"

cd scripts/migrations

# Install dependencies if needed
if [ ! -d "node_modules" ]; then
    echo "Installing dependencies..."
    pnpm install
fi

# Run migrations
pnpm db:migrate

echo "Migrations completed!"
