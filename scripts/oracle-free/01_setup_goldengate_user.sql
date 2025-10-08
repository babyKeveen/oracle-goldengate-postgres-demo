-- Oracle Database 23ai Free GoldenGate Setup (IDEMPOTENT VERSION)
-- This script configures Oracle Free for GoldenGate with Integrated Extract support
-- This version can safely run multiple times without breaking the database

-- Connect to CDB as SYSDBA
CONNECT sys/Oracle123!@FREE as sysdba

-- Check and enable ARCHIVELOG mode only if needed (idempotent)
DECLARE
  v_log_mode VARCHAR2(20);
BEGIN
  SELECT log_mode INTO v_log_mode FROM v$database;
  IF v_log_mode = 'NOARCHIVELOG' THEN
    EXECUTE IMMEDIATE 'SHUTDOWN IMMEDIATE';
    EXECUTE IMMEDIATE 'STARTUP MOUNT';
    EXECUTE IMMEDIATE 'ALTER DATABASE ARCHIVELOG';
    EXECUTE IMMEDIATE 'ALTER DATABASE OPEN';
    DBMS_OUTPUT.PUT_LINE('ARCHIVELOG mode enabled');
  ELSE
    DBMS_OUTPUT.PUT_LINE('ARCHIVELOG mode already enabled');
  END IF;
END;
/

-- Enable GoldenGate replication (idempotent)
BEGIN
  EXECUTE IMMEDIATE 'ALTER SYSTEM SET enable_goldengate_replication=TRUE';
  DBMS_OUTPUT.PUT_LINE('GoldenGate replication enabled');
EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE = -2097 THEN -- Parameter already set
      DBMS_OUTPUT.PUT_LINE('GoldenGate replication already enabled');
    ELSE
      RAISE;
    END IF;
END;
/

-- Enable supplemental logging (idempotent)
BEGIN
  EXECUTE IMMEDIATE 'ALTER DATABASE ADD SUPPLEMENTAL LOG DATA';
  DBMS_OUTPUT.PUT_LINE('Supplemental logging enabled');
EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE = -1999 THEN -- Already enabled
      DBMS_OUTPUT.PUT_LINE('Supplemental logging already enabled');
    ELSE
      RAISE;
    END IF;
END;
/

BEGIN
  EXECUTE IMMEDIATE 'ALTER DATABASE ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS';
  DBMS_OUTPUT.PUT_LINE('Supplemental logging (ALL) enabled');
EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE = -1999 THEN -- Already enabled
      DBMS_OUTPUT.PUT_LINE('Supplemental logging (ALL) already enabled');
    ELSE
      RAISE;
    END IF;
END;
/

-- Switch to PDB for GoldenGate user setup
ALTER SESSION SET CONTAINER = FREEPDB1;

-- Create GoldenGate admin user (idempotent)
DECLARE
  user_exists NUMBER;
BEGIN
  SELECT COUNT(*) INTO user_exists FROM dba_users WHERE username = 'GGADMIN';
  IF user_exists = 0 THEN
    EXECUTE IMMEDIATE 'CREATE USER ggadmin IDENTIFIED BY "GGAdmin123!"';
    EXECUTE IMMEDIATE 'GRANT DBA TO ggadmin';
    EXECUTE IMMEDIATE 'GRANT CONNECT, RESOURCE TO ggadmin';
    DBMS_OUTPUT.PUT_LINE('Created user GGADMIN');
  ELSE
    DBMS_OUTPUT.PUT_LINE('User GGADMIN already exists');
  END IF;
END;
/

-- Create GoldenGate user for extraction (idempotent)
DECLARE
  user_exists NUMBER;
BEGIN
  SELECT COUNT(*) INTO user_exists FROM dba_users WHERE username = 'GGUSER';
  IF user_exists = 0 THEN
    EXECUTE IMMEDIATE 'CREATE USER gguser IDENTIFIED BY "GGUser123!"';
    EXECUTE IMMEDIATE 'GRANT DBA TO gguser';
    EXECUTE IMMEDIATE 'GRANT CONNECT, RESOURCE TO gguser';
    DBMS_OUTPUT.PUT_LINE('Created user GGUSER');
  ELSE
    DBMS_OUTPUT.PUT_LINE('User GGUSER already exists');
  END IF;
