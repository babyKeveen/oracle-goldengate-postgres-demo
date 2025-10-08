#!/bin/bash

echo "🚀 Starting Oracle Enterprise Edition + GoldenGate Environment"
echo "=============================================================="

# Check if user is logged into Oracle Container Registry
echo "📝 Checking Oracle Container Registry login..."
if ! docker login container-registry.oracle.com --help > /dev/null 2>&1; then
    echo "❌ Please login to Oracle Container Registry first:"
    echo "   docker login container-registry.oracle.com"
    echo "   Username: Your Oracle Account Email"
    echo "   Password: Your Oracle Account Password"
    echo ""
    echo "💡 You also need to accept the Enterprise Edition license at:"
    echo "   https://container-registry.oracle.com"
    exit 1
fi

echo "✅ Oracle Container Registry login detected"

echo ""
echo "🐳 Starting Oracle Enterprise Edition (this may take 5-10 minutes)..."
docker-compose up -d oracle-ee

echo ""
echo "⏳ Waiting for Oracle EE to be healthy..."
echo "   You can monitor progress with: docker-compose logs -f oracle-ee"

# Wait for Oracle EE to be healthy
MAX_WAIT=900  # 15 minutes
WAIT_TIME=0
while [ $WAIT_TIME -lt $MAX_WAIT ]; do
    if docker-compose ps oracle-ee | grep -q "healthy"; then
        echo "✅ Oracle EE is healthy!"
        break
    fi
    echo "   Still waiting... (${WAIT_TIME}s elapsed)"
    sleep 30
    WAIT_TIME=$((WAIT_TIME + 30))
done

if [ $WAIT_TIME -ge $MAX_WAIT ]; then
    echo "❌ Oracle EE failed to start within 15 minutes"
    echo "   Check logs: docker-compose logs oracle-ee"
    exit 1
fi

echo ""
echo "🔧 Running GoldenGate setup script..."
docker exec -i oracle-ee-source sqlplus /nolog @/docker-entrypoint-initdb.d/startup/01_setup_goldengate_user.sql || true

echo ""
echo "🐳 Starting GoldenGate for Oracle EE..."
docker-compose up -d goldengate-oracle-ee

echo ""
echo "⏳ Waiting for GoldenGate EE to be healthy..."
sleep 30
while ! docker-compose ps goldengate-oracle-ee | grep -q "healthy"; do
    echo "   Still waiting for GoldenGate EE..."
    sleep 15
done

echo "✅ GoldenGate EE is healthy!"

echo ""
echo "🎉 Oracle Enterprise Edition Environment Ready!"
echo "============================================="
echo ""
echo "📊 Connection Details:"
echo "   Oracle EE CDB:  sqlplus sys/Oracle123!@localhost:1522/ORCL as sysdba"
echo "   Oracle EE PDB:  sqlplus sys/Oracle123!@localhost:1522/ORCLPDB1 as sysdba"
echo "   Test User:      sqlplus testuser/Test123!@localhost:1522/ORCLPDB1"
echo "   GG User:        sqlplus gguser/Oracle123!@localhost:1522/ORCLPDB1"
echo ""
echo "🌐 Web Interfaces:"
echo "   Oracle EM:      http://localhost:5501/em"
echo "   GoldenGate EE:  http://localhost:9110"
echo ""
echo "🔧 GoldenGate AdminClient:"
echo "   docker exec -it gg-oracle-ee-extract /u01/ogg/bin/adminclient"
echo "   CONNECT http://localhost:9011 as oggadmin password \"Oracle123!\""
echo ""
echo "💡 Next Steps:"
echo "   1. Test GoldenGate Extract with Enterprise Edition"
echo "   2. Configure PostgreSQL Replicat"
echo "   3. Test end-to-end replication"
echo ""
echo "🆚 Compare with XE environment (still running on ports 1521, 9100)"