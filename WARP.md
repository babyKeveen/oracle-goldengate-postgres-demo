# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Project Overview

This is an Oracle GoldenGate to PostgreSQL demo project that demonstrates real-time data replication using Docker containers. The project includes:

- **Oracle XE 21c** as the source database
- **PostgreSQL 15** as the target database  
- **Oracle GoldenGate** for real-time data replication (Extract and Replicat)
- **pgAdmin** for PostgreSQL management

## Essential Commands

### Environment Setup
```bash
# Quick start (recommended for new users)
./quick-start.sh

# Manual start - brings up all services
docker-compose up -d

# Monitor startup logs (services take 10-15 minutes to be healthy)
docker-compose logs -f

# Check service health status
docker-compose ps
```

### Database Access
```bash
# Oracle XE access (as SYSDBA)
docker exec -it oracle-xe-source sqlplus sys/Oracle123!@XE as sysdba

# Oracle XE access (connect to PDB for replication setup)
docker exec -it oracle-xe-source sqlplus sys/Oracle123!@XEPDB1 as sysdba

# PostgreSQL access
docker exec -it postgresql-target psql -U postgres -d targetdb

# Access as GoldenGate user in PostgreSQL
docker exec -it postgresql-target psql -U gguser -d targetdb
```

### Initial Database Setup
```bash
# Setup Oracle for GoldenGate (creates users, enables supplemental logging)
docker exec -i oracle-xe-source sqlplus /nolog < scripts/oracle/01_setup_goldengate_user.sql

# Setup PostgreSQL target schema
docker exec -i postgresql-target psql -U postgres < scripts/postgresql/01_setup_target_schema.sql
```

### Development and Testing
```bash
# Check replication status by comparing data
docker exec -it oracle-xe-source sqlplus testuser/\"Test123!\"/XEPDB1 -S <<< "SELECT COUNT(*) FROM employees;"
docker exec -it postgresql-target psql -U postgres -d targetdb -c "SELECT COUNT(*) FROM replicated.employees;"

# Insert test data into Oracle (to verify replication)
docker exec -it oracle-xe-source sqlplus testuser/\"Test123!\"/XEPDB1 <<< "INSERT INTO employees VALUES (4, 'Test User', 'Engineering', 80000, SYSDATE, 'test@company.com', 'ACTIVE'); COMMIT;"

# Clean restart (removes all data)
docker-compose down -v
docker-compose up -d
```

### Troubleshooting
```bash
# View logs for specific services
docker-compose logs oracle-xe
docker-compose logs postgresql
docker-compose logs goldengate-oracle
docker-compose logs goldengate-postgresql

# Check container resource usage
docker stats

# Restart specific service
docker-compose restart oracle-xe
docker-compose restart postgresql
```

## Architecture Overview

### Container Network (172.20.0.0/16)
- **oracle-xe**: Oracle XE database (ports 1521, 5500)
- **postgresql**: PostgreSQL target (port 5432)
- **gg-oracle-extract**: GoldenGate extract process (ports 9100, 9011)
- **gg-postgresql-replicat**: GoldenGate replicat process (ports 9200, 9021)
- **pgadmin**: PostgreSQL web admin (port 8080)

### Data Flow
```
Oracle XE (testuser.employees) → GoldenGate Extract → GoldenGate Replicat → PostgreSQL (replicated.employees)
```

### Key Configuration Points
- Oracle uses **CDB/PDB architecture** - replication works with XEPDB1 (not XE directly)
- **Supplemental logging** must be enabled in Oracle for GoldenGate to capture changes
- PostgreSQL target uses **replicated schema** to separate replicated data
- All services have health checks and proper startup dependencies

### File Structure
```
├── docker-compose.yml          # Main orchestration (5 services)
├── quick-start.sh             # Automated setup script
├── scripts/
│   ├── oracle/               # Oracle initialization SQL
│   └── postgresql/           # PostgreSQL setup SQL
├── configs/                  # GoldenGate parameter files (when added)
├── data/                     # Persistent volumes (gitignored)
└── logs/                     # Container logs (gitignored)
```

## Default Credentials

| Service | Username | Password | Database/URL |
|---------|----------|----------|--------------|
| Oracle XE | sys | Oracle123! | XE (CDB), XEPDB1 (PDB) |
| Oracle Test User | testuser | Test123! | XEPDB1 |
| PostgreSQL | postgres | Postgres123! | targetdb |
| PostgreSQL GG User | gguser | Oracle123! | targetdb |
| GoldenGate Admin | oggadmin | Oracle123! | Web UI |
| pgAdmin | admin@example.com | admin123 | http://localhost:8080 |

## Web Interfaces

- **pgAdmin**: http://localhost:8080 (PostgreSQL management)
- **GoldenGate Oracle**: http://localhost:9100 (Extract configuration)
- **GoldenGate PostgreSQL**: http://localhost:9200 (Replicat configuration)

## Prerequisites

1. **Oracle Container Registry Access**: Must login to `container-registry.oracle.com` and accept licenses for Database Express and GoldenGate
2. **Docker Desktop**: At least 8GB RAM allocated
3. **Ports Available**: 1521, 5432, 5500, 8080, 9100, 9200, 9011, 9021

## Project Status

This is a **learning/demo project** in active development:
- ✅ Container orchestration and basic connectivity
- ⏳ GoldenGate configuration and replication setup
- 🔄 Advanced features like schema mapping and conflict resolution planned

When working with this project, focus on the Docker-based architecture and understand that the Oracle database uses a pluggable database (XEPDB1) rather than the container database (XE) directly for replication.