END;
/

-- Create PDB admin user (idempotent)
DECLARE
  user_exists NUMBER;
BEGIN
  SELECT COUNT(*) INTO user_exists FROM dba_users WHERE username = 'PDBADMIN';
  IF user_exists = 0 THEN
    EXECUTE IMMEDIATE 'CREATE USER pdbadmin IDENTIFIED BY "PDBAdmin123!"';
    EXECUTE IMMEDIATE 'GRANT CONNECT, RESOURCE TO pdbadmin';
    EXECUTE IMMEDIATE 'GRANT UNLIMITED TABLESPACE TO pdbadmin';
    DBMS_OUTPUT.PUT_LINE('Created user PDBADMIN');
  ELSE
    DBMS_OUTPUT.PUT_LINE('User PDBADMIN already exists');
  END IF;
END;
/

-- Grant GoldenGate-specific privileges (idempotent)
BEGIN
  DBMS_GOLDENGATE_AUTH.GRANT_ADMIN_PRIVILEGE('GGADMIN');
  DBMS_OUTPUT.PUT_LINE('Granted GG privileges to GGADMIN');
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('GG privileges already granted to GGADMIN or error occurred');
END;
/

BEGIN
  DBMS_GOLDENGATE_AUTH.GRANT_ADMIN_PRIVILEGE('GGUSER');
  DBMS_OUTPUT.PUT_LINE('Granted GG privileges to GGUSER');
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('GG privileges already granted to GGUSER or error occurred');
END;
/

-- Connect as gguser and create source tables (idempotent)
CONNECT gguser/"GGUser123!"@FREEPDB1

-- Create employees table for testing (idempotent)
DECLARE
  table_exists NUMBER;
BEGIN
  SELECT COUNT(*) INTO table_exists FROM user_tables WHERE table_name = 'EMPLOYEES';
  IF table_exists = 0 THEN
    EXECUTE IMMEDIATE 'CREATE TABLE employees (
        employee_id NUMBER(10) PRIMARY KEY,
        first_name VARCHAR2(50) NOT NULL,
        last_name VARCHAR2(50) NOT NULL,
        department VARCHAR2(50),
        salary NUMBER(10,2),
        hire_date DATE,
        email VARCHAR2(100),
        status VARCHAR2(20) DEFAULT ''ACTIVE''
    )';
    DBMS_OUTPUT.PUT_LINE('Created EMPLOYEES table');
    
    -- Insert sample data
    INSERT INTO employees VALUES (1, 'John', 'Doe', 'Engineering', 75000, SYSDATE-365, 'john.doe@company.com', 'ACTIVE');
    INSERT INTO employees VALUES (2, 'Jane', 'Smith', 'Marketing', 65000, SYSDATE-200, 'jane.smith@company.com', 'ACTIVE');
    INSERT INTO employees VALUES (3, 'Bob', 'Johnson', 'Sales', 55000, SYSDATE-100, 'bob.johnson@company.com', 'ACTIVE');
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Inserted sample data');
  ELSE
    DBMS_OUTPUT.PUT_LINE('EMPLOYEES table already exists');
  END IF;
END;
/

-- Enable supplemental logging on the table (idempotent)
CONNECT sys/"Oracle123!"@FREEPDB1 as sysdba

BEGIN
  EXECUTE IMMEDIATE 'ALTER TABLE gguser.employees ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS';
  DBMS_OUTPUT.PUT_LINE('Added supplemental logging to EMPLOYEES table');
EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE = -1999 THEN -- Already enabled
      DBMS_OUTPUT.PUT_LINE('Supplemental logging already enabled on EMPLOYEES table');
    ELSE
      RAISE;
    END IF;
END;
/

-- Show configuration
SELECT name, log_mode FROM v$database;
SELECT supplemental_log_data_min FROM v$database;
SELECT * FROM dba_users WHERE username IN ('PDBADMIN', 'GGADMIN', 'GGUSER');

EXIT;