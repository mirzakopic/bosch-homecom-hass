#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Load environment variables from .env if it exists
if [ -f .env ]; then
    echo -e "${GREEN}Loading environment variables from .env${NC}"
    export $(cat .env | grep -v '^#' | xargs)
else
    echo -e "${YELLOW}No .env file found, using defaults${NC}"
    echo -e "${YELLOW}Copy .env.example to .env to customize settings${NC}"
fi

# Default values
HA_CONFIG_DIR=${HA_CONFIG_DIR:-./dev_config}
HA_PORT=${HA_PORT:-8123}
LOG_LEVEL=${LOG_LEVEL:-debug}
BOSCH_LOG_LEVEL=${BOSCH_LOG_LEVEL:-debug}
TZ=${TZ:-UTC}

VENV_DIR="./venv"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}Bosch HomeCom HA Development Setup${NC}"
echo -e "${BLUE}======================================${NC}\n"

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check Python version
echo -e "${GREEN}[1/7] Checking Python version...${NC}"
if ! command_exists python3.12; then
    if command_exists python3; then
        PYTHON_VERSION=$(python3 --version | cut -d' ' -f2 | cut -d'.' -f1,2)
        echo -e "${YELLOW}Python 3.12 not found, using python3 (version $PYTHON_VERSION)${NC}"
        PYTHON_CMD="python3"
    else
        echo -e "${RED}Error: Python 3.12+ is required${NC}"
        exit 1
    fi
else
    PYTHON_CMD="python3.12"
fi

# Create virtual environment if it doesn't exist
echo -e "${GREEN}[2/7] Setting up virtual environment...${NC}"
if [ ! -d "$VENV_DIR" ]; then
    echo "Creating virtual environment..."
    $PYTHON_CMD -m venv "$VENV_DIR"
else
    echo "Virtual environment already exists"
fi

# Activate virtual environment
source "$VENV_DIR/bin/activate"

# Upgrade pip
echo -e "${GREEN}[3/7] Upgrading pip...${NC}"
pip install --upgrade pip > /dev/null

# Install dependencies
echo -e "${GREEN}[4/7] Installing dependencies...${NC}"
echo "Installing Home Assistant..."
pip install homeassistant > /dev/null

echo "Installing integration dependencies..."
pip install homecom_alt>=1.4.13 > /dev/null

echo "Installing development dependencies..."
if [ -f requirements.test.txt ]; then
    pip install -r requirements.test.txt > /dev/null
fi

# Set up Home Assistant config directory
echo -e "${GREEN}[5/7] Setting up Home Assistant config directory...${NC}"
mkdir -p "$HA_CONFIG_DIR"
mkdir -p "$HA_CONFIG_DIR/custom_components"

# Create symlink to custom component
if [ -L "$HA_CONFIG_DIR/custom_components/bosch_homecom" ]; then
    echo "Symlink already exists"
elif [ -d "$HA_CONFIG_DIR/custom_components/bosch_homecom" ]; then
    echo "Directory already exists, removing..."
    rm -rf "$HA_CONFIG_DIR/custom_components/bosch_homecom"
    ln -s "$SCRIPT_DIR/custom_components/bosch_homecom" "$HA_CONFIG_DIR/custom_components/bosch_homecom"
else
    echo "Creating symlink to custom component..."
    ln -s "$SCRIPT_DIR/custom_components/bosch_homecom" "$HA_CONFIG_DIR/custom_components/bosch_homecom"
fi

# Create configuration.yaml if it doesn't exist
echo -e "${GREEN}[6/7] Creating configuration.yaml...${NC}"
if [ ! -f "$HA_CONFIG_DIR/configuration.yaml" ]; then
    cat > "$HA_CONFIG_DIR/configuration.yaml" << EOF
# Home Assistant Development Configuration
# Loads of default config
default_config:

# Text to speech
tts:
  - platform: google_translate

# Logger configuration for development
logger:
  default: ${LOG_LEVEL}
  logs:
    custom_components.bosch_homecom: ${BOSCH_LOG_LEVEL}
    homecom_alt: ${BOSCH_LOG_LEVEL}

# Enable the auth system
homeassistant:
  auth_providers:
    - type: homeassistant

# HTTP configuration
http:
  server_port: ${HA_PORT}
EOF
    echo "Configuration file created at $HA_CONFIG_DIR/configuration.yaml"
else
    echo "Configuration file already exists"
fi

# Create .storage directory with onboarding complete
echo -e "${GREEN}[7/7] Finalizing setup...${NC}"
mkdir -p "$HA_CONFIG_DIR/.storage"

# Check if onboarding is needed
if [ ! -f "$HA_CONFIG_DIR/.storage/onboarding" ]; then
    echo "Setting up onboarding completion..."
    cat > "$HA_CONFIG_DIR/.storage/onboarding" << 'EOF'
{
  "version": 3,
  "minor_version": 1,
  "key": "onboarding",
  "data": {
    "done": [
      "user",
      "core_config",
      "analytics"
    ]
  }
}
EOF
fi

echo -e "\n${GREEN}======================================${NC}"
echo -e "${GREEN}Setup Complete!${NC}"
echo -e "${GREEN}======================================${NC}\n"

echo -e "${BLUE}Configuration:${NC}"
echo -e "  Config directory: ${YELLOW}$HA_CONFIG_DIR${NC}"
echo -e "  Port: ${YELLOW}$HA_PORT${NC}"
echo -e "  Log level: ${YELLOW}$LOG_LEVEL${NC}"
echo -e "  Bosch integration log: ${YELLOW}$BOSCH_LOG_LEVEL${NC}\n"

echo -e "${BLUE}Next steps:${NC}"
echo -e "1. Start Home Assistant with: ${YELLOW}./dev_run.sh${NC}"
echo -e "2. Open browser to: ${YELLOW}http://localhost:$HA_PORT${NC}"
echo -e "3. Complete onboarding (create admin user)"
echo -e "4. Go to Settings → Devices & Services → Add Integration"
echo -e "5. Search for 'Bosch HomeCom' and follow authentication steps\n"

echo -e "${YELLOW}To get authorization code:${NC}"
echo -e "See README.md for detailed authentication instructions"
echo -e "Or run: ${YELLOW}cat README.md | grep -A 20 'Step-by-Step Instructions'${NC}\n"

echo -e "${GREEN}Creating dev_run.sh script...${NC}"
cat > dev_run.sh << 'RUNSCRIPT'
#!/bin/bash
# Load environment variables
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

HA_CONFIG_DIR=${HA_CONFIG_DIR:-./dev_config}
VENV_DIR="./venv"

# Activate virtual environment
source "$VENV_DIR/bin/activate"

echo "Starting Home Assistant..."
echo "Config directory: $HA_CONFIG_DIR"
echo "Press Ctrl+C to stop"
echo ""

# Start Home Assistant
hass -c "$HA_CONFIG_DIR" --debug
RUNSCRIPT

chmod +x dev_run.sh

echo -e "${GREEN}Development environment is ready!${NC}"
echo -e "Run ${YELLOW}./dev_run.sh${NC} to start Home Assistant\n"
