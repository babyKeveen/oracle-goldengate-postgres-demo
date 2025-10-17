#!/bin/bash
set -euo pipefail
[[ "${RUN_SETUP_ON_START:-0}" = "1" ]] && \
  "$ORACLE_BASE/$USER_SCRIPTS_FILE" "$ORACLE_BASE/scripts/setup"

