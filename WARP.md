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

## Resume Here

Status checklist (update as you progress):
- [x] Images pulled (XE, EE, GoldenGate, PostgreSQL, pgAdmin)
- [x] Containers running (oracle-ee-source, postgresql-target, gg-oracle-ee-extract, gg-postgresql-replicat, pgadmin)
- [x] PostgreSQL target schema created (replicated.employees, gguser)
- [ ] GoldenGate Extract (Oracle EE) configured (EXT_EE → trail EA)
- [ ] Distribution Path created (EA → RA → gg-postgresql)
- [ ] Receiver (PostgreSQL) + Replicat configured (REP_PG from RA)
- [ ] End-to-end test validated

Next actions:
1) Configure Extract on Oracle EE (UI http://localhost:9110) for ORCLPDB1 and table TESTUSER.EMPLOYEES → write local trail EA.
2) Create a Distribution Path from the EE deployment to the PostgreSQL deployment (target http://gg-postgresql:80) → remote trail RA.
3) Configure Replicat on PostgreSQL (UI http://localhost:9200) from remote trail RA → PostgreSQL targetdb, schema replicated.
4) Insert a test row in Oracle EE (ORCLPDB1) and verify it appears in PostgreSQL.

## GoldenGate Runbook (Oracle EE → PostgreSQL)

Services and URLs
- GoldenGate Oracle EE (Extract): http://localhost:9110
- GoldenGate PostgreSQL (Replicat): http://localhost:9200
- pgAdmin: http://localhost:8080

Source and target databases
- Oracle EE PDB: ORCLPDB1 (users: ggadmin, testuser; SYS: sys/Oracle123!)
- PostgreSQL: host postgresql, db targetdb (users: postgres, gguser)

1) Prepare Oracle EE (ORCLPDB1)
- Ensure:
  - ggadmin and testuser exist in ORCLPDB1
  - Supplemental logging enabled at DB and table level
  - Table TESTUSER.EMPLOYEES exists with supplemental logging
- Tip: Use an EE-focused setup script or run SQL as SYSDBA against ORCLPDB1.

2) Configure Extract (Oracle EE deployment — 9110)
- Security → Credentials: add alias ORA_SRC_EE (ggadmin / Oracle).
- Configuration → Add Extract:
  - Name: EXT_EE
  - Type: Integrated Extract
  - Database/container: ORCLPDB1
  - Credential alias: ORA_SRC_EE
  - Local trail: EA
  - Objects: include TESTUSER.EMPLOYEES
- Start EXT_EE and confirm it writes to dirdat/ea.

3) Create Distribution Path (EE → PostgreSQL)
- Distribution Server → Paths → Add:
  - Name: to_pg
  - Source: local trail EA
  - Target: http://gg-postgresql:80
  - Target auth: oggadmin / Oracle123! (default)
  - Remote trail: RA
- Start the path; status should be Running.

4) Configure Receiver + Replicat (PostgreSQL deployment — 9200)
- Receiver Server: ensure inbound receiver is running (will create trail RA).
- Security → Credentials: add alias PG_TGT (gguser).
- Configuration → Add Replicat:
  - Name: REP_PG
  - Type: Non-Integrated
  - Source: remote trail RA
  - Target: JDBC → jdbc:postgresql://postgresql:5432/targetdb
  - Credential alias: PG_TGT
  - Mapping: TESTUSER.EMPLOYEES → replicated.employees (1:1 columns)
- Start REP_PG; verify Checkpoints advance.

5) Test replication
- Insert into Oracle EE (ORCLPDB1) as TESTUSER, then verify in PostgreSQL:
  - Oracle: INSERT INTO employees (id, name, department, salary, email) VALUES (...);
  - Postgres: SELECT id, name FROM replicated.employees WHERE id = ...;
- Expect new row to appear within a few seconds.

Troubleshooting
- No rows in Postgres:
  - Check Extract is RUNNING and writing to EA.
  - Ensure Distribution Path to_pg is RUNNING (not Paused) and delivering to RA.
  - Verify Replicat REP_PG is RUNNING and has no mapping errors.
- Object/schema mismatches:
  - Confirm ORCLPDB1 vs CDB and table name/schema.
  - Confirm column names and datatypes match.
- Credentials:
  - Add DB credentials in each deployment’s Credential Store before creating groups.

Persistence and restart
- Containers and data persist via Docker volumes.
- To resume after reboot: `docker-compose up -d`, then open 9110 and 9200.
