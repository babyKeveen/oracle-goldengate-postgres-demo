-- ============================================================================
-- GoldenGate Extract Creation Procedure
-- Oracle Database 23ai Free to PostgreSQL Replication
-- ============================================================================

-- Prerequisites Check Procedure
-- ============================================
CREATE OR REPLACE PROCEDURE check_gg_prerequisites
IS
    v_count NUMBER;
    v_status VARCHAR2(100);
    v_version VARCHAR2(100);
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== GoldenGate Prerequisites Check ===');
    
    -- Check if GoldenGate user exists
    SELECT COUNT(*) INTO v_count 
    FROM all_users 
    WHERE username = 'GGUSER';
    
    IF v_count = 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'GGUSER does not exist. Run setup scripts first.');
    ELSE
        DBMS_OUTPUT.PUT_LINE('✓ GGUSER exists');
    END IF;
    
    -- Check if supplemental logging is enabled
    SELECT supplemental_log_data_min INTO v_status 
    FROM v$database;
    
    IF v_status = 'YES' THEN
        DBMS_OUTPUT.PUT_LINE('✓ Supplemental logging enabled');
    ELSE
        DBMS_OUTPUT.PUT_LINE('✗ Supplemental logging disabled - enabling now...');
        EXECUTE IMMEDIATE 'ALTER DATABASE ADD SUPPLEMENTAL LOG DATA';
        DBMS_OUTPUT.PUT_LINE('✓ Supplemental logging enabled');
    END IF;
    
    -- Check if force logging is enabled
    SELECT force_logging INTO v_status 
    FROM v$database;
    
    IF v_status = 'YES' THEN
        DBMS_OUTPUT.PUT_LINE('✓ Force logging enabled');
    ELSE
        DBMS_OUTPUT.PUT_LINE('✗ Force logging disabled - enabling now...');
        EXECUTE IMMEDIATE 'ALTER DATABASE FORCE LOGGING';
        DBMS_OUTPUT.PUT_LINE('✓ Force logging enabled');
    END IF;
    
    -- Check archivelog mode
    SELECT log_mode INTO v_status 
    FROM v$database;
    
    IF v_status = 'ARCHIVELOG' THEN
        DBMS_OUTPUT.PUT_LINE('✓ Database in ARCHIVELOG mode');
    ELSE
        DBMS_OUTPUT.PUT_LINE('✗ Database not in ARCHIVELOG mode');
        RAISE_APPLICATION_ERROR(-20002, 'Database must be in ARCHIVELOG mode for GoldenGate');
    END IF;
    
    DBMS_OUTPUT.PUT_LINE('=== Prerequisites Check Complete ===');
END;
/

-- Extract Setup Procedure
-- ============================================
CREATE OR REPLACE PROCEDURE setup_gg_extract(
    p_extract_name VARCHAR2 DEFAULT 'EXTFREE',
    p_trail_path VARCHAR2 DEFAULT './dirdat/ea',
    p_table_owner VARCHAR2 DEFAULT 'GGUSER',
    p_table_name VARCHAR2 DEFAULT 'EMPLOYEES'
)
IS
    v_sql VARCHAR2(4000);
    v_count NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== Setting up GoldenGate Extract: ' || p_extract_name || ' ===');
    
    -- Check if table exists and has supplemental logging
    SELECT COUNT(*) INTO v_count
    FROM all_tables
    WHERE owner = UPPER(p_table_owner)
    AND table_name = UPPER(p_table_name);
    
    IF v_count = 0 THEN
        RAISE_APPLICATION_ERROR(-20003, 'Table ' || p_table_owner || '.' || p_table_name || ' does not exist');
    END IF;
    
    -- Enable supplemental logging on the table
    v_sql := 'ALTER TABLE ' || p_table_owner || '.' || p_table_name || ' ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS';
    EXECUTE IMMEDIATE v_sql;
    DBMS_OUTPUT.PUT_LINE('✓ Supplemental logging enabled for ' || p_table_owner || '.' || p_table_name);
    
    -- Grant necessary privileges to GGUSER (if not already granted)
    BEGIN
        EXECUTE IMMEDIATE 'GRANT SELECT ON ' || p_table_owner || '.' || p_table_name || ' TO GGUSER';
        DBMS_OUTPUT.PUT_LINE('✓ SELECT privilege granted to GGUSER');
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE != -1749 THEN -- Ignore if privilege already granted
                RAISE;
            END IF;
    END;
    
    DBMS_OUTPUT.PUT_LINE('✓ Extract setup preparations complete');
    DBMS_OUTPUT.PUT_LINE('Next steps:');
    DBMS_OUTPUT.PUT_LINE('1. Connect to GoldenGate Admin Client');
    DBMS_OUTPUT.PUT_LINE('2. Run the extract creation commands');
    
