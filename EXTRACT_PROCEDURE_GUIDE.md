# GoldenGate Extract Procedure Guide

## Overview
This guide explains how to use the comprehensive GoldenGate extract procedure that automates the setup and creation of extract processes for Oracle to PostgreSQL replication.

## Files Created
- `procedures/create_gg_extract.sql` - SQL procedures for extract management
- `create_extract.sh` - Automated shell script wrapper
- `EXTRACT_PROCEDURE_GUIDE.md` - This guide

## Quick Start

### 1. Create Extract with Defaults
```bash
./create_extract.sh
```
This creates an extract named `EXTFREE` for the `GGUSER.EMPLOYEES` table.

### 2. Create Custom Extract
```bash
./create_extract.sh MYEXT ./dirdat/my GGUSER ORDERS
```

### 3. Check Extract Status
```bash
./create_extract.sh --status
```

### 4. Show GoldenGate Commands
```bash
./create_extract.sh --commands
```

## SQL Procedures Available

### Main Procedures
1. **`create_gg_extract`** - Main procedure that orchestrates the entire process
2. **`check_gg_prerequisites`** - Validates database prerequisites
3. **`setup_gg_extract`** - Prepares database for extract creation
4. **`check_extract_status`** - Monitors extract status
5. **`cleanup_gg_extract`** - Provides cleanup commands

### Direct SQL Usage
```sql
-- Execute with defaults
EXEC create_gg_extract;

-- Execute with custom parameters
EXEC create_gg_extract('MYEXT', './dirdat/my', 'GGUSER', 'ORDERS', TRUE);

-- Check status
EXEC check_extract_status('EXTFREE');

-- Cleanup
EXEC cleanup_gg_extract('EXTFREE');
```

## What the Procedure Does

### Database Preparation
1. ✅ Validates GGUSER exists
2. ✅ Enables supplemental logging (database level)
3. ✅ Enables force logging
4. ✅ Verifies ARCHIVELOG mode
5. ✅ Enables table-level supplemental logging
6. ✅ Grants necessary privileges

### Prerequisites Checked
- GoldenGate user (GGUSER) exists
- Database is in ARCHIVELOG mode
- Supplemental logging is enabled
- Force logging is enabled
- Target table exists
- Proper permissions are granted

## Complete Workflow

### Step 1: Run Database Preparation
```bash
./create_extract.sh
```

### Step 2: Execute GoldenGate Commands
The procedure will output the exact commands to run. Connect to GoldenGate and execute:

```bash
# Connect to GoldenGate container
docker compose exec goldengate bash

# Start admin client
/opt/oracle/ogg/bin/adminclient

# Connect to service
CONNECT http://localhost:80/oggf AS ggadmin PASSWORD GGAdmin123!

# Create credential store (if not exists)
DBLOGIN USERID gguser@oracle-free:1521/FREEPDB1, PASSWORD "GGUser123!"
ADD CREDENTIALSTORE
ALTER CREDENTIALSTORE ADD USER gguser@oracle-free:1521/FREEPDB1, PASSWORD "GGUser123!" ALIAS oracle_free

# Create and start extract
DBLOGIN USERIDALIAS oracle_free
ADD EXTRACT EXTFREE, INTEGRATED TRANLOG, BEGIN NOW
ADD EXTTRAIL ./dirdat/ea, EXTRACT EXTFREE, MEGABYTES 100
START EXTRACT EXTFREE

# Verify extract
INFO EXTRACT EXTFREE
STATS EXTRACT EXTFREE
```

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| extract_name | EXTFREE | Name of the extract process |
| trail_path | ./dirdat/ea | Path for trail files |
| table_owner | GGUSER | Owner of the source table |
| table_name | EMPLOYEES | Name of the source table |

## Troubleshooting

### Common Issues

1. **Container not running**
   ```bash
   docker compose up -d
   ```

2. **Prerequisites not met**
   - The procedure automatically enables most settings
   - Check ARCHIVELOG mode manually if needed

3. **Extract already exists**
   ```bash
   ./create_extract.sh --cleanup
   ```

### Monitoring

Check extract status at any time:
```bash
./create_extract.sh --status
```

Or in GoldenGate Admin Client:
```
INFO EXTRACT EXTFREE
STATS EXTRACT EXTFREE
```

## Advanced Usage

### Multiple Extracts
Create different extracts for different tables:
```bash
./create_extract.sh EXT_ORDERS ./dirdat/ord GGUSER ORDERS
./create_extract.sh EXT_CUSTOMERS ./dirdat/cust GGUSER CUSTOMERS
```

### Custom Configuration
Modify the `.prm` files in `configs/goldengate/` for advanced settings:
- `EXTFREE.prm` - Extract configuration
- `REPPG.prm` - Replicat configuration

## Integration with Existing Setup

The procedure integrates with your existing configuration:
- Uses existing `GGUSER` and credentials
- Works with current Docker Compose setup
- Leverages existing trail file structure
- Compatible with existing replicat configuration

## Next Steps

After creating the extract:
1. Verify extract is running: `INFO EXTRACT EXTFREE`
2. Check replicat status: `INFO REPLICAT REPPG`  
3. Monitor statistics: `STATS EXTRACT EXTFREE`
4. Test with sample data changes

## Support Files

Reference the existing configuration files:
- `configs/goldengate/EXTFREE.prm` - Extract parameters
- `configs/goldengate/REPPG.prm` - Replicat parameters
- `configs/goldengate/setup_replication.oby` - Manual setup commands