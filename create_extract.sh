#!/bin/bash

# ============================================================================
# GoldenGate Extract Creation Script
# This script automates the creation of GG extract procedures
# ============================================================================

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
EXTRACT_NAME=${1:-"EXTFREE"}
TRAIL_PATH=${2:-"./dirdat/ea"}
TABLE_OWNER=${3:-"GGUSER"}
TABLE_NAME=${4:-"EMPLOYEES"}

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if containers are running
check_containers() {
    print_status "Checking Docker containers..."
    
    if ! docker compose ps | grep -q "oracle-free.*Up"; then
        print_error "Oracle Free container is not running"
        print_status "Starting containers..."
        docker compose up -d
        
        print_status "Waiting for Oracle to be ready..."
        sleep 30
    else
        print_success "Oracle Free container is running"
    fi
    
    if ! docker compose ps | grep -q "goldengate.*Up"; then
        print_error "GoldenGate container is not running"
        return 1
    else
        print_success "GoldenGate container is running"
    fi
}

# Function to install the procedure in Oracle
install_procedure() {
    print_status "Installing GoldenGate extract procedure in Oracle..."
    
    # Create procedures directory if it doesn't exist
    mkdir -p procedures
    
    # Execute the procedure creation script
    if docker compose exec -T oracle-free sqlplus -s sys/Oracle123!@//localhost:1521/FREEPDB1 AS SYSDBA < procedures/create_gg_extract.sql; then
        print_success "Procedure installed successfully"
        return 0
    else
        print_error "Failed to install procedure"
        return 1
    fi
}

# Function to execute the extract creation procedure
create_extract() {
    print_status "Creating GoldenGate extract: $EXTRACT_NAME"
    print_status "Parameters:"
    print_status "  Extract Name: $EXTRACT_NAME"
    print_status "  Trail Path: $TRAIL_PATH"
    print_status "  Table: $TABLE_OWNER.$TABLE_NAME"
    
    # Create SQL command to execute the procedure
    SQL_CMD="SET SERVEROUTPUT ON;
EXEC create_gg_extract('$EXTRACT_NAME', '$TRAIL_PATH', '$TABLE_OWNER', '$TABLE_NAME', TRUE);
EXIT;"
    
    # Execute the procedure
    if echo "$SQL_CMD" | docker compose exec -T oracle-free sqlplus -s ggadmin/GGAdmin123!@//localhost:1521/FREEPDB1; then
        print_success "Extract creation procedure completed successfully"
        return 0
    else
        print_error "Failed to execute extract creation procedure"
        return 1
    fi
}

# Function to check extract status
check_status() {
    print_status "Checking extract status for: $EXTRACT_NAME"
    
    # Check containers first
    print_status "Container Status:"
    docker compose ps
    
    echo ""
    print_status "Database Connection Test:"
    if docker compose exec -T oracle-free timeout 5 sqlplus -s ggadmin/GGAdmin123!@//localhost:1521/FREEPDB1 <<< "SELECT 'Oracle Connected' FROM dual; EXIT;" 2>/dev/null | grep -q "Oracle Connected"; then
        print_success "Oracle database connection: OK"
    else
        print_error "Oracle database connection: Failed"
        return 1
    fi
    
    echo ""
    print_status "GoldenGate Extract Status:"
    
    # Check if extract exists in GoldenGate using admin client
    docker compose exec --user ogg -T goldengate timeout 10 /u01/ogg/bin/adminclient <<EOF 2>/dev/null || echo "Admin client check completed"
CONNECT http://localhost:80/oggf as ggadmin password "GGAdmin123!"
INFO EXTRACT $EXTRACT_NAME
EXIT
EOF

    echo ""
    print_status "Database-level checks (using ggadmin):"
    
    # Simple database checks using ggadmin user
    SQL_CMD="SET PAGESIZE 0
SET FEEDBACK OFF
SET HEADING ON
SELECT 'Database Status:' as info FROM dual;
SELECT log_mode FROM v\$database;
SELECT 'Supplemental Logging:' as info FROM dual;
SELECT supplemental_log_data_min FROM v\$database;
EXIT;"
    
    echo "$SQL_CMD" | docker compose exec -T oracle-free sqlplus -s ggadmin/GGAdmin123!@//localhost:1521/FREEPDB1 2>/dev/null || echo "Database check completed"
    
    echo ""
    print_status "For detailed extract status, use: INFO EXTRACT $EXTRACT_NAME in GoldenGate Admin Client"
}