END;
/

-- Extract Status Check Procedure
-- ============================================
CREATE OR REPLACE PROCEDURE check_extract_status(
    p_extract_name VARCHAR2 DEFAULT 'EXTFREE'
)
IS
    v_count NUMBER;
    v_status VARCHAR2(100);
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== Extract Status Check: ' || p_extract_name || ' ===');
    
    -- Check for active redo capture processes
    SELECT COUNT(*) INTO v_count
    FROM gv$goldengate_capture
    WHERE capture_name = UPPER(p_extract_name);
    
    IF v_count > 0 THEN
        SELECT state INTO v_status
        FROM gv$goldengate_capture
        WHERE capture_name = UPPER(p_extract_name)
        AND ROWNUM = 1;
        
        DBMS_OUTPUT.PUT_LINE('✓ Extract ' || p_extract_name || ' found - Status: ' || v_status);
    ELSE
        DBMS_OUTPUT.PUT_LINE('✗ Extract ' || p_extract_name || ' not found in v$goldengate_capture');
    END IF;
    
    -- Check for integrated capture processes
    SELECT COUNT(*) INTO v_count
    FROM dba_capture
    WHERE capture_name = UPPER(p_extract_name);
    
    IF v_count > 0 THEN
        SELECT status INTO v_status
        FROM dba_capture
        WHERE capture_name = UPPER(p_extract_name);
        
        DBMS_OUTPUT.PUT_LINE('✓ Integrated capture found - Status: ' || v_status);
    ELSE
        DBMS_OUTPUT.PUT_LINE('ℹ No integrated capture process found');
    END IF;
    
END;
/

