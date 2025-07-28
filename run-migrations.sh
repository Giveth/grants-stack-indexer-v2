#!/bin/bash

# Load environment variables
if [ -f .env.production ]; then
    export $(cat .env.production | grep -v '^#' | xargs)
fi

# Check if CA certificate exists
if [ ! -f "ca-certificate.crt" ]; then
    echo "❌ Error: ca-certificate.crt not found"
    echo "Please ensure the DigitalOcean CA certificate is available as ca-certificate.crt"
    exit 1
fi

# Construct DATABASE_URL with proper SSL configuration for DigitalOcean
export DATABASE_URL="postgresql://${DATALAYER_PG_USER}:${DATALAYER_PG_PASSWORD}@${DATALAYER_PG_HOST}:${DATALAYER_PG_PORT}/${DATALAYER_PG_DATABASE}?sslmode=require&sslrootcert=ca-certificate.crt"

echo "Running database migrations..."
echo "Database: ${DATALAYER_PG_HOST}:${DATALAYER_PG_PORT}/${DATALAYER_PG_DATABASE}"

cd scripts/migrations

# Install dependencies if needed
if [ ! -d "node_modules" ]; then
    echo "Installing dependencies..."
    pnpm install
fi

# Run migrations
pnpm db:migrate

echo "Migrations completed!"
