# DigitalOcean Deployment Guide

This guide will help you deploy the Grants Stack Indexer v2 to a single DigitalOcean droplet with managed databases.

## 🏗️ Architecture Overview

### Simplified Architecture
- **Single DigitalOcean Droplet** running all application containers
- **Two DigitalOcean Managed Databases** (PostgreSQL)
- **Caddy** as reverse proxy with automatic HTTPS
- **Docker Compose** for container orchestration

### Services
1. **Caddy** - Reverse proxy with automatic SSL/TLS
2. **Processing Service** - Main application logic
3. **Datalayer GraphQL API** - Hasura instance for main data
4. **Indexer GraphQL API** - Hasura instance for blockchain data
5. **Indexer Service** - Blockchain event indexer

## 🚀 Prerequisites

### DigitalOcean Resources
1. **Droplet**: 4GB RAM, 2 vCPUs minimum (recommended: 8GB RAM, 4 vCPUs)
2. **Two Managed PostgreSQL Databases**:
   - Datalayer Database (for application data)
   - Indexer Database (for blockchain events)
3. **Domain name** pointed to your droplet's IP

### Required Software on Droplet
- Docker & Docker Compose
- Git
- UFW (firewall)

## 📋 Step-by-Step Deployment

### 1. Prepare DigitalOcean Infrastructure

#### Create Droplet
```bash
# Create a droplet with Docker pre-installed
# Choose: Ubuntu 22.04 LTS with Docker
# Size: 4GB RAM, 2 vCPUs (minimum)
# Add your SSH key
```

#### Create Managed Databases
```bash
# Create two PostgreSQL databases:
# 1. datalayer-db (for application data)
# 2. indexer-db (for blockchain events)
# 
# Note the connection details:
# - Host
# - Port (usually 25060)
# - Username (usually doadmin)
# - Password
# - Database name
```

#### Configure DNS
```bash
# Point your domain to the droplet IP:
# A record: your-domain.com -> droplet-ip
# A record: indexer.your-domain.com -> droplet-ip
# A record: admin.your-domain.com -> droplet-ip
```

### 2. Server Setup

#### Connect to your droplet
```bash
ssh root@your-droplet-ip
```

#### Install additional dependencies
```bash
# Update system
apt update && apt upgrade -y

# Install git if not present
apt install -y git curl

# Verify Docker installation
docker --version
docker-compose --version
```

#### Configure firewall
```bash
# The deployment script will handle this, but you can do it manually:
ufw enable
ufw allow ssh
ufw allow 80/tcp
ufw allow 443/tcp
ufw default deny incoming
ufw default allow outgoing
```

### 3. Deploy Application

#### Clone repository
```bash
git clone https://github.com/your-org/grants-stack-indexer-v2.git
cd grants-stack-indexer-v2
```

#### Configure environment
```bash
# Copy production environment template
cp .env.production .env

# Edit the environment file
nano .env
```

#### Required Environment Variables
Update these in your `.env` file:

```bash
# Domain configuration
DOMAIN=your-domain.com
EMAIL=your-email@domain.com
ADMIN_IPS=your.admin.ip.address

# Datalayer database (from DigitalOcean)
DATALAYER_PG_HOST=your-datalayer-db-host.db.ondigitalocean.com
DATALAYER_PG_PORT=25060
DATALAYER_PG_USER=doadmin
DATALAYER_PG_PASSWORD=your-secure-password
DATALAYER_PG_DATABASE=datalayer

# Indexer database (from DigitalOcean)
ENVIO_PG_HOST=your-indexer-db-host.db.ondigitalocean.com
ENVIO_PG_PORT=25060
ENVIO_PG_USER=doadmin
ENVIO_PG_PASSWORD=your-secure-password
ENVIO_PG_DATABASE=indexer

# Security
DATALAYER_HASURA_ADMIN_SECRET=your-super-secure-admin-secret
HASURA_GRAPHQL_ADMIN_SECRET=your-super-secure-admin-secret

# External APIs
COINGECKO_API_KEY=your-coingecko-api-key
```

#### Deploy
```bash
# Make deployment script executable (already done)
chmod +x deploy-digitalocean.sh

# Run deployment
./deploy-digitalocean.sh deploy
```

### 4. Initialize Databases

After deployment, you need to set up the database schemas:

