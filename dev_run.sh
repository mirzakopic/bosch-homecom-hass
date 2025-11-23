#!/bin/bash
# Load environment variables
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

HA_CONFIG_DIR=${HA_CONFIG_DIR:-./dev_config}
VENV_DIR="./venv"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check if setup has been run
if [ ! -d "$VENV_DIR" ]; then
    echo -e "${YELLOW}Virtual environment not found. Running setup...${NC}"
    ./dev_setup.sh
    exit 0
fi

# Activate virtual environment
source "$VENV_DIR/bin/activate"

echo -e "${GREEN}Starting Home Assistant...${NC}"
echo -e "Config directory: ${YELLOW}$HA_CONFIG_DIR${NC}"
echo -e "Press ${YELLOW}Ctrl+C${NC} to stop"
echo ""

# Start Home Assistant
hass -c "$HA_CONFIG_DIR" --debug
