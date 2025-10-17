#!/bin/bash

# Oracle Wallet Creation Script
# This script creates an Oracle Wallet for passwordless authentication

WALLET_DIR="/opt/oracle/scripts/configs/wallet"
WALLET_PASSWORD="WalletPass123!"

echo "=== Creating Oracle Wallet ==="

# Create wallet directory if it doesn't exist
mkdir -p $WALLET_DIR

# Create the wallet
echo "Creating wallet..."
mkstore -wrl $WALLET_DIR -create <<EOF
$WALLET_PASSWORD
$WALLET_PASSWORD
EOF

# Add credentials for different connection scenarios
echo "Adding credentials to wallet..."

# Add credentials for SYS user connecting to CDB (FREE)
mkstore -wrl $WALLET_DIR -createCredential FREE sys Oracle123! <<EOF
$WALLET_PASSWORD
EOF

# Add credentials for SYS user connecting to PDB (FREEPDB1) 
mkstore -wrl $WALLET_DIR -createCredential FREEPDB1 sys Oracle123! <<EOF
$WALLET_PASSWORD
EOF

# Add credentials for SYS user with SYSDBA privilege
mkstore -wrl $WALLET_DIR -createCredential FREE_SYSDBA sys Oracle123! <<EOF
$WALLET_PASSWORD
EOF

mkstore -wrl $WALLET_DIR -createCredential FREEPDB1_SYSDBA sys Oracle123! <<EOF
$WALLET_PASSWORD
EOF

# Add credentials for testuser
mkstore -wrl $WALLET_DIR -createCredential FREEPDB1_TESTUSER testuser "Test123!" <<EOF
$WALLET_PASSWORD
EOF

# Add credentials for ggadmin 
mkstore -wrl $WALLET_DIR -createCredential FREEPDB1_GGADMIN ggadmin Oracle123! <<EOF
$WALLET_PASSWORD
EOF

echo "=== Wallet creation complete ==="

# List wallet contents
echo "Wallet contents:"
mkstore -wrl $WALLET_DIR -listCredential <<EOF
$WALLET_PASSWORD
EOF

# Set proper permissions
chmod 600 $WALLET_DIR/*
chown oracle:oinstall $WALLET_DIR/*

echo "=== Oracle Wallet setup finished ==="