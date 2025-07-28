#!/bin/bash

# Load environment variables
if [ -f .env.production ]; then
    export $(cat .env.production | grep -v '^#' | xargs)
fi

# Download DigitalOcean CA certificate if it doesn't exist
if [ ! -f "ca-certificate.crt" ]; then
    echo "Downloading DigitalOcean CA certificate..."
    curl -o ca-certificate.crt https://raw.githubusercontent.com/digitalocean/certificate-authority/master/certs/ca-certificate.crt
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
