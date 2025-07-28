#!/bin/bash

# Load environment variables safely
if [ -f .env.production ]; then
    echo "Loading environment variables from .env.production..."
    set -a  # automatically export all variables
    source .env.production
    set +a  # disable automatic export
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
