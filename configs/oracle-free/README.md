# Oracle Database 23ai Free Configuration

## Connection Details

### Oracle Free Database
- **Host**: localhost
- **Port**: 1521 (standard Oracle port)
- **CDB**: FREE
- **PDB**: FREEPDB1
- **SYS Password**: Oracle123!

### GoldenGate
- **Web UI**: http://localhost:9200
- **AdminClient Port**: 9021
- **Admin User**: ggadmin
- **Admin Password**: ggadmin123

## User Roles

- **pdbadmin/pdbadmin123**: PDB Administrator (general database admin)
- **ggadmin/ggadmin123**: GoldenGate Administrator (manages replication processes)
- **gguser/gguser123**: Source Table Owner (owns employees table being replicated)

## Connection Strings

### CDB (Container Database)
```
sqlplus sys/Oracle123!@localhost:1521/FREE as sysdba
```

### PDB (Pluggable Database) - Use this for GoldenGate
```
sqlplus sys/Oracle123!@localhost:1521/FREEPDB1 as sysdba
sqlplus pdbadmin/pdbadmin123@localhost:1521/FREEPDB1
sqlplus ggadmin/ggadmin123@localhost:1521/FREEPDB1
sqlplus gguser/gguser123@localhost:1521/FREEPDB1
```

## Docker Commands

### Start All Services
```bash
docker-compose up -d
```

### Start Only Oracle Free
```bash
docker-compose up oracle-free
```

### Connect to Oracle Free Container
```bash
docker exec -it oracle-free-source bash
```

### Connect to GoldenGate Container
```bash
docker exec -it gg-replication bash
```

## Key Features of Oracle 23ai Free

1. **ARM64 Native**: Runs natively on Apple Silicon Macs
2. **Logmining Server**: Available (supports GoldenGate Integrated Extract)
3. **Database Name**: FREE instead of XE or ORCL
4. **PDB Name**: FREEPDB1 instead of XEPDB1
5. **Ports**: Standard 1521/5500
6. **Memory**: 2GB SGA/1GB PGA allocation
7. **Features**: Enterprise-grade features in free edition

## Startup Time

Oracle 23ai Free starts faster than EE (3-5 minutes vs 10-15 minutes).
Wait for the healthcheck to pass before connecting.

## Testing GoldenGate

Once containers are running:

1. Open GoldenGate Web UI:
```
http://localhost:9200
Login: oggadmin / Oracle123!
```

2. Add Database Credentials:
```
Oracle Source: gguser@oracle-free:1521/FREEPDB1
PostgreSQL Target: postgres@postgresql:5432/targetdb
```

3. Create Extract (Integrated):
```
Name: EXT_FREE
Type: Integrated Extract
Database: FREEPDB1
Objects: GGUSER.EMPLOYEES
Trail: EA
```

4. Create Replicat:
```
Name: REP_PG
Type: Non-Integrated Replicat
Source Trail: EA
Target: PostgreSQL targetdb
Mapping: GGUSER.EMPLOYEES -> replicated.employees
```

The Integrated Extract will work perfectly with Oracle 23ai Free!
