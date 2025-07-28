#!/bin/bash

# Load user's PATH and environment
source ~/.bashrc 2>/dev/null || true
source ~/.zshrc 2>/dev/null || true

# Add common paths where psql might be installed
export PATH="/usr/local/bin:$PATH"
export PATH="/opt/homebrew/bin:$PATH"
export PATH="/usr/bin:$PATH"

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

# Check if dump file is provided
if [ -z "$1" ]; then
    echo "❌ Error: No dump file specified"
    echo "Usage: $0 <path-to-dump-file.sql>"
    echo "Example: $0 ./backup/indexer-dump-2024-01-15.sql"
    exit 1
fi

DUMP_FILE="$1"

# Check if dump file exists
if [ ! -f "$DUMP_FILE" ]; then
    echo "❌ Error: Dump file not found: $DUMP_FILE"
    exit 1
fi

# Use SSL but don't verify certificates - works with DigitalOcean managed databases
# This targets the INDEXER database (ENVIO_* variables)
export INDEXER_DATABASE_URL="postgresql://${ENVIO_PG_USER}:${ENVIO_PG_PASSWORD}@${ENVIO_PG_HOST}:${ENVIO_PG_PORT}/${ENVIO_PG_DATABASE}?sslmode=require"

# Set PostgreSQL environment variables to avoid certificate file lookups
export PGSSLMODE=require
export PGSSLCERT=""
export PGSSLKEY=""
export PGSSLROOTCERT=""

# Temporarily disable SSL certificate verification for Node.js
export NODE_TLS_REJECT_UNAUTHORIZED=0

# Check if required environment variables are set
if [[ "${ENVIO_PG_HOST}" == "your-indexer-db-host.db.ondigitalocean.com" ]] || [[ -z "${ENVIO_PG_HOST}" ]]; then
    echo "❌ Error: Indexer database environment variables not properly loaded from .env.production"
    echo "Please check that .env.production exists and contains real ENVIO_* values (not placeholders)"
    exit 1
fi

# Determine file type and required tool
FILE_EXT="${DUMP_FILE##*.}"
if [[ "$FILE_EXT" == "dump" ]]; then
    RESTORE_TOOL="pg_restore"
    RESTORE_CMD="pg_restore"
    echo "📄 Detected PostgreSQL custom format dump (.dump)"
else
    RESTORE_TOOL="psql"
    RESTORE_CMD="psql"
    echo "📄 Detected SQL text dump (.sql)"
fi

# Check if required tool is installed
echo "Checking for $RESTORE_TOOL..."
if ! command -v "$RESTORE_TOOL" &> /dev/null; then
    echo "❌ Error: $RESTORE_TOOL is not found in PATH"
    echo "Current PATH: $PATH"
    echo "Please install PostgreSQL client tools"
    echo "On macOS: brew install postgresql"
    echo "On Ubuntu/Debian: sudo apt-get install postgresql-client"
    exit 1
else
    echo "✅ Found $RESTORE_TOOL: $(which "$RESTORE_TOOL")"
    if [[ "$RESTORE_TOOL" == "psql" ]]; then
        echo "✅ psql version: $(psql --version)"
    else
        echo "✅ pg_restore version: $(pg_restore --version)"
    fi
fi

echo ""
echo "🗄️  Database Dump Upload"
echo "========================"
echo "Source file: $DUMP_FILE"
echo "Target database: ${ENVIO_PG_HOST}:${ENVIO_PG_PORT}/${ENVIO_PG_DATABASE}"
echo "File size: $(du -h "$DUMP_FILE" | cut -f1)"
echo "⚠️  SSL certificate verification is disabled"
echo ""

# Confirm before proceeding
read -p "⚠️  This will OVERWRITE the existing indexer database. Are you sure? (yes/no): " -r
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "❌ Upload cancelled"
    exit 1
fi

echo ""
echo "🔄 Starting database dump upload..."

# Create a backup of current database first
BACKUP_FILE="backup-before-upload-$(date +%Y%m%d-%H%M%S).sql"
echo "📦 Creating backup of current database: $BACKUP_FILE"

pg_dump "$INDEXER_DATABASE_URL" > "$BACKUP_FILE" 2>/dev/null
if [ $? -eq 0 ]; then
    echo "✅ Backup created successfully: $BACKUP_FILE"
else
    echo "⚠️  Warning: Could not create backup (database might be empty)"
fi

echo ""
echo "🗑️  Dropping existing database objects..."

# Drop all tables, views, functions, etc. (clean slate)
psql "$INDEXER_DATABASE_URL" -c "
DROP SCHEMA IF EXISTS public CASCADE;
CREATE SCHEMA public;
GRANT ALL ON SCHEMA public TO ${ENVIO_PG_USER};
GRANT ALL ON SCHEMA public TO public;
" 2>/dev/null

if [ $? -eq 0 ]; then
    echo "✅ Database cleaned successfully"
else
    echo "❌ Error: Failed to clean database"
    exit 1
fi

echo ""
echo "📥 Uploading dump file..."

# Upload the dump using appropriate tool
if [[ "$FILE_EXT" == "dump" ]]; then
    # Use pg_restore for custom format dumps
    pg_restore --verbose --clean --no-acl --no-owner -d "$INDEXER_DATABASE_URL" "$DUMP_FILE"
else
    # Use psql for SQL text dumps
    psql "$INDEXER_DATABASE_URL" < "$DUMP_FILE"
fi

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Database dump uploaded successfully!"
    echo ""
    echo "📊 Database summary:"
    psql "$INDEXER_DATABASE_URL" -c "
    SELECT 
        schemaname,
        tablename,
        pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
    FROM pg_tables 
    WHERE schemaname = 'public' 
    ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC 
    LIMIT 10;
    "
    
    echo ""
    echo "🎉 Upload completed successfully!"
    echo "📦 Backup of previous database saved as: $BACKUP_FILE"
else
    echo ""
    echo "❌ Error: Failed to upload database dump"
    echo "💡 You can restore the backup with:"
    echo "   psql \"$INDEXER_DATABASE_URL\" < \"$BACKUP_FILE\""
    exit 1
fi
