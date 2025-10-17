-- Oracle GoldenGate Setup Script
-- This script sets up the necessary users and privileges for GoldenGate
-- Note: Connection is automatically established by the container


-- Enable GoldenGate replication
ALTER DATABASE ADD SUPPLEMENTAL LOG DATA;

-- Switch logfile to enable supplemental logging
ALTER SYSTEM SWITCH LOGFILE;

-- Switch to the pluggable database XEPDB1 (Oracle XE default PDB)
ALTER SESSION SET CONTAINER = FREEPDB1;


-- Create GoldenGate admin user in the PDB
CREATE USER ggadmin IDENTIFIED BY "GGAdmin123!";
GRANT CONNECT, RESOURCE, DBA TO ggadmin;
GRANT SELECT ANY DICTIONARY TO ggadmin;
GRANT FLASHBACK ANY TABLE TO ggadmin;

-- Additional privileges for GoldenGate
GRANT EXECUTE ON DBMS_FLASHBACK TO ggadmin;
GRANT SELECT ON SYS.V_$DATABASE TO ggadmin;
GRANT SELECT ON SYS.V_$LOG TO ggadmin;
GRANT SELECT ON SYS.V_$LOGFILE TO ggadmin;
GRANT SELECT ON SYS.V_$ARCHIVED_LOG TO ggadmin;
GRANT SELECT ON SYS.V_$ARCHIVE_DEST_STATUS TO ggadmin;
GRANT SELECT ON SYS.V_$TRANSACTION TO ggadmin;

-- Create sample schema for testing (in the PDB)
CREATE USER gguser IDENTIFIED BY "GGUser123!";
GRANT CONNECT, RESOURCE TO gguser;
GRANT UNLIMITED TABLESPACE TO gguser;
alter session set current_schema=gguser;

CREATE TABLE employees (
    id NUMBER PRIMARY KEY,
    name VARCHAR2(100) NOT NULL,
    department VARCHAR2(50),
    salary NUMBER(10,2),
    hire_date DATE DEFAULT SYSDATE,
    email VARCHAR2(100),
    status VARCHAR2(20) DEFAULT 'ACTIVE'
);

-- Enable supplemental logging for the table
ALTER TABLE employees ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;

-- Insert sample data
INSERT INTO employees (id, name, department, salary, email) VALUES 
(1, 'John Doe', 'IT', 75000, 'john.doe@company.com');
INSERT INTO employees (id, name, department, salary, email) VALUES 
(2, 'Jane Smith', 'HR', 65000, 'jane.smith@company.com');
INSERT INTO employees (id, name, department, salary, email) VALUES 
(3, 'Bob Johnson', 'Finance', 70000, 'bob.johnson@company.com');
COMMIT;

-- Show the data
SELECT * FROM employees;
