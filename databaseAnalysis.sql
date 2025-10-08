-- --------------------------------------------------------------------------------------------------------
-- Copyright (c) 2023 Oracle and/or its affiliates.  All rights reserved.
-- Licensed under the Universal Permissive License v 1.0 as shown at http://oss.oracle.com/licenses/upl.
--
-- File Name    : ggfree_priv_v6.3.sql
-- Description  : Lists all changes needed in the database to enable GoldenGate
-- Call Syntax  : @ggfree_priv
-- Output file  : GoldenGate_Configuration.sql
-- Requirements : sysdba at CDB root container or nonCDB
-- Last Modified: 11 July 2023
--
-- 07/11/23 - Alex Lima: Bug 35387147  Fixed default tablespace
--                       Bug 35573835  Added support for 23c roles
--                       Bug 35387609  Add Instance Name to avoid Bounce Required for RAC on stream_pool_size
--                                     Added "alter database add supplemental log data for procedural replication"
-- 08/22/23 - Alex Lima: Added Per-PDB-Capture for 21 and 23 databases
--                       Added OGG_CAPTURE and OGG_APPLY roles for 23c and greater database
--
-- --------------------------------------------------------------------------------------------------------
spool GoldenGate_Configuration.sql
SET SERVEROUTPUT ON
CLEAR SCREEN
SET FEEDBACK OFF
SET LINE 300
DECLARE
    -- Constant Values from the OGG Free Front End Choices, mandatory values
    -- User the Database instance service name if the database is nonCDB.
c_pdb_service_name    VARCHAR2(100) := 'ORACLEPDB1';
    c_db_password         VARCHAR2(50)  := 'Oracle123!';

    -- Other Constant values
    c_cdb_user            VARCHAR2(20) := '';
    c_pdb_user            VARCHAR2(20)  := 'ggadmin';
    c_noncdb_user         VARCHAR2(20)  := 'ggadmin';

    c_ogg_tablespace      VARCHAR2(20)  := 'GG_ADMIN_DATA';
    c_pdb_choice          VARCHAR2(20);

    -- Exceptions
    c_cdb_user_invalid          EXCEPTION;
    c_pdb_user_invalid          EXCEPTION;
    c_noncdb_user_invalid       EXCEPTION;
    c_db_password_invalid       EXCEPTION;
    c_pdb_service_name_invalid  EXCEPTION;
    v_pdb_service_name_invalid  EXCEPTION;
    c_cdb_user_not_needed       EXCEPTION;

    -- Current State Variable
    v_db_name             VARCHAR2(20);
    v_instance_name       VARCHAR2(20);
    v_db_unique_name      VARCHAR2(20);
    v_log_mode            VARCHAR2(20);
    v_force_logging       VARCHAR2(20);
    v_supplemental        VARCHAR2(20);
    v_stream_pool_size    VARCHAR2(20);
    v_enable_ogg_rep      VARCHAR2(20);
    v_is_cdb              VARCHAR2(20);
    v_is_rac              NUMBER(10);
    v_printing            VARCHAR2(50);
    v_recommended_stream  NUMBER := 512;
    v_cdb_service_name    VARCHAR2(100);
    v_pdb_service_name    VARCHAR2(100);
    v_noncdb_service_name VARCHAR2(100);
    v_period_pos          NUMBER;
    v_host_name           VARCHAR2(50);
    v_pdb_name            VARCHAR2(20);
    v_restart             VARCHAR2(20);
    v_is_db_gg_ready      BOOLEAN;
    v_cdb_package_executed      VARCHAR2(10);
    v_pdb_package_executed      VARCHAR2(10);
    v_noncdb_package_executed   VARCHAR2(10);
    v_pdb_service_name_exist    VARCHAR2(100);
    v_dv_enabled                VARCHAR2(60);
    v_db_version                VARCHAR2(10);
    v_cdb_user_needed           VARCHAR2(5);
    v_session_altered_completed VARCHAR2(10);
    v_alter_pdb                 VARCHAR2(5);


    --- Users and Tablespace Variables
    v_data_file_name      VARCHAR2(200);
    v_data_file_dest      VARCHAR2(4000);
    v_asm_diskegroup      VARCHAR2(200);
    v_file_system         VARCHAR2(200);
    v_os_slash            VARCHAR2(100);
    v_cdb_user            VARCHAR2(20);
    v_pdb_user            VARCHAR2(20);
    v_cdb_tablespace      VARCHAR2(3);
    v_pdb_tablespace      VARCHAR2(3);
    v_pdb_data_file_name  VARCHAR2(100);
    v_noncdb_user         VARCHAR2(10);
    v_noncdb_tablespace   VARCHAR2(3);
    v_match_found         BOOLEAN := FALSE;
    v_match_to_print      VARCHAR2(50);
    v_db_domain           VARCHAR2(50);
    v_default_temp_tbs    VARCHAR2(50);

    -- Grants for the CDB Container
    type cdb_array IS VARRAY(50) OF VARCHAR2(50);
    v_cdb_privs cdb_array := cdb_array(
    'CONNECT',
    'RESOURCE',
    'CREATE TABLE',
    'CREATE VIEW',
    'CREATE SESSION',
    'SELECT_CATALOG_ROLE',
    'DV_GOLDENGATE_ADMIN',
    'DV_GOLDENGATE_REDO_ACCESS',
    'ALTER SYSTEM',
    'ALTER USER',
    'ALTER DATABASE',
    'SELECT ANY DICTIONARY',
    'SELECT ANY TRANSACTION',
    'OGG_CAPTURE',
    'OGG_APPLY');

    -- Grants for the PDB Container and NonCDB Databases
    type pdb_array IS VARRAY(50) OF VARCHAR2(50);
    v_pdb_privs pdb_array := pdb_array(
    'CONNECT',
    'RESOURCE',
    'CREATE SESSION',
    'SELECT_CATALOG_ROLE',
    'DV_GOLDENGATE_ADMIN',
    'DV_GOLDENGATE_REDO_ACCESS',
    'ALTER SYSTEM',
    'ALTER USER',
    'ALTER DATABASE',
    'DATAPUMP_EXP_FULL_DATABASE',
    'DATAPUMP_IMP_FULL_DATABASE',
    'SELECT ANY DICTIONARY',
    'SELECT ANY TRANSACTION',
    'INSERT ANY TABLE',
    'UPDATE ANY TABLE',
    'DELETE ANY TABLE',
    'LOCK ANY TABLE',
    'CREATE ANY TABLE',
    'CREATE ANY INDEX',
    'CREATE ANY CLUSTER',
    'CREATE ANY INDEXTYPE',
    'CREATE ANY OPERATOR',
    'CREATE ANY PROCEDURE',
    'CREATE ANY SEQUENCE',
    'CREATE ANY TRIGGER',
    'CREATE ANY TYPE',
    'CREATE ANY SEQUENCE',
    'CREATE ANY VIEW',
    'ALTER ANY TABLE',
    'ALTER ANY INDEX',
    'ALTER ANY CLUSTER',
    'ALTER ANY INDEXTYPE',
    'ALTER ANY OPERATOR',
    'ALTER ANY PROCEDURE',
    'ALTER ANY SEQUENCE',
    'ALTER ANY TRIGGER',
    'ALTER ANY TYPE',
    'ALTER ANY SEQUENCE',
    'CREATE DATABASE LINK',
    'OGG_CAPTURE',
    'OGG_APPLY');

  --  Proc to print the output line
  PROCEDURE dbms_output_put_line (p_print1 VARCHAR2)