-- Main Extract Creation Procedure
-- ============================================
CREATE OR REPLACE PROCEDURE create_gg_extract(
    p_extract_name VARCHAR2 DEFAULT 'EXTFREE',
    p_trail_path VARCHAR2 DEFAULT './dirdat/ea',
    p_table_owner VARCHAR2 DEFAULT 'GGUSER',
    p_table_name VARCHAR2 DEFAULT 'EMPLOYEES',
    p_check_prereqs BOOLEAN DEFAULT TRUE
)
IS
BEGIN
    DBMS_OUTPUT.PUT_LINE('====================================================');
    DBMS_OUTPUT.PUT_LINE('GoldenGate Extract Creation Procedure');
    DBMS_OUTPUT.PUT_LINE('Extract Name: ' || p_extract_name);
    DBMS_OUTPUT.PUT_LINE('Trail Path: ' || p_trail_path);
    DBMS_OUTPUT.PUT_LINE('Source Table: ' || p_table_owner || '.' || p_table_name);
    DBMS_OUTPUT.PUT_LINE('====================================================');
    
    -- Check prerequisites if requested
    IF p_check_prereqs THEN
        check_gg_prerequisites;
    END IF;
    
    -- Setup extract
    setup_gg_extract(p_extract_name, p_trail_path, p_table_owner, p_table_name);
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('====================================================');
    DBMS_OUTPUT.PUT_LINE('Database preparation complete!');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Next Steps - Run in GoldenGate Admin Client:');
    DBMS_OUTPUT.PUT_LINE('====================================================');
    DBMS_OUTPUT.PUT_LINE('1. Connect to admin client:');
    DBMS_OUTPUT.PUT_LINE('   docker compose exec goldengate bash');
    DBMS_OUTPUT.PUT_LINE('   /opt/oracle/ogg/bin/adminclient');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('2. Connect to GoldenGate service:');
    DBMS_OUTPUT.PUT_LINE('   CONNECT http://localhost:80/oggf AS ggadmin PASSWORD GGAdmin123!');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('3. Create credential store:');
    DBMS_OUTPUT.PUT_LINE('   DBLOGIN USERID gguser@oracle-free:1521/FREEPDB1, PASSWORD "GGUser123!"');
    DBMS_OUTPUT.PUT_LINE('   ADD CREDENTIALSTORE');
    DBMS_OUTPUT.PUT_LINE('   ALTER CREDENTIALSTORE ADD USER gguser@oracle-free:1521/FREEPDB1, PASSWORD "GGUser123!" ALIAS oracle_free');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('4. Create and start extract:');
    DBMS_OUTPUT.PUT_LINE('   DBLOGIN USERIDALIAS oracle_free');
    DBMS_OUTPUT.PUT_LINE('   ADD EXTRACT ' || p_extract_name || ', INTEGRATED TRANLOG, BEGIN NOW');
    DBMS_OUTPUT.PUT_LINE('   ADD EXTTRAIL ' || p_trail_path || ', EXTRACT ' || p_extract_name || ', MEGABYTES 100');
    DBMS_OUTPUT.PUT_LINE('   START EXTRACT ' || p_extract_name);
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('5. Verify extract status:');
    DBMS_OUTPUT.PUT_LINE('   INFO EXTRACT ' || p_extract_name);
    DBMS_OUTPUT.PUT_LINE('   STATS EXTRACT ' || p_extract_name);
    DBMS_OUTPUT.PUT_LINE('====================================================');
    
END;
/

-- Cleanup Procedure
-- ============================================
CREATE OR REPLACE PROCEDURE cleanup_gg_extract(
    p_extract_name VARCHAR2 DEFAULT 'EXTFREE'
)
IS
    v_count NUMBER;
    v_sql VARCHAR2(1000);
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== Cleaning up Extract: ' || p_extract_name || ' ===');
    
    -- This procedure provides SQL commands to run in GoldenGate Admin Client
    DBMS_OUTPUT.PUT_LINE('Run these commands in GoldenGate Admin Client:');
    DBMS_OUTPUT.PUT_LINE('STOP EXTRACT ' || p_extract_name);
    DBMS_OUTPUT.PUT_LINE('DELETE EXTRACT ' || p_extract_name);
    DBMS_OUTPUT.PUT_LINE('DELETE EXTTRAIL ./dirdat/ea');
    
    DBMS_OUTPUT.PUT_LINE('✓ Cleanup commands provided');
END;
/

-- Grant execute permissions to GGUSER
GRANT EXECUTE ON check_gg_prerequisites TO GGUSER;
GRANT EXECUTE ON setup_gg_extract TO GGUSER;
GRANT EXECUTE ON check_extract_status TO GGUSER;
GRANT EXECUTE ON create_gg_extract TO GGUSER;
GRANT EXECUTE ON cleanup_gg_extract TO GGUSER;

-- Usage Examples:
-- ============================================
-- Execute the main procedure with defaults:
-- EXEC create_gg_extract;
--
-- Execute with custom parameters:
-- EXEC create_gg_extract('MYEXT', './dirdat/my', 'GGUSER', 'EMPLOYEES', TRUE);
--
-- Check extract status:
-- EXEC check_extract_status('EXTFREE');
--
-- Cleanup extract:
-- EXEC cleanup_gg_extract('EXTFREE');
-- ============================================