# Oracle GoldenGate to PostgreSQL Demo

A comprehensive learning project demonstrating real-time data replication from Oracle Database to PostgreSQL using Oracle GoldenGate, all running in Docker containers.

## 🎯 Learning Objectives

This project is designed to help you learn:

- **Oracle GoldenGate**: Real-time data replication and change data capture (CDC)
- **PostgreSQL**: Modern open-source relational database management
- **Docker & Docker Compose**: Container orchestration and microservices
- **Database Migration**: Cross-platform data movement strategies
- **DevOps Practices**: Infrastructure as code, version control for database projects

## 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Oracle XE     │────│  GoldenGate     │────│  PostgreSQL     │
│   (Source)      │    │  Extract &      │    │   (Target)      │
│                 │    │  Replicat       │    │                 │
│   Port: 1521    │    │  Ports:         │    │   Port: 5432    │
│   Web: 5500     │    │  9100, 9200     │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### Components

1. **Oracle XE 21c**: Source database running in container
2. **GoldenGate Extract**: Captures changes from Oracle
3. **GoldenGate Replicat**: Applies changes to PostgreSQL
4. **PostgreSQL 15**: Target database
5. **pgAdmin**: Web-based PostgreSQL administration (optional)

## 🚀 Quick Start

### Prerequisites

1. **Docker Desktop** installed and running
2. **Oracle Account** for accessing Oracle container images
3. **Git** for version control
4. At least **8GB RAM** available for containers

### Oracle Container Registry Access

You'll need to accept the license agreements for Oracle images:

1. Go to [container-registry.oracle.com](https://container-registry.oracle.com)
2. Sign in with your Oracle account
3. Navigate to **Database** → **Express** and accept the license
4. Navigate to **Middleware** → **GoldenGate** and accept the license
5. Login to the registry from your terminal:

```bash
docker login container-registry.oracle.com
```

### Setup Instructions

1. **Clone the repository**:
   ```bash
   git clone <your-repo-url>
   cd oracle-goldengate-postgres-demo
   ```

2. **Start the environment**:
   ```bash
   # Start all services (this will take 10-15 minutes on first run)
   docker-compose up -d
   
   # Monitor the startup process
   docker-compose logs -f
   ```

3. **Verify services are healthy**:
   ```bash
   docker-compose ps
   ```

4. **Access the services**:
   - Oracle XE SQL*Plus: `docker exec -it oracle-xe-source sqlplus sys/Oracle123!@XE as sysdba`
   - PostgreSQL: `docker exec -it postgresql-target psql -U postgres -d targetdb`
   - pgAdmin: http://localhost:8080 (admin@example.com / admin123)
   - GoldenGate Oracle: http://localhost:9100 (oggadmin / Oracle123!)
   - GoldenGate PostgreSQL: http://localhost:9200 (oggadmin / Oracle123!)

## 📁 Project Structure

```
oracle-goldengate-postgres-demo/
├── docker-compose.yml          # Main orchestration file
├── README.md                   # This file
├── .gitignore                  # Git ignore rules
│
├── configs/                    # Configuration files
│   ├── goldengate/            # GoldenGate parameter files
│   ├── oracle/                # Oracle configuration
│   └── postgresql/            # PostgreSQL configuration
│
├── scripts/                   # Setup and utility scripts
│   ├── oracle/               # Oracle initialization scripts
│   ├── postgresql/           # PostgreSQL initialization scripts
│   └── goldengate/           # GoldenGate setup scripts
│
├── docs/                     # Documentation
├── data/                     # Persistent data (gitignored)
└── logs/                     # Application logs (gitignored)
```

## 🔧 Configuration

### Default Credentials

| Service | Username | Password | Database |
|---------|----------|----------|----------|
| Oracle XE | sys | Oracle123! | XE |
| PostgreSQL | postgres | Postgres123! | targetdb |
| GoldenGate | oggadmin | Oracle123! | - |
| pgAdmin | admin@example.com | admin123 | - |

### Network Configuration

- **Subnet**: 172.20.0.0/16
- **Network**: gg-network (bridge)

All services communicate via the Docker network using hostnames.

## 🧪 Testing Data Replication

### 1. Create Test Table in Oracle

```sql
-- Connect to Oracle
docker exec -it oracle-xe-source sqlplus sys/Oracle123!@XE as sysdba

-- Enable supplemental logging
ALTER DATABASE ADD SUPPLEMENTAL LOG DATA;
ALTER SYSTEM SWITCH LOGFILE;

-- Create test user and table
CREATE USER testuser IDENTIFIED BY Test123!;
GRANT CONNECT, RESOURCE, DBA TO testuser;

CONNECT testuser/Test123!@XE

CREATE TABLE employees (
    id NUMBER PRIMARY KEY,
    name VARCHAR2(100),
    department VARCHAR2(50),
    salary NUMBER(10,2),
    created_date DATE DEFAULT SYSDATE
);

-- Insert test data
INSERT INTO employees VALUES (1, 'John Doe', 'IT', 75000, SYSDATE);
INSERT INTO employees VALUES (2, 'Jane Smith', 'HR', 65000, SYSDATE);
COMMIT;
```

### 2. Configure GoldenGate

*Note: Detailed GoldenGate configuration will be added in subsequent phases*

### 3. Verify Replication in PostgreSQL

```sql
-- Connect to PostgreSQL
docker exec -it postgresql-target psql -U postgres -d targetdb

-- Check if data was replicated
SELECT * FROM employees;
```

## 📚 Learning Resources

### Oracle GoldenGate
- [Oracle GoldenGate Documentation](https://docs.oracle.com/goldengate/c1230/gg-winux/index.html)
- [GoldenGate Concepts and Architecture](https://docs.oracle.com/goldengate/c1230/gg-winux/GWUAD/getting-started-oracle-goldengate.htm)

### PostgreSQL
- [PostgreSQL Official Documentation](https://www.postgresql.org/docs/)
- [PostgreSQL Tutorial](https://www.postgresqltutorial.com/)

### Docker
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)

## 🐛 Troubleshooting

### Common Issues

1. **Oracle container fails to start**
   - Ensure you've accepted the license agreement
   - Check available memory (Oracle needs ~2GB)
   - Verify Docker login to Oracle registry

2. **GoldenGate connection issues**
   - Wait for databases to be fully healthy before starting GoldenGate
   - Check network connectivity between containers
   - Verify credentials in configuration files

3. **PostgreSQL connection refused**
   - Ensure PostgreSQL is fully initialized
   - Check port availability (5432)

### Useful Commands

```bash
# View all container logs
docker-compose logs

# Check container health
docker-compose ps

# Restart a specific service
docker-compose restart oracle-xe

# Clean up everything
docker-compose down -v
docker system prune -f

# Execute commands in containers
docker exec -it oracle-xe-source bash
docker exec -it postgresql-target bash
```

## 🎯 Next Steps

1. **Phase 1**: Basic Setup (Current)
   - ✅ Container orchestration
   - ✅ Basic connectivity
   - ⏳ GoldenGate configuration

2. **Phase 2**: Advanced Features
   - Schema mapping
   - Data transformation
   - Conflict resolution

3. **Phase 3**: Monitoring & Operations
   - Performance monitoring
   - Alerting setup
   - Backup strategies

4. **Phase 4**: Production Readiness
   - Security hardening
   - High availability
   - Disaster recovery

## 🤝 Contributing

This is a learning project! Feel free to:
- Report issues you encounter
- Suggest improvements
- Add documentation
- Share your learning experiences

## 📄 License

This project is for educational purposes. Oracle and PostgreSQL components are subject to their respective licenses.

---

**Happy Learning!** 🚀

Remember: This is a journey. Take your time to understand each component and don't hesitate to experiment!