IS
BEGIN
    DBMS_OUTPUT.PUT_LINE(p_print1);
END;

  PROCEDURE get_pdb_name
IS
BEGIN

    -- Check if database is Multi-tenant
select cdb into v_is_cdb from v$database;
-- Check if databse have db_domain enabled, this will be used to validate the service_name and pdb
select nvl(value, null) into v_db_domain
from v$parameter where name = 'db_domain';

-- Check if the servicename entered is valid and assing the PDB name to the process based on the same service name.
select distinct upper(pdb) into v_pdb_name
from v$services
where upper(network_name) =  upper(c_pdb_service_name)
   or   upper(network_name) =  upper(c_pdb_service_name||'.'||v_db_domain)
   or   upper(network_name) =  upper(SUBSTR(c_pdb_service_name, 1, INSTR(c_pdb_service_name, '.') - 1));

-- If PDB is not populated, error will be displayed
if v_pdb_name is null and v_is_cdb ='YES' then
     raise c_pdb_service_name_invalid;
end if;
EXCEPTION

    WHEN TOO_MANY_ROWS then
      DBMS_OUTPUT_PUT_LINE(rpad('--',90,'#'));
      DBMS_OUTPUT_PUT_LINE('--          Database GoldenGate Error  ');
      DBMS_OUTPUT_PUT_LINE(rpad('--',90,'#'));
      DBMS_OUTPUT_PUT_LINE('--');
      DBMS_OUTPUT_PUT_LINE('-20102,TOO MANY ROWS, The service name '''||upper(c_pdb_service_name)||''' entered was not found.  Please review the service name provided. ');

END; --get_pdb_name

  PROCEDURE check_database
is
BEGIN

    -- Check Database Version
select DBMS_DB_VERSION.VERSION into v_db_version from dual;

--Check for contant parameters, raise error if it's not set
if c_cdb_user is NULL then
        if v_db_version > 19 then
            v_cdb_user_needed := 'NO';
        elsif v_db_version <= 19 and v_is_cdb = 'NO' then
            v_cdb_user_needed := 'NO';
else
            RAISE c_cdb_user_invalid;
end if;
    elsif c_cdb_user is not null then
        if v_db_version > 19 then
            RAISE c_cdb_user_not_needed;
end if;
    elsif c_db_password is NULL then
        RAISE c_db_password_invalid;
    elsif c_pdb_user is NULL then
        RAISE c_pdb_user_invalid;
    elsif c_noncdb_user is NULL then
        RAISE c_noncdb_user_invalid;
end if;

    -- Check general database status
select host_name into v_host_name from v$instance;
select name into v_db_name from v$database;
select instance_name into v_instance_name from v$instance;
select db_unique_name into v_db_unique_name from v$database;
select decode(log_mode, 'ARCHIVELOG', 'YES', 'NO') into v_log_mode from v$database;
select force_logging into v_force_logging from v$database;
select supplemental_log_data_min into v_supplemental from v$database;
select value into v_enable_ogg_rep from v$parameter  where name='enable_goldengate_replication';
select property_value into v_default_temp_tbs from database_properties where property_name = 'DEFAULT_TEMP_TABLESPACE';
select DBMS_DB_VERSION.VERSION into v_db_version from dual;

-- Check if the database is RAC (Clustered)
select count(*) into v_is_rac from v$instance;

-- Check if database has Data Vault enabled
select value into v_dv_enabled from v$option where parameter ='Oracle Database Vault';

-- Check for CDB service name
select value into v_cdb_service_name from v$parameter where name = 'service_names';
-- Define the best value for Stream Pool Size, 1G is the recommended value for a normal database
-- for OGG Free we recommend 512M if streams_pool_size is set to 0 or lower then 512M.
select round(value/1024/1024) into v_stream_pool_size from v$parameter  where name='streams_pool_size';
-- Check if CDB Users and Tablespace exists
if v_is_cdb = 'YES' then

select decode(count(*),1,'YES','NO') into v_cdb_user from dba_users where username = upper(c_cdb_user);  -- CDB USER
--select decode(count(*),1,'YES','NO') into v_cdb_tablespace from dba_tablespaces where tablespace_name = upper(c_ogg_tablespace);  -- CDB Tablespace
-- Check if PDB User and Tablespace exist
select decode(count(*),1,'YES','NO') into v_pdb_user from cdb_users
where username = upper(c_pdb_user)
  and con_id = (select con_id from v$pdbs where upper(name) = upper(v_pdb_name));  -- PDB User
select decode(count(*),1,'YES','NO') into v_pdb_tablespace from cdb_tablespaces
where tablespace_name = upper(c_ogg_tablespace)
  and con_id = (select con_id from v$pdbs where upper(name) = upper(v_pdb_name));  -- PDB Tablespace
else
        -- Check NonCDB user and tablespace
select decode(count(*),1,'YES','NO') into v_noncdb_user from dba_users where username = upper(c_noncdb_user);
select decode(count(*),1,'YES','NO') into v_noncdb_tablespace from dba_tablespaces where tablespace_name = upper(c_ogg_tablespace);
end if;
END;  -- check database

  -----------------------------------------------------------------------------------
  -- Proc to Generate the DDL for the create tablespace
  -- It checks if the file system is ASM diskgroup, Linux or Windows file system
  -----------------------------------------------------------------------------------
  PROCEDURE create_tablespace(p_pdb VARCHAR2)
IS
BEGIN
      --------------------------------------
      --  Create tablespaces
      --------------------------------------

      --  First Check if database is in OMF enabled
select value into v_data_file_dest from v$parameter where name = 'db_create_file_dest';

-- If the database is OMF enabled, if it is, we just create the tablespace with the value.
-- If not we check if the database is CDB or not, if it's is ASM of Windows or Linux File systems, extract the path or disk group to add the location to create tablespace DDL.
if v_data_file_dest is not null then
       if REGEXP_LIKE(v_data_file_dest, '^\+') = "TRUE" THEN
           DBMS_OUTPUT_PUT_LINE('CREATE TABLESPACE '||c_ogg_tablespace||' DATAFILE ''' || v_data_file_dest ||''' SIZE 100m AUTOEXTEND ON NEXT 100m;');
else
SELECT SYS_CONTEXT('USERENV', 'PLATFORM_SLASH') INTO v_os_slash FROM DUAL;
DBMS_OUTPUT_PUT_LINE('CREATE TABLESPACE '||c_ogg_tablespace||' DATAFILE ''' || v_data_file_dest ||''|| v_os_slash ||'ggadmin_data.dbf'' SIZE 100m AUTOEXTEND ON NEXT 100m;');
end if;
else
          if p_pdb = 'CDB' or p_pdb = 'nonCDB' then
select file_name into v_data_file_name from dba_data_files where tablespace_name='SYSTEM';
else
select file_name into v_data_file_name from cdb_data_files where con_id = (select con_id from v$pdbs where name = upper(v_pdb_name)) and tablespace_name='SYSTEM';
end if;
          --  Check is data files is in ASM Diskgroup or OS File System
          IF REGEXP_LIKE(v_data_file_name, '^\+') = "TRUE" THEN
             v_asm_diskegroup:=substr(v_data_file_name,1,instr(v_data_file_name, '/', 1, 1)-1);
             DBMS_OUTPUT_PUT_LINE('CREATE TABLESPACE '||c_ogg_tablespace||' DATAFILE ''' || v_asm_diskegroup ||''' SIZE 100m AUTOEXTEND ON NEXT 100m;');
ELSE
            -- Check if platform is Windows or UNIX for slash position
SELECT SYS_CONTEXT('USERENV', 'PLATFORM_SLASH') INTO v_os_slash FROM DUAL;
if v_os_slash = '/' then
             v_file_system:=substr(v_data_file_name,1,instr(v_data_file_name, '/', -1, 1)-1);  -- UNIX/Linux slash
else
             v_file_system:=substr(v_data_file_name,1,instr(v_data_file_name, '\', -1, 1)-1);  -- Windows slash
end if;
            DBMS_OUTPUT_PUT_LINE('CREATE TABLESPACE '||c_ogg_tablespace||' DATAFILE ''' || v_file_system ||''|| v_os_slash ||'ggadmin_data.dbf'' SIZE 100m AUTOEXTEND ON NEXT 100m;');
END IF;
end if;
END;

--===================================================
-- MAIN
--===================================================
BEGIN

  -- Displaying Generat Database Information Output
  -- PDB name is require to create the appropriated user and grant privileges for GoldenGate
  get_pdb_name;
  -- Check database for GoldenGate required components
  check_database;

  --  Check if the database needs to be restarted and enable archived log mode
  if v_log_mode = 'YES' then
   v_restart := 'NO';
else
   v_restart := 'YES';
   v_is_db_gg_ready := FALSE;
end if;
  DBMS_OUTPUT_PUT_LINE('--');
  DBMS_OUTPUT_PUT_LINE(rpad('--',90,'#'));
  DBMS_OUTPUT_PUT_LINE('--          Database Information');
  DBMS_OUTPUT_PUT_LINE(rpad('--',90,'#'));
  DBMS_OUTPUT_PUT_LINE(rpad('--Database Name:                 ',32) || v_db_name);
  DBMS_OUTPUT_PUT_LINE(rpad('--Database Host Name:            ',32) || v_host_name);
  DBMS_OUTPUT_PUT_LINE(rpad('--Database Instance Name:        ',32) || v_instance_name);
  DBMS_OUTPUT_PUT_LINE(rpad('--Database Unique Name:          ',32) || v_db_unique_name);
  DBMS_OUTPUT_PUT_LINE(rpad('--Database Version:              ',32) || v_db_version);
  if v_is_cdb = 'YES' then
    DBMS_OUTPUT_PUT_LINE(rpad('--Database is Container (CDB): ',32) || v_is_cdb);
    DBMS_OUTPUT_PUT_LINE(rpad('--Database CDB Service Name:   ',32) || upper(v_cdb_service_name));
    DBMS_OUTPUT_PUT_LINE(rpad('--Database PDB Service Name:   ',32) || upper(c_pdb_service_name));
    DBMS_OUTPUT_PUT_LINE(rpad('--Database CDB User Exist:     ',32) || rpad(upper(v_cdb_user),5) ||' (User Name:  '||c_cdb_user||')');
    DBMS_OUTPUT_PUT_LINE(rpad('--Database PDB User Exist:     ',32) || rpad(upper(v_pdb_user),5) ||' (User Name:  '||c_pdb_user||')');
else
    DBMS_OUTPUT_PUT_LINE(rpad('--Database User                ',32) || rpad(upper(v_noncdb_user),5) ||' (User Name:  '||c_pdb_user||')');
    DBMS_OUTPUT_PUT_LINE(rpad('--Database Service Name:       ',32) || upper(v_cdb_service_name));
end if;
  DBMS_OUTPUT_PUT_LINE('--');
  DBMS_OUTPUT_PUT_LINE(rpad('--',90,'#'));
  DBMS_OUTPUT_PUT_LINE('--          Database GoldenGate Status  ');
  DBMS_OUTPUT_PUT_LINE(rpad('--',90,'#'));
  DBMS_OUTPUT_PUT_LINE(rpad('--Database Restart Required:   ',32) || rpad(v_restart,5));
  DBMS_OUTPUT_PUT_LINE(rpad('--Database Archived Log Mode:  ',32) || rpad(v_log_mode,5) ||         '     (Required value for GoldenGate: YES)');
  DBMS_OUTPUT_PUT_LINE(rpad('--Database Force Logging Mode: ',32) || rpad(v_force_logging,5) ||    '     (Required value for GoldenGate: YES)');
  DBMS_OUTPUT_PUT_LINE(rpad('--Database Supplemental Mode:  ',32) || rpad(v_supplemental,5) ||     '     (Required value for GoldenGate: YES)');
  DBMS_OUTPUT_PUT_LINE(rpad('--Database Stream Pool Size Mb:',32) || rpad(v_stream_pool_size,5) || '     (Recommended value for GoldenGate: '|| v_recommended_stream ||'Mb)');
  DBMS_OUTPUT_PUT_LINE(rpad('--GoldenGate Enable Parameter: ',32) || rpad(v_enable_ogg_rep,5) ||   '     (Required value for GoldenGate: TRUE)');

  DBMS_OUTPUT_PUT_LINE('--');
  DBMS_OUTPUT_PUT_LINE(rpad('--',90,'#'));
  DBMS_OUTPUT_PUT_LINE('--          SQL Script to Enable GoldenGate in the '||v_db_name||' Database  ');
  DBMS_OUTPUT_PUT_LINE(rpad('--',90,'#'));
  DBMS_OUTPUT_PUT_LINE('--');
  ---------------------------------------------------------------------------------------------------------------
  -- This session will check if a database restart is required to enable Archived Log Mode required by GoldenGate
  ---------------------------------------------------------------------------------------------------------------
  -- FOR TESTING
  --v_is_rac:=2;
  --v_log_mode:='NO';
  --Check if a bounce is required and create the DDL for RAC or NON-RAC database bounce
  if v_log_mode = 'YES' then
   DBMS_OUTPUT_PUT_LINE('-- Database is in Archived Log Mode, NO RESTART required');
   DBMS_OUTPUT_PUT_LINE('');
else
   if v_is_rac > 1 then
    DBMS_OUTPUT_PUT_LINE('-- The database is RAC enabled, it is not in Archived Log Mode and a database Restart is required.');
    DBMS_OUTPUT_PUT_LINE('-- Recommended Process:');
    DBMS_OUTPUT_PUT_LINE('--SRVCTL STOP DATABASE -db '||v_db_unique_name||' -stopoption immediate;');
    DBMS_OUTPUT_PUT_LINE('--SRVCTL START DATABASE -db '||v_db_unique_name||' -startoption mount;');
    DBMS_OUTPUT_PUT_LINE('--ALTER DATABASE ARCHIVELOG;');
    DBMS_OUTPUT_PUT_LINE('--SRVCTL STOP DATABASE -db '||v_db_unique_name||' -stopoption immediate;');
    DBMS_OUTPUT_PUT_LINE('--SRVCTL START DATABASE -db '||v_db_unique_name||';');
    DBMS_OUTPUT_PUT_LINE('--SRVCTL STATUS DATABASE -db '||v_db_unique_name||';');
else
    DBMS_OUTPUT_PUT_LINE('-- The database is non-RAC, its not in Archived Log Mode and a database Restart is required.');
    DBMS_OUTPUT_PUT_LINE('-- Recommended Process:');
    DBMS_OUTPUT_PUT_LINE('--SHUTDOWN IMMEDIATE;');
    DBMS_OUTPUT_PUT_LINE('--STARTUP MOUNT;');
    DBMS_OUTPUT_PUT_LINE('--ALTER DATABASE ARCHIVELOG;');
    DBMS_OUTPUT_PUT_LINE('--ALTER DATABASE OPEN;');
    DBMS_OUTPUT_PUT_LINE('--');
    DBMS_OUTPUT_PUT_LINE('');
end if;
end if;

  --------------------------------------
  ---  Stream pool size
  --------------------------------------

 if (v_stream_pool_size = 0 or v_stream_pool_size < round(v_recommended_stream/1024/1024)) then
    DBMS_OUTPUT_PUT_LINE('-- Database '||v_db_name||' STREAMS_POOL_SIZE current size is '||v_stream_pool_size||'Mb and it will be modified to '||v_recommended_stream||'Mb');
    DBMS_OUTPUT_PUT_LINE('-- The STREAMS_POOL_SIZE value helps determine the size of the Streams pool.');
    DBMS_OUTPUT_PUT_LINE('--');
    DBMS_OUTPUT_PUT_LINE('-- Property            Description');
    DBMS_OUTPUT_PUT_LINE('-- Parameter type      Big integer');
    DBMS_OUTPUT_PUT_LINE('-- Syntax              STREAMS_POOL_SIZE = integer [K | M | G]');
    DBMS_OUTPUT_PUT_LINE('-- Default value       0');
    DBMS_OUTPUT_PUT_LINE('-- Modifiable          ALTER SYSTEM');
    DBMS_OUTPUT_PUT_LINE('-- Modifiable in a PDB No');
    DBMS_OUTPUT_PUT_LINE('-- Range of values     Minimum: 0');
    DBMS_OUTPUT_PUT_LINE('--                     Maximum: operating system-dependent');
    DBMS_OUTPUT_PUT_LINE('-- Basic               No');
    DBMS_OUTPUT_PUT_LINE('-- ');
    DBMS_OUTPUT_PUT_LINE('-- Oracle''s Automatic Shared Memory Management feature manages the size of');
    DBMS_OUTPUT_PUT_LINE('-- the Streams pool when the SGA_TARGET initialization parameter is set to ' );
    DBMS_OUTPUT_PUT_LINE('-- a nonzero value. If the STREAMS_POOL_SIZE initialization parameter also ' );
    DBMS_OUTPUT_PUT_LINE('-- is set to a nonzero value, then Automatic Shared Memory Management uses ' );
    DBMS_OUTPUT_PUT_LINE('-- this value as a minimum for the Streams pool.');
    DBMS_OUTPUT_PUT_LINE('-- Oracle GoldenGate recommends streams_pool_size to be set at 1G or 10% of allocated SGA, whichever is smaller');
    --Bug 35387609
    DBMS_OUTPUT_PUT_LINE('ALTER SYSTEM SET STREAMS_POOL_SIZE='||v_recommended_stream||'M SCOPE=BOTH SID='''||v_instance_name||''';');
    v_is_db_gg_ready := FALSE;
else
    DBMS_OUTPUT_PUT_LINE('-- Stream pool size is already configured to '||v_stream_pool_size|| 'Mb and NO ACTION is required. ');
end if;
  DBMS_OUTPUT_PUT_LINE('--');

  --------------------------------------
  ---  Force Logging
  --------------------------------------

 if v_force_logging != 'YES' then
    DBMS_OUTPUT_PUT_LINE('-- Database '||v_db_name||' is not in the recommended Force Logging Mode, alter database is required');
    DBMS_OUTPUT_PUT_LINE('--');
    DBMS_OUTPUT_PUT_LINE('-- Use this clause to put the database into or take the database out of FORCE LOGGING mode. ');
    DBMS_OUTPUT_PUT_LINE('-- The database must be mounted or open.');
    DBMS_OUTPUT_PUT_LINE('-- ');
    DBMS_OUTPUT_PUT_LINE('-- In FORCE LOGGING mode, Oracle Database logs all changes in the database except changes in ');
    DBMS_OUTPUT_PUT_LINE('-- temporary tablespaces and temporary segments. This setting takes precedence over and is ');
    DBMS_OUTPUT_PUT_LINE('-- independent of any NOLOGGING or FORCE LOGGING settings you specify for individual ');
    DBMS_OUTPUT_PUT_LINE('-- tablespaces and any NOLOGGING settings you specify for individual database objects.');
    DBMS_OUTPUT_PUT_LINE('-- Oracle strongly recommends putting the Oracle source database into forced logging mode. ');
    DBMS_OUTPUT_PUT_LINE('-- Forced logging mode forces the logging of all transactions and loads, overriding any user ');
    DBMS_OUTPUT_PUT_LINE('-- or storage settings to the contrary. This ensures that no source data in the Extract configuration gets missed.');
    DBMS_OUTPUT_PUT_LINE('-- ');
    DBMS_OUTPUT_PUT_LINE('-- If you specify FORCE LOGGING, then Oracle Database waits for all ongoing unlogged operations to finish.');
    DBMS_OUTPUT_PUT_LINE('--');
    DBMS_OUTPUT_PUT_LINE('ALTER DATABASE FORCE LOGGING;');
    v_is_db_gg_ready := FALSE;
else
   DBMS_OUTPUT_PUT_LINE('-- Database '||v_db_name||' is in the recommended FORCE LOGGING mode, NO ACTION is required.');
end if;
  DBMS_OUTPUT_PUT_LINE('--');

  --------------------------------------
  ---  Enable GoldenGate
  --------------------------------------

  if v_enable_ogg_rep != 'TRUE' then
    DBMS_OUTPUT_PUT_LINE('-- Database '||v_db_name||' GoldenGate Replication Parameter is not ENABLED, alter database is required');
    DBMS_OUTPUT_PUT_LINE('-- ');
    DBMS_OUTPUT_PUT_LINE('-- Property             Description');
    DBMS_OUTPUT_PUT_LINE('-- Parameter type       Boolean');
    DBMS_OUTPUT_PUT_LINE('-- Default value        false');
    DBMS_OUTPUT_PUT_LINE('-- Modifiable           ALTER SYSTEM');
    DBMS_OUTPUT_PUT_LINE('-- Modifiable in a PDB  No');
    DBMS_OUTPUT_PUT_LINE('-- Range of values      true | false');
    DBMS_OUTPUT_PUT_LINE('-- Basic                No');
    DBMS_OUTPUT_PUT_LINE('-- Oracle RAC All       instances must have the same setting');
    DBMS_OUTPUT_PUT_LINE('-- ');
    DBMS_OUTPUT_PUT_LINE('-- This parameter primarily controls supplemental logging required to support logical ');
    DBMS_OUTPUT_PUT_LINE('-- replication of new data types and operations. The redo log file is designed to be ');
    DBMS_OUTPUT_PUT_LINE('-- applied physically to a database, therefore the default contents of the redo log file ');
    DBMS_OUTPUT_PUT_LINE('-- often do not contain sufficient information to allow logged changes to be converted ');
    DBMS_OUTPUT_PUT_LINE('-- into SQL statements. Supplemental logging adds extra information into the redo log ');
    DBMS_OUTPUT_PUT_LINE('-- files so that replication can convert logged changes into SQL statements without ');
    DBMS_OUTPUT_PUT_LINE('-- having to access the database for each change. Previously these extra changes ');
    DBMS_OUTPUT_PUT_LINE('-- were controlled by the supplemental logging DDL. Now the ENABLE_GOLDENGATE_REPLICATION ');
    DBMS_OUTPUT_PUT_LINE('-- parameter must also be set to enable the required supplemental logging for any ');
    DBMS_OUTPUT_PUT_LINE('-- new data types or operations.');
    DBMS_OUTPUT_PUT_LINE('-- ');
    DBMS_OUTPUT_PUT_LINE('ALTER SYSTEM SET ENABLE_GOLDENGATE_REPLICATION=TRUE SCOPE=BOTH;');
    v_is_db_gg_ready := FALSE;
else
    DBMS_OUTPUT_PUT_LINE('-- Database '||v_db_name||' GoldenGate Parameter is ENABLED, NO ACTION is required.');
end if;
  DBMS_OUTPUT_PUT_LINE('--');

  --------------------------------------
  ---  Supplemental Logging
  --------------------------------------

  if v_supplemental != 'YES' then
   DBMS_OUTPUT_PUT_LINE('-- Database '||v_db_name||' does not have SUPPLEMENTAL LOGGING enabled and an alter database is required.');
   DBMS_OUTPUT_PUT_LINE('-- ');
   DBMS_OUTPUT_PUT_LINE('-- In addition to force logging, the minimal supplemental logging, a database-level option, is required for an Oracle source database ');
   DBMS_OUTPUT_PUT_LINE('-- when using Oracle GoldenGate. This adds row chaining information, if any exists, to the redo log for update operations.');
   DBMS_OUTPUT_PUT_LINE('-- ');
   DBMS_OUTPUT_PUT_LINE('ALTER DATABASE ADD SUPPLEMENTAL LOG DATA FOR PROCEDURAL REPLICATION;');
   DBMS_OUTPUT_PUT_LINE('ALTER DATABASE ADD SUPPLEMENTAL LOG DATA;');
   v_is_db_gg_ready := FALSE;
else
   DBMS_OUTPUT_PUT_LINE('-- Database '||v_db_name||' has SUPPLEMENTAL LOGGING enabled, NO ACTION is required.');
end if;
  DBMS_OUTPUT_PUT_LINE('--');



  ----------------------------------------------------
  --  Create GoldenGate User(s) if it does not exist
  ----------------------------------------------------
  DBMS_OUTPUT_PUT_LINE('--');
  if v_is_cdb = 'YES' then

   -- Create user CDB
   if v_cdb_user = 'NO' then
    if v_cdb_user_needed is null then -- If database is > 19 PDB-Capture only, no need for CDB user
        DBMS_OUTPUT_PUT_LINE('--#######################################################################');
        DBMS_OUTPUT_PUT_LINE('--#### Create and Grant Privileges to the CDB GOldenGate Admin user. ####');
        DBMS_OUTPUT_PUT_LINE('--#######################################################################');
        DBMS_OUTPUT_PUT_LINE('--');
        DBMS_OUTPUT_PUT_LINE('-- GoldenGate CDB User does not exist, create CDB user is required to extract transactions from the database.');
        DBMS_OUTPUT_PUT_LINE('ALTER SESSION SET CONTAINER = CDB$ROOT;');
        DBMS_OUTPUT_PUT_LINE('CREATE USER '||c_cdb_user||' IDENTIFIED BY "'||c_db_password||'" CONTAINER=ALL DEFAULT TABLESPACE SYSAUX QUOTA UNLIMITED ON SYSAUX;');
        v_is_db_gg_ready := FALSE;
else
        DBMS_OUTPUT_PUT_LINE('-- CDB User already exist or it is not needed for PDB Extract in databases greater then 19c, no action required.');
        DBMS_OUTPUT_PUT_LINE('--');
end if;
    DBMS_OUTPUT_PUT_LINE('--');
end if;


        -- ####### Check if the CDB user already have each Privilege required to
        -- ####### enable GoldenGate
        -- Outer loop iterates through each element in the CDB user Array list
        -- If database is > 19 PDB-Capture only, no need for CDB user
     if v_cdb_user_needed is null then
        FOR i IN 1 .. v_cdb_privs.count
        LOOP
            -- Inner loop iterates through each element in the database list

            FOR privilege_cur IN (
                select granted_role as granted_privs from dba_role_privs where grantee=c_cdb_user
                union
                select privilege as granted_privs from dba_sys_privs where grantee=c_cdb_user order by 1)
            LOOP
                -- Compare the current element in the first list to the current element in the second list
                if privilege_cur.granted_privs = v_cdb_privs(i) then
                    -- DBMS_OUTPUT_PUT_LINE(privilege_cur.granted_privs);
                     v_match_found:= TRUE;
                     exit;
else
                     v_match_found:= FALSE;
end if;
END LOOP ;  --Inner For Loop
            -- Print privileged to be granted not found in the database
            if v_match_found = FALSE then
             -- if v_session_altered_completed is NULL then
             --  DBMS_OUTPUT_PUT_LINE('ALTER SESSION SET CONTAINER = CDB$ROOT;');
             --  v_session_altered_completed := 'TRUE';
             -- end if;

              if (v_cdb_privs(i) <> 'OGG_CAPTURE' and v_cdb_privs(i) <> 'OGG_APPLY' and DBMS_DB_VERSION.VERSION < 23) then
                DBMS_OUTPUT_PUT_LINE('GRANT ' ||v_cdb_privs(i)||' TO '||c_cdb_user||' CONTAINER=ALL;');
              elsif DBMS_DB_VERSION.VERSION >= 23 then
                DBMS_OUTPUT_PUT_LINE('GRANT ' ||v_cdb_privs(i)||' TO '||c_cdb_user||' CONTAINER=ALL;');
end if;
            v_is_db_gg_ready := FALSE;
end if;

END LOOP; -- Outer For Loop

       -- Output the result

        --  Check the DBMS_GOLDENGATE_AUTH.GRANT_ADMIN_PRIVILEGE package has been executed and execute if it's not
      if DBMS_DB_VERSION.VERSION < 23 then
select decode(count(*),1,'YES','NO') into v_cdb_package_executed
from
    (select username from DBA_GOLDENGATE_PRIVILEGES
     where dba_goldengate_privileges.grant_select_privileges = 'YES'
       and dba_goldengate_privileges.privilege_type = '*'
       and upper(dba_goldengate_privileges.username) = upper(c_cdb_user));

if v_cdb_package_executed = 'NO' then
            DBMS_OUTPUT_PUT_LINE('EXEC DBMS_GOLDENGATE_AUTH.GRANT_ADMIN_PRIVILEGE('''||c_cdb_user||''',CONTAINER=>''ALL'');');
            v_is_db_gg_ready := FALSE;
            DBMS_OUTPUT_PUT_LINE('--');
end if; -- Package execution check
end if; -- Package needed check
end if;  -- cdb user is needed


   -- Create User PDB
   if v_pdb_user = 'NO' then
    DBMS_OUTPUT_PUT_LINE('--#######################################################################');
    DBMS_OUTPUT_PUT_LINE('--#### Create and Grant Privileges to the PDB GoldenGate Admin user. ####');
    DBMS_OUTPUT_PUT_LINE('--######################################################################' );
    DBMS_OUTPUT_PUT_LINE('--');
    DBMS_OUTPUT_PUT_LINE('-- GoldenGate PDB User does not exist, create PDB user is required to extract transactions from the database.');
    DBMS_OUTPUT_PUT_LINE('ALTER SESSION SET CONTAINER = '||upper(v_pdb_name)||';');

    if v_pdb_tablespace = 'NO' then
       create_tablespace('PDB');
end if;
    DBMS_OUTPUT_PUT_LINE('CREATE USER '||c_pdb_user||' IDENTIFIED BY "'||c_db_password||'" CONTAINER=CURRENT DEFAULT TABLESPACE '
     ||c_ogg_tablespace||' QUOTA UNLIMITED ON '||c_ogg_tablespace||';');
    v_is_db_gg_ready := FALSE;
else
    DBMS_OUTPUT_PUT_LINE('-- PDB User already exist, no action required.');
end if;
   DBMS_OUTPUT_PUT_LINE('--');

    DBMS_OUTPUT_PUT_LINE('--#######################################################################');
    DBMS_OUTPUT_PUT_LINE('--####     Grant Privileges to the PDB GoldenGate Admin user.        ####');
    DBMS_OUTPUT_PUT_LINE('--#######################################################################');
    DBMS_OUTPUT_PUT_LINE('--');
 --   DBMS_OUTPUT_PUT_LINE('ALTER SESSION SET CONTAINER = '||upper(v_pdb_name)||';');

    -- ####### Check if the PDB user already have each Privilege required to
    -- ####### enable GoldenGate
    -- Outer loop iterates through each element in the PDB user Array list
    v_match_found:= FALSE;
FOR i IN 1 .. v_pdb_privs.count
    LOOP
        -- Inner loop iterates through each element in the database list

        FOR privilege_cur IN (
            select granted_role as granted_privs from cdb_role_privs where grantee=c_pdb_user and con_id = (select con_id from v$pdbs where upper(name) = upper(v_pdb_name))
            union
            select privilege as granted_privs  from cdb_sys_privs where grantee=c_pdb_user and con_id = (select con_id from v$pdbs where upper(name) = upper(v_pdb_name)) order by 1)
        LOOP
            -- Compare the current element in the first list to the current element in the second list
            if privilege_cur.granted_privs = v_pdb_privs(i) then
                -- DBMS_OUTPUT_PUT_LINE(privilege_cur.granted_privs);
                 v_match_found:= TRUE;
                 exit;
else
                 v_match_found:= FALSE;
end if;
END LOOP ;  --Inner For Loop
        -- Print privileged to be granted not found in the database
        --   v_dv_enabled := 'TRUE';
        if v_match_found = FALSE then

            if v_alter_pdb <> 'YES' then
                DBMS_OUTPUT_PUT_LINE('ALTER SESSION SET CONTAINER = '||upper(v_pdb_name)||';');
                v_alter_pdb :='YES';
end if;

            -- Only grant Data Vault roleprivilege if database has Data Vault Enabled.
            if instr(v_pdb_privs(i), 'DV_GOLDENGATE') > 0 and v_dv_enabled = 'TRUE' then
                DBMS_OUTPUT_PUT_LINE('GRANT ' ||v_pdb_privs(i)||' TO '||c_pdb_user||' CONTAINER=CURRENT;');
            elsif ( v_pdb_privs(i) <> 'OGG_CAPTURE' and
                    v_pdb_privs(i) <> 'OGG_APPLY' and
                    instr(v_pdb_privs(i), 'DV_GOLDENGATE') = 0 and
                    DBMS_DB_VERSION.VERSION < 23
                    ) then
                DBMS_OUTPUT_PUT_LINE('GRANT ' ||v_pdb_privs(i)||' TO '||c_pdb_user||' CONTAINER=CURRENT;');
            elsif DBMS_DB_VERSION.VERSION >= 23 and instr(v_pdb_privs(i), 'DV_GOLDENGATE') = 0 then
                DBMS_OUTPUT_PUT_LINE('GRANT ' ||v_pdb_privs(i)||' TO '||c_pdb_user||' CONTAINER=CURRENT;');
end if;
        v_is_db_gg_ready := FALSE;
end if;

END LOOP; -- Outer For Loop

    --  Check the DBMS_GOLDENGATE_AUTH.GRANT_ADMIN_PRIVILEGE package has been executed and execute if it's not
    --Bug 35573835
    if DBMS_DB_VERSION.VERSION < 23 then
select decode(count(*),1,'YES','NO') into v_pdb_package_executed
from
    (select username from CDB_GOLDENGATE_PRIVILEGES
     where cdb_goldengate_privileges.grant_select_privileges = 'YES'
       and cdb_goldengate_privileges.privilege_type = '*'
       and upper(cdb_goldengate_privileges.username) = upper(c_pdb_user)
       and con_id = (select con_id from cdb_pdbs where pdb_name = upper(v_pdb_name)));

if v_pdb_package_executed = 'NO' then
        DBMS_OUTPUT_PUT_LINE('EXEC DBMS_GOLDENGATE_AUTH.GRANT_ADMIN_PRIVILEGE('''||c_pdb_user||''',CONTAINER=>''CURRENT'');');
        v_is_db_gg_ready := FALSE;
        DBMS_OUTPUT_PUT_LINE('--');
end if;
end if;

else
   -- Create User NonCDB
   if v_noncdb_user = 'NO' then
    DBMS_OUTPUT_PUT_LINE('-- GoldenGate User does not exist, creating the database user is required to extract transactions from the database.');
    if v_noncdb_tablespace = 'NO' then
        create_tablespace('nonCDB');
end if;
    DBMS_OUTPUT_PUT_LINE('CREATE USER '||c_noncdb_user||' IDENTIFIED BY "'||c_db_password||'" DEFAULT TABLESPACE '
     ||c_ogg_tablespace||' QUOTA UNLIMITED ON '||c_ogg_tablespace||';');
     v_is_db_gg_ready := FALSE;
else
    DBMS_OUTPUT_PUT_LINE('-- GoldenGate User already exist, no action required.');
end if;
   DBMS_OUTPUT_PUT_LINE('--');

    -- ####### Display all elements of the nonCDB Privilege List
    DBMS_OUTPUT_PUT_LINE('--##########################################################');
    DBMS_OUTPUT_PUT_LINE('--#### Privileges for the NonCDB GOldenGate Admin user. ####');
    DBMS_OUTPUT_PUT_LINE('--##########################################################');
    DBMS_OUTPUT_PUT_LINE('--');

    -- ####### Check if the NonCDB user already have each Privilege required to
    -- ####### enable GoldenGate
    -- Outer loop iterates through each element in the NonCDB(PDB) user Array list
    v_match_found:= FALSE;
FOR i IN 1 .. v_pdb_privs.count
    LOOP
        -- Inner loop iterates through each element in the database list

        FOR privilege_cur IN (
            select granted_role as granted_privs from dba_role_privs where grantee=c_noncdb_user
            union
            select privilege as granted_privs from dba_sys_privs where grantee=c_noncdb_user order by 1)
        LOOP
            -- Compare the current element in the first list to the current element in the second list
            if privilege_cur.granted_privs = v_pdb_privs(i) then
                -- DBMS_OUTPUT_PUT_LINE(privilege_cur.granted_privs);
                 v_match_found:= TRUE;
                 exit;
else
                 v_match_found:= FALSE;
end if;
END LOOP ;  --Inner For Loop
        -- Print privileged to be granted not found in the database
        if v_match_found = FALSE then
            -- Only grant Data Vault roleprivilege if database has Data Vault Enabled.
            if instr(v_pdb_privs(i), 'DV_GOLDENGATE') > 0 and v_dv_enabled = 'TRUE' then
                DBMS_OUTPUT_PUT_LINE('GRANT ' ||v_pdb_privs(i)||' TO '||c_pdb_user||';');
            elsif ( v_pdb_privs(i) <> 'OGG_CAPTURE' and
                    v_pdb_privs(i) <> 'OGG_APPLY' and
                    instr(v_pdb_privs(i), 'DV_GOLDENGATE') = 0 and
                    DBMS_DB_VERSION.VERSION < 23
                    ) then
                DBMS_OUTPUT_PUT_LINE('GRANT ' ||v_pdb_privs(i)||' TO '||c_pdb_user||';');
            elsif DBMS_DB_VERSION.VERSION >= 23 and instr(v_pdb_privs(i), 'DV_GOLDENGATE') = 0 then
                DBMS_OUTPUT_PUT_LINE('GRANT ' ||v_pdb_privs(i)||' TO '||c_pdb_user||';');
end if;

        v_is_db_gg_ready := FALSE;
end if;

END LOOP; -- Outer For Loop

    --  Check the DBMS_GOLDENGATE_AUTH.GRANT_ADMIN_PRIVILEGE package has been executed and execute if it's not
select decode(count(*),1,'YES','NO') into v_noncdb_package_executed
from
    (select username from DBA_GOLDENGATE_PRIVILEGES
     where dba_goldengate_privileges.grant_select_privileges = 'YES'
       and dba_goldengate_privileges.privilege_type = '*'
       and upper(dba_goldengate_privileges.username) = upper(c_noncdb_user));
if v_noncdb_package_executed = 'NO' then
       DBMS_OUTPUT_PUT_LINE('EXEC DBMS_GOLDENGATE_AUTH.GRANT_ADMIN_PRIVILEGE('''||c_noncdb_user||''');');
       v_is_db_gg_ready := FALSE;
       DBMS_OUTPUT_PUT_LINE('--');
end if;
end if;

  -- Display if the database is ready or not for GoldenGate
  DBMS_OUTPUT_PUT_LINE('--');
  DBMS_OUTPUT_PUT_LINE(rpad('--',90,'#'));

  if v_is_db_gg_ready = FALSE then
   DBMS_OUTPUT_PUT_LINE('-- Database Configuration Status for GoldenGate: REQUIRE ATTENTION');
else
   DBMS_OUTPUT_PUT_LINE('-- Database Configuration Status for GoldenGate: READY FOR GOLDENGATE');
end if;

  DBMS_OUTPUT_PUT_LINE(rpad('--',90,'#'));
  DBMS_OUTPUT_PUT_LINE('--');

  -- Generic Exception handler
EXCEPTION
   WHEN c_cdb_user_invalid THEN
      dbms_output_put_line('ORA-20010: CDB User name must be entered!');
WHEN c_pdb_user_invalid THEN
      dbms_output_put_line('ORA-20011: PDB User name must be entered!');
WHEN c_db_password_invalid THEN
      dbms_output_put_line('ORA-20012: PASSWORD must be entered!');
WHEN c_noncdb_user_invalid THEN
     dbms_output_put_line('ORA-20013: Non CDB User name must be entered!');
WHEN c_pdb_service_name_invalid THEN
        DBMS_OUTPUT_PUT_LINE(rpad('--',90,'#'));
        DBMS_OUTPUT_PUT_LINE('--          Database GoldenGate Error  ');
        DBMS_OUTPUT_PUT_LINE(rpad('--',90,'#'));
        DBMS_OUTPUT_PUT_LINE('--');
        DBMS_OUTPUT_PUT_LINE('ORA-20014: The service name '''||upper(c_pdb_service_name)||''' you entered does not exist in the database. Review your SERVICE NAME and try again.');
WHEN no_data_found THEN
        DBMS_OUTPUT_PUT_LINE(rpad('--',90,'#'));
        DBMS_OUTPUT_PUT_LINE('--          Database GoldenGate Error  ');
        DBMS_OUTPUT_PUT_LINE(rpad('--',90,'#'));
        DBMS_OUTPUT_PUT_LINE('--');
        DBMS_OUTPUT_PUT_LINE('ORA-20015: NO DATA FOUND, the service name '''||upper(c_pdb_service_name)||''' you entered does not exist in the database. Review your SERVICE NAME and try again.');
WHEN c_cdb_user_not_needed then
        dbms_output_put_line('ORA-20010: CDB User name is not needed in database greater then 19c');
WHEN TOO_MANY_ROWS then
      RAISE_APPLICATION_ERROR(-20002,'TOO MANY ROWS, Please Report to Oracle Support!');
END;
/

spool off
