-- Oracle Database 23ai Free GoldenGate Setup (IDEMPOTENT VERSION)
-- This script configures Oracle Free for GoldenGate with Integrated Extract support
-- This version can safely run multiple times without breaking the database

-- Connect to CDB as SYSDBA
CONNECT sys/Oracle123!@FREE as sysdba
set serveroutput on;

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

declare v_supp_log_data_cols integer;
BEGIN
  select count(1) into v_supp_log_data_cols from dba_tab_cols where column_name = 'SUPPLEMENTAL_LOG_DATA_MIN' and table_name = 'V$DATABASE';
  if (v_supp_log_data_cols = 0) then 
  begin
  	EXECUTE IMMEDIATE 'ALTER DATABASE ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS';
  	DBMS_OUTPUT.PUT_LINE('Supplemental logging (ALL) nowenabled');
  end; --- supp cols
  else
  begin
	dbms_output.put_line('Supplemental logging already enabled');
  end; -- supp cols?
  end if;
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
set serveroutput on 

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

exec dbms_output.put_line('connecting as gguser....');
-- Connect as gguser and create source tables (idempotent)
CONNECT gguser/"GGUser123!"@FREEPDB1
SHOW SERVEROUTPUT
SET SERVEROUTPUT ON SIZE UNLIMITED FORMAT WRAPPED
show serveroutput;
exec dbms_output.put_line('debugging...');
-- debug

-- Create employees table for testing (idempotent)
DECLARE
  table_exists NUMBER;
BEGIN
  DBMS_OUTPUT.ENABLE(NULL); -- optional, but harmless
  SELECT COUNT(*) INTO table_exists FROM user_tables WHERE table_name = 'EMPLOYEES';
  dbms_output.put_line('table found?'|| table_exists);
  IF table_exists = 0 THEN
  begin
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
    
  end;
  ELSE
    DBMS_OUTPUT.PUT_LINE('EMPLOYEES table already exists');
  END IF;
END;
/


begin
	dbms_output.put_line('loading rows');
	-- delete 
	delete employees;
    	-- Insert sample data
	INSERT INTO employees VALUES (1, 'Johnny', 'Doe', 'Engineering', 75000, SYSDATE-365, 'john.doe@company.com', 'ACTIVE');
	INSERT INTO employees VALUES (2, 'Jane', 'Smith', 'Marketing', 65000, SYSDATE-200, 'jane.smith@company.com', 'ACTIVE');
	INSERT INTO employees VALUES (3, 'Bob', 'Johnson', 'Sales', 55000, SYSDATE-100, 'bob.johnson@company.com', 'ACTIVE');
	COMMIT;
	dbms_output.put_line('loaded rows');
end; -- rows exist?
/

-- Enable supplemental logging on the table (idempotent)
CONNECT sys/"Oracle123!"@FREEPDB1 as sysdba

declare v_supp_log_data_col integer;
BEGIN
  select count(1) into v_supp_log_data_col from dba_log_groups where owner = 'GGUSER' and table_name = 'EMPLOYEES'; 
  if (v_supp_log_data_col = 0) then
  begin 
  	EXECUTE IMMEDIATE 'ALTER TABLE gguser.employees ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS';
  	DBMS_OUTPUT.PUT_LINE('Now added supplemental logging to EMPLOYEES table');
  end;
  else
  begin
	DBMS_OUTPUT.PUT_LINE('Already added supplemental logging to EMPLOYEES table');
  end; -- supp log employees?
  end if;
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
col username for a30
col created  for a18
col account_status for a30
SELECT username, created, account_status FROM dba_users WHERE username IN ('PDBADMIN', 'GGADMIN', 'GGUSER');

EXIT;
