#!/bin/bash

# Quick Start Script for Oracle GoldenGate to PostgreSQL Demo
# This script helps you get started quickly with the project

set -e

echo "🚀 Oracle GoldenGate to PostgreSQL Demo - Quick Start"
echo "=================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if Docker is running
echo -e "${BLUE}Checking Docker status...${NC}"
if ! docker info >/dev/null 2>&1; then
    echo -e "${RED}❌ Docker is not running. Please start Docker Desktop and try again.${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Docker is running${NC}"

# Check if Docker Compose is available
if ! command -v docker-compose >/dev/null 2>&1; then
    echo -e "${RED}❌ Docker Compose is not installed or not in PATH${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Docker Compose is available${NC}"

# Check Oracle Container Registry login
echo -e "${BLUE}Checking Oracle Container Registry access...${NC}"
if ! docker pull container-registry.oracle.com/database/express:21.3.0-xe --quiet >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  Oracle Container Registry login required${NC}"
    echo "Please run: docker login container-registry.oracle.com"
    echo "You'll need to:"
    echo "1. Create an Oracle account at https://container-registry.oracle.com"
    echo "2. Accept license agreements for Database Express and GoldenGate"
    echo "3. Login with your Oracle credentials"
    exit 1
fi
echo -e "${GREEN}✅ Oracle Container Registry access confirmed${NC}"

# Create .env file if it doesn't exist
if [ ! -f ".env" ]; then
    echo -e "${BLUE}Creating .env file from template...${NC}"
    cp .env.template .env
    echo -e "${GREEN}✅ Created .env file${NC}"
else
    echo -e "${GREEN}✅ .env file already exists${NC}"
fi

# Check available memory
echo -e "${BLUE}Checking system resources...${NC}"
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    MEMORY_GB=$(( $(sysctl -n hw.memsize) / 1024 / 1024 / 1024 ))
    if [ $MEMORY_GB -lt 8 ]; then
        echo -e "${YELLOW}⚠️  Warning: Less than 8GB RAM detected. Performance may be impacted.${NC}"
    else
        echo -e "${GREEN}✅ Sufficient memory available (${MEMORY_GB}GB)${NC}"
    fi
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux
    MEMORY_GB=$(( $(grep MemTotal /proc/meminfo | awk '{print $2}') / 1024 / 1024 ))
    if [ $MEMORY_GB -lt 8 ]; then
        echo -e "${YELLOW}⚠️  Warning: Less than 8GB RAM detected. Performance may be impacted.${NC}"
    else
        echo -e "${GREEN}✅ Sufficient memory available (${MEMORY_GB}GB)${NC}"
    fi
fi

echo ""
echo -e "${BLUE}Starting the environment...${NC}"
echo "This may take 10-15 minutes on first run while images are downloaded."
echo ""

# Start services
docker-compose up -d

echo ""
echo -e "${YELLOW}Waiting for services to become healthy...${NC}"
echo "This can take a few minutes..."

# Wait for services to be healthy
MAX_WAIT=600  # 10 minutes
WAIT_TIME=0
while [ $WAIT_TIME -lt $MAX_WAIT ]; do
    ORACLE_STATUS=$(docker inspect oracle-xe-source --format='{{.State.Health.Status}}' 2>/dev/null || echo "starting")
    POSTGRES_STATUS=$(docker inspect postgresql-target --format='{{.State.Health.Status}}' 2>/dev/null || echo "starting")
    
    if [ "$ORACLE_STATUS" = "healthy" ] && [ "$POSTGRES_STATUS" = "healthy" ]; then
        echo -e "${GREEN}✅ All services are healthy!${NC}"
        break
    fi
    
    echo "Oracle: $ORACLE_STATUS, PostgreSQL: $POSTGRES_STATUS (${WAIT_TIME}s elapsed)"
    sleep 10
    WAIT_TIME=$((WAIT_TIME + 10))
done

if [ $WAIT_TIME -ge $MAX_WAIT ]; then
    echo -e "${RED}❌ Services did not become healthy within 10 minutes${NC}"
    echo "Check the logs: docker-compose logs"
    exit 1
fi

echo ""
echo -e "${GREEN}🎉 Environment is ready!${NC}"
echo ""
echo "Access Information:"
echo "=================="
echo -e "🔹 Oracle XE SQL*Plus:     ${BLUE}docker exec -it oracle-xe-source sqlplus sys/Oracle123!@XE as sysdba${NC}"
echo -e "🔹 PostgreSQL:             ${BLUE}docker exec -it postgresql-target psql -U postgres -d targetdb${NC}"
echo -e "🔹 pgAdmin:                 ${BLUE}http://localhost:8080${NC} (admin@example.com / admin123)"
echo -e "🔹 GoldenGate Oracle:       ${BLUE}http://localhost:9100${NC} (oggadmin / Oracle123!)"
echo -e "🔹 GoldenGate PostgreSQL:   ${BLUE}http://localhost:9200${NC} (oggadmin / Oracle123!)"
echo ""
echo "Next Steps:"
echo "=========="
echo "1. Run Oracle setup script:"
echo "   docker exec -i oracle-xe-source sqlplus /nolog < scripts/oracle/01_setup_goldengate_user.sql"
echo ""
echo "2. Run PostgreSQL setup script:"
echo "   docker exec -i postgresql-target psql -U postgres < scripts/postgresql/01_setup_target_schema.sql"
echo ""
echo "3. Configure GoldenGate replication (see README.md for details)"
echo ""
echo -e "${GREEN}Happy Learning! 🚀${NC}"