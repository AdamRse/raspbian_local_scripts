#!/bin/bash

SCRIPT_PATH=$(readlink -f "$0")
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")

source "${SCRIPT_DIR}/.env"
source "${SCRIPT_DIR}/fct/terminal-tools.fct.sh"
source "${SCRIPT_DIR}/fct/lampe_cycle.fct.sh"

echo "Script dir : $SCRIPT_DIR"