# Function to show GoldenGate commands
show_gg_commands() {
    print_status "GoldenGate Admin Client Commands:"
    echo ""
    echo "1. Connect to GoldenGate container:"
    echo "   docker compose exec goldengate bash"
    echo ""
    echo "2. Start admin client:"
    echo "   /opt/oracle/ogg/bin/adminclient"
    echo ""
    echo "3. Connect to GoldenGate service:"
    echo "   CONNECT http://localhost:80/oggf AS ggadmin PASSWORD GGAdmin123!"
    echo ""
    echo "4. Create credential store (if not exists):"
    echo "   DBLOGIN USERID gguser@oracle-free:1521/FREEPDB1, PASSWORD \"GGUser123!\""
    echo "   ADD CREDENTIALSTORE"
    echo "   ALTER CREDENTIALSTORE ADD USER gguser@oracle-free:1521/FREEPDB1, PASSWORD \"GGUser123!\" ALIAS oracle_free"
    echo ""
    echo "5. Create and start extract:"
    echo "   DBLOGIN USERIDALIAS oracle_free"
    echo "   ADD EXTRACT $EXTRACT_NAME, INTEGRATED TRANLOG, BEGIN NOW"
    echo "   ADD EXTTRAIL $TRAIL_PATH, EXTRACT $EXTRACT_NAME, MEGABYTES 100"
    echo "   START EXTRACT $EXTRACT_NAME"
    echo ""
    echo "6. Verify extract:"
    echo "   INFO EXTRACT $EXTRACT_NAME"
    echo "   STATS EXTRACT $EXTRACT_NAME"
    echo ""
}

# Function to cleanup extract
cleanup_extract() {
    print_warning "Cleaning up extract: $EXTRACT_NAME"
    
    SQL_CMD="SET SERVEROUTPUT ON;
EXEC cleanup_gg_extract('$EXTRACT_NAME');
EXIT;"
    
    echo "$SQL_CMD" | docker compose exec -T oracle-free sqlplus -s ggadmin/GGAdmin123!@//localhost:1521/FREEPDB1
}

# Function to show help
show_help() {
    echo "GoldenGate Extract Creation Script"
    echo ""
    echo "Usage: $0 [extract_name] [trail_path] [table_owner] [table_name] [action]"
    echo ""
    echo "Parameters:"
    echo "  extract_name  : Name of the extract (default: EXTFREE)"
    echo "  trail_path    : Trail file path (default: ./dirdat/ea)"
    echo "  table_owner   : Owner of source table (default: GGUSER)"
    echo "  table_name    : Name of source table (default: EMPLOYEES)"
    echo ""
    echo "Actions:"
    echo "  --install     : Install the procedure only"
    echo "  --create      : Create the extract (default)"
    echo "  --status      : Check extract status"
    echo "  --cleanup     : Cleanup extract"
    echo "  --commands    : Show GoldenGate commands"
    echo "  --help        : Show this help"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Create extract with defaults"
    echo "  $0 MYEXT ./dirdat/my GGUSER ORDERS   # Create custom extract"
    echo "  $0 EXTFREE ./dirdat/ea GGUSER EMPLOYEES --status  # Check status"
    echo ""
}

# Main execution logic
main() {
    # Check for help parameter
    if [[ "$*" == *"--help"* ]]; then
        show_help
        exit 0
    fi
    
    # Check for action parameters first, before setting positional parameters
    if [[ "$*" == *"--install"* ]]; then
        check_containers && install_procedure
        exit $?
    elif [[ "$*" == *"--status"* ]]; then
        # Reset parameters to defaults for status check
        EXTRACT_NAME="EXTFREE"
        TRAIL_PATH="./dirdat/ea"
        TABLE_OWNER="GGUSER"
        TABLE_NAME="EMPLOYEES"
        check_status
        exit 0
    elif [[ "$*" == *"--cleanup"* ]]; then
        cleanup_extract
        exit 0
    elif [[ "$*" == *"--commands"* ]]; then
        show_gg_commands
        exit 0
    fi
    
    # Default action: create extract
    print_status "Starting GoldenGate Extract Creation Process..."
    echo "=============================================="
    
    # Check containers
    if ! check_containers; then
        print_error "Container check failed"
        exit 1
    fi
    
    # Install procedure
    if ! install_procedure; then
        print_error "Procedure installation failed"
        exit 1
    fi
    
    # Create extract
    if ! create_extract; then
        print_error "Extract creation failed"
        exit 1
    fi
    
    echo ""
    print_success "Database preparation completed successfully!"
    echo ""
    show_gg_commands
}

# Execute main function
main "$@"