```bash
# Install dependencies and build
pnpm install && pnpm build

# Set up environment files for scripts
cp scripts/bootstrap/.env.example scripts/bootstrap/.env
cp scripts/migrations/.env.example scripts/migrations/.env
cp scripts/hasura-config/.env.example scripts/hasura-config/.env

# Edit these files with your production database URLs
# Then run migrations and bootstrap
pnpm db:cache:migrate
pnpm bootstrap:all
pnpm db:migrate
```

## 🔧 Management Commands

### Deployment Script Usage
```bash
# Full deployment
./deploy-digitalocean.sh deploy

# Check status
./deploy-digitalocean.sh status

# View logs
./deploy-digitalocean.sh logs [service-name]

# Restart services
./deploy-digitalocean.sh restart [service-name]

# Update deployment
./deploy-digitalocean.sh update

# Stop all services
./deploy-digitalocean.sh stop
```

### Docker Compose Commands
```bash
# View running containers
docker-compose -f docker-compose.production.yml ps

# View logs
docker-compose -f docker-compose.production.yml logs -f

# Restart specific service
docker-compose -f docker-compose.production.yml restart processing

# Scale services (if needed)
docker-compose -f docker-compose.production.yml up -d --scale processing=2
```

## 🌐 API Endpoints

After deployment, your APIs will be available at:

- **Main API**: `https://your-domain.com/v1/graphql`
- **Indexer API**: `https://indexer.your-domain.com/v1/graphql`
- **Admin Interface**: `https://admin.your-domain.com/` (IP restricted)
- **Health Check**: `https://your-domain.com/health`

## 🔍 Monitoring & Troubleshooting

### Health Checks
```bash
# Check if all services are running
curl https://your-domain.com/health

# Check specific service health
docker-compose -f docker-compose.production.yml ps
```

### Log Analysis
```bash
# View all logs
./deploy-digitalocean.sh logs

# View specific service logs
./deploy-digitalocean.sh logs processing
./deploy-digitalocean.sh logs caddy

# Follow logs in real-time
docker-compose -f docker-compose.production.yml logs -f processing
```

### Common Issues

#### SSL Certificate Issues
```bash
# Check Caddy logs
docker-compose -f docker-compose.production.yml logs caddy

# Restart Caddy
docker-compose -f docker-compose.production.yml restart caddy
```

#### Database Connection Issues
```bash
# Test database connectivity
docker-compose -f docker-compose.production.yml exec processing \
  psql "postgresql://user:pass@host:port/db" -c "SELECT 1;"
```

#### Service Not Starting
```bash
# Check service logs
docker-compose -f docker-compose.production.yml logs [service-name]

# Restart specific service
docker-compose -f docker-compose.production.yml restart [service-name]
```

## 🔒 Security Considerations

### Firewall
- Only ports 22 (SSH), 80 (HTTP), and 443 (HTTPS) are open
- Admin interface is IP-restricted

### Database Security
- Use DigitalOcean managed databases with SSL
- Strong passwords for all database users
- Regular backups enabled

### Application Security
- HTTPS enforced for all traffic
- Strong admin secrets for Hasura
- CORS properly configured
- Security headers enabled

### Backup Strategy
- DigitalOcean managed database backups
- Regular droplet snapshots
- Configuration files backed up

## 📊 Performance Optimization

### Resource Monitoring
```bash
# Monitor resource usage
docker stats

# Check disk usage
df -h

# Monitor memory usage
free -h
```

### Scaling Options
1. **Vertical Scaling**: Resize droplet for more CPU/RAM
2. **Database Scaling**: Upgrade managed database plan
3. **Horizontal Scaling**: Add load balancer + multiple droplets

## 🔄 Updates & Maintenance

### Application Updates
```bash
# Pull latest code
git pull origin main

# Update deployment
./deploy-digitalocean.sh update
```

### System Updates
```bash
# Update system packages
apt update && apt upgrade -y

# Update Docker images
docker-compose -f docker-compose.production.yml pull
```

### Database Maintenance
- Regular backups are handled by DigitalOcean
- Monitor database performance in DO dashboard
- Scale database resources as needed

## 💰 Cost Estimation

### Monthly Costs (approximate)
- **Droplet (4GB)**: $24/month
- **Managed DB (2x Basic)**: $30/month each = $60/month
- **Total**: ~$84/month

### Cost Optimization
- Use smaller droplet for staging
- Single database for development
- Regular monitoring to avoid over-provisioning
