# GoldenGate Extract Troubleshooting Guide

## 🔍 Extract Configuration Review

### **Extract Process: EXTFREE**
- **Type**: Integrated Extract
- **Source**: Oracle Database 23ai Free (FREEPDB1)
- **Trail**: ./dirdat/ea
- **Tables**: gguser.employees

### **Key Features**
- ✅ Integrated Extract (better performance)
- ✅ ARM64 native Oracle Free support
- ✅ Optimized for low-latency replication

## 🚨 Common Issues & Solutions

### 1. **Extract Won't Start**
```sql
-- Check extract status
INFO EXTRACT EXTFREE

-- Common causes:
-- ❌ Database not ready
-- ❌ Insufficient privileges
-- ❌ Archive log mode not enabled
```

**Solutions:**
```sql
-- Verify database connection
DBLOGIN USERID gguser@oracle-free:1521/FREEPDB1, PASSWORD "GGUser123!"

-- Check archive log mode
SELECT log_mode FROM v$database;

-- Enable if needed (run as SYS)
ALTER DATABASE ARCHIVELOG;
```

### 2. **Logmining Server Error**
```
ERROR: Could not start Logmining Server
```

**Solution:** Oracle Free 23ai supports integrated extract, but verify:
```sql
-- Check if LogMiner is available
SELECT * FROM v$logmnr_contents WHERE ROWNUM = 1;

-- Restart extract with fresh position
STOP EXTRACT EXTFREE
DELETE EXTRACT EXTFREE
ADD EXTRACT EXTFREE, INTEGRATED TRANLOG, BEGIN NOW
START EXTRACT EXTFREE
```

### 3. **Permission Issues**
```
ERROR: Insufficient privileges for user GGUSER
```

**Solutions:**
```sql
-- Grant necessary privileges (run as SYS)
GRANT EXECUTE ON DBMS_GOLDENGATE_AUTH TO gguser;
EXEC DBMS_GOLDENGATE_AUTH.GRANT_ADMIN_PRIVILEGE('GGUSER');
GRANT SELECT ANY DICTIONARY TO gguser;
GRANT FLASHBACK ANY TABLE TO gguser;
```

### 4. **Trail File Issues**
```
ERROR: Cannot create trail file
```

**Solutions:**
```bash
# Check trail directory permissions
ls -la /opt/oracle/ogg/dirdat/

# Create directory if missing
mkdir -p /opt/oracle/ogg/dirdat/
chown oracle:oinstall /opt/oracle/ogg/dirdat/
```

## 🔧 Extract Monitoring Commands

### **Status Checks**
```sql
-- Overall status
INFO ALL

-- Detailed extract info
INFO EXTRACT EXTFREE, DETAIL

-- Check lag
LAG EXTRACT EXTFREE

-- Statistics
STATS EXTRACT EXTFREE, LATEST
```

### **Log Analysis**
```bash
# Extract error log
tail -f /opt/oracle/ogg/ggserr/EXTFREE.log

# Extract report
less /opt/oracle/ogg/dirrpt/EXTFREE.rpt
```

## ⚡ Performance Tuning

### **Extract Parameters**
```sql
-- In EXTFREE.prm file:
TRANLOGOPTIONS MINEFROMREDO        -- Read from redo logs
REPORTCOUNT EVERY 10000           -- Reduce reporting frequency
CACHEMGR CACHESIZE 512MB          -- Increase cache
```

### **Database Optimization**
```sql
-- Optimize log switching frequency
ALTER SYSTEM SET log_checkpoint_interval = 0;
ALTER SYSTEM SET log_checkpoint_timeout = 0;

-- Increase redo buffer
ALTER SYSTEM SET log_buffer = 50331648;  -- 48MB
```

## 🎯 Expected Extract Behavior

### **Healthy Extract Shows:**
```
EXTRACT    EXTFREE   Last Started 2024-10-06 14:44   Status RUNNING
Checkpoint Lag       00:00:05 (updated 00:00:02 ago)
Process ID           12345
Log Read Checkpoint  Oracle Redo Logs
```

### **Performance Targets:**
- **Lag**: < 10 seconds under normal load
- **Throughput**: 1000+ transactions/second
- **Memory Usage**: < 512MB per extract

## 🔄 Quick Recovery Steps

If extract completely fails:

```sql
-- 1. Stop and clean up
STOP EXTRACT EXTFREE
DELETE EXTRACT EXTFREE

-- 2. Recreate from current position  
ADD EXTRACT EXTFREE, INTEGRATED TRANLOG, BEGIN NOW
ADD EXTTRAIL ./dirdat/ea, EXTRACT EXTFREE

-- 3. Start fresh
START EXTRACT EXTFREE

-- 4. Monitor startup
INFO EXTRACT EXTFREE, SHOWCH
```

## 📞 Support Information

For issues specific to Oracle Free 23ai:
- Check Oracle documentation for Integrated Extract requirements
- Verify Oracle Free licensing allows GoldenGate usage
- Consider fallback to Classic Extract if Integrated fails