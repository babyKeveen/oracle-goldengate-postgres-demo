# Oracle GoldenGate PostgreSQL Demo - Complete Architecture

## 🏗️ **Container Architecture Overview**

This project now includes **TWO parallel Oracle environments** for comparison and learning:

### 1. **Oracle XE Environment** (Original - Limited)
```
Oracle XE (port 1521) → GoldenGate Extract (port 9100) → PostgreSQL (port 5432)
```
- **Limitation**: No logmining server (integrated capture fails)
- **Status**: Extract starts but stops due to `OGG-02022` error
- **Use Case**: Understanding the limitation of Express Edition

### 2. **Oracle Enterprise Edition Environment** (New - Full Featured)
```
Oracle EE (port 1522) → GoldenGate EE Extract (port 9110) → PostgreSQL (port 5432)
```
- **Advantage**: Full logmining server support
- **Status**: Should work with integrated capture
- **Use Case**: Production-ready GoldenGate replication

## 📊 **Port Mapping Summary**

| Service | XE Environment | EE Environment | PostgreSQL | Web Admin |
|---------|----------------|----------------|------------|-----------|
| Oracle DB | 1521 | **1522** | - | - |
| Oracle EM | 5500 | **5501** | - | - |
| GoldenGate Web | 9100 | **9110** | - | - |
| GG AdminClient | 9011 | **9012** | - | - |
| PostgreSQL | - | - | 5432 | - |
| pgAdmin | - | - | - | 8080 |

## 🔧 **Connection Details**

### Oracle XE (Limited)
```bash
# Database
sqlplus sys/Oracle123!@localhost:1521/XE as sysdba
sqlplus testuser/Test123!@localhost:1521/XEPDB1

# GoldenGate
docker exec -it gg-oracle-extract /u01/ogg/bin/adminclient
# Web: http://localhost:9100
```

### Oracle EE (Full Featured)
```bash
# Database  
sqlplus sys/Oracle123!@localhost:1522/ORCL as sysdba
sqlplus testuser/Test123!@localhost:1522/ORCLPDB1

# GoldenGate
docker exec -it gg-oracle-ee-extract /u01/ogg/bin/adminclient
# Web: http://localhost:9110
```

### PostgreSQL (Shared Target)
```bash
# Database
psql -h localhost -p 5432 -U postgres -d targetdb

# Web Admin
# http://localhost:8080 (admin@example.com / admin123)
```

## 🚀 **Startup Commands**

### Start Everything
```bash
docker-compose up -d
```

### Start Only XE Environment
```bash
docker-compose up -d oracle-xe goldengate-oracle postgresql pgadmin
```

### Start Only EE Environment
```bash
./start-oracle-ee.sh
# or manually:
docker-compose up -d oracle-ee goldengate-oracle-ee postgresql pgadmin
```

### Start Individual Components
```bash
# Oracle XE + GoldenGate XE
docker-compose up -d oracle-xe goldengate-oracle

# Oracle EE + GoldenGate EE  
docker-compose up -d oracle-ee goldengate-oracle-ee

# PostgreSQL + Replicat + pgAdmin
docker-compose up -d postgresql goldengate-postgresql pgadmin
```

## 🎯 **Expected Results**

### XE Environment (Educational)
- ❌ Extract fails: "Logmining server does not exist"
- ✅ Shows Oracle XE limitations clearly
- ✅ Perfect for understanding the problem

### EE Environment (Production-Ready)
- ✅ Extract should run successfully
- ✅ Full integrated capture support
- ✅ Complete GoldenGate functionality
- ✅ End-to-end replication working

## 💡 **Learning Path**

1. **Compare Environments**: Start both and see the difference
2. **Test XE Limitation**: Confirm the logmining server error
3. **Test EE Success**: Verify Extract runs smoothly
4. **Configure Replicat**: Complete the PostgreSQL side
5. **End-to-End Test**: Full data replication working

## 🆓 **Licensing**

- **Oracle XE**: Always free, production use allowed
- **Oracle EE**: Free for development/learning, requires license for production
- **GoldenGate Free**: Limited but sufficient for learning
- **PostgreSQL**: Open source, always free

## 🏆 **Architecture Benefits**

1. **Side-by-Side Comparison**: See exactly why EE works and XE doesn't
2. **Production Learning**: EE environment mirrors real-world setups
3. **Container Isolation**: Each environment is completely separate
4. **CLI Automation**: All your AdminClient scripts work on both
5. **Future-Proof**: Easy to extend with additional features

This architecture gives you the **best of both worlds** - understanding limitations AND seeing the full solution! 🎉