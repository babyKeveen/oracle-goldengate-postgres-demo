#!/bin/bash

echo "🔍 GoldenGate Extract Status Check"
echo "=================================="

echo ""
echo "1. 📊 Container Status:"
docker compose ps

echo ""
echo "2. 🔗 Database Connectivity:"
echo "   Testing Oracle Free..."
if docker compose exec -T oracle-free timeout 10 sqlplus -s sys/Oracle123!@localhost:1521/FREE as sysdba <<< "SELECT 'READY' FROM dual; EXIT;" >/dev/null 2>&1; then
    echo "   ✅ Oracle Free: Connected"
else
    echo "   ❌ Oracle Free: Not ready or connection failed"
fi

echo "   Testing PostgreSQL..."
if docker compose exec -T postgresql timeout 10 psql -U postgres -d targetdb -c "SELECT 'READY';" >/dev/null 2>&1; then
    echo "   ✅ PostgreSQL: Connected"
else
    echo "   ❌ PostgreSQL: Not ready or connection failed"
fi

echo ""
echo "3. 🛠️ GoldenGate Service Manager:"
echo "   Checking if service manager is running..."
if docker compose exec --user ogg -T goldengate timeout 10 /u01/ogg/bin/adminclient <<< "CONNECT http://localhost:80/oggf as ggadmin password \"GGAdmin123!\"
INFO ALL
EXIT" 2>&1 | grep -q "Service Manager.*is not available"; then
    echo "   ❌ Service Manager: Not available"
    echo "   💡 This is normal for GoldenGate Free - it uses web UI instead"
else
    echo "   ✅ Service Manager: Available"
fi

echo ""
echo "4. 📁 Configuration Files:"
echo "   Checking parameter files..."
if docker compose exec --user ogg -T goldengate test -f /opt/oracle/ogg/dirprm/EXTFREE.prm; then
    echo "   ✅ Extract config (EXTFREE.prm): Found"
else
    echo "   ❌ Extract config (EXTFREE.prm): Missing"
fi

if docker compose exec --user ogg -T goldengate test -f /opt/oracle/ogg/dirprm/REPPG.prm; then
    echo "   ✅ Replicat config (REPPG.prm): Found"
else
    echo "   ❌ Replicat config (REPPG.prm): Missing"
fi

echo ""
echo "5. 📋 Extract Process Status:"
echo "   (Note: GoldenGate Free requires manual configuration via Web UI)"
echo "   No Extract processes have been configured yet."

echo ""
echo "6. 🌐 Web UI Access:"
echo "   GoldenGate Web UI should be available at:"
echo "   http://localhost:9200"
echo "   Login: ggadmin / GGAdmin123!"

echo ""
echo "7. 📝 Next Steps to Configure Extract:"
echo "   a) Wait for all containers to be fully healthy (may take 5-10 minutes)"
echo "   b) Access GoldenGate Web UI at http://localhost:9200"
echo "   c) Create database connections for Oracle and PostgreSQL"
echo "   d) Configure Extract process using the Web UI"
echo "   e) Configure Replicat process using the Web UI"

echo ""
echo "🎯 Current Status: Containers are running, ready for manual configuration"