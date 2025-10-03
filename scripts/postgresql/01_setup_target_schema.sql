-- PostgreSQL Target Schema Setup
-- This script creates the target schema and tables for GoldenGate replication

-- Connect to target database
\c targetdb;

-- Create a schema for replicated data
CREATE SCHEMA IF NOT EXISTS replicated;

-- Create target table matching Oracle source structure
CREATE TABLE replicated.employees (
    id INTEGER PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    department VARCHAR(50),
    salary NUMERIC(10,2),
    hire_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    email VARCHAR(100),
    status VARCHAR(20) DEFAULT 'ACTIVE'
);

-- Create indexes for better performance
CREATE INDEX idx_employees_department ON replicated.employees(department);
CREATE INDEX idx_employees_status ON replicated.employees(status);

-- Create a user for GoldenGate operations
CREATE USER gguser WITH PASSWORD 'Oracle123!';

-- Grant necessary privileges to the GoldenGate user
GRANT USAGE ON SCHEMA replicated TO gguser;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA replicated TO gguser;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA replicated TO gguser;

-- Grant privileges on future objects
ALTER DEFAULT PRIVILEGES IN SCHEMA replicated 
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO gguser;
ALTER DEFAULT PRIVILEGES IN SCHEMA replicated 
GRANT USAGE, SELECT ON SEQUENCES TO gguser;

-- Create a checkpoint table for GoldenGate (if needed)
CREATE TABLE replicated.gg_checkpoint (
    group_name VARCHAR(32) NOT NULL,
    group_key VARCHAR(32) NOT NULL,
    seqno BIGINT NOT NULL,
    rba BIGINT NOT NULL,
    extract_ts TIMESTAMP,
    updated_ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (group_name, group_key)
);

GRANT SELECT, INSERT, UPDATE, DELETE ON replicated.gg_checkpoint TO gguser;

-- Show the created objects
\dt replicated.*

-- Display current schema information
SELECT schemaname, tablename, tableowner 
FROM pg_tables 
WHERE schemaname = 'replicated';

-- Show privileges
\dp replicated.*