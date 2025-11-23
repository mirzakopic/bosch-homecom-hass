# Local Development Setup

This guide explains how to run and test the Bosch HomeCom integration locally.

## Quick Start

```bash
# One-time setup
./dev_setup.sh

# Start Home Assistant
./dev_run.sh
```

That's it! Home Assistant will start on `http://localhost:8123` with the integration installed.

## What Gets Set Up

The setup script automatically:
- ✅ Creates a Python virtual environment (`venv/`)
- ✅ Installs Home Assistant and all dependencies
- ✅ Creates a development config directory (`dev_config/`)
- ✅ Symlinks the integration to `dev_config/custom_components/bosch_homecom`
- ✅ Generates a `configuration.yaml` with debug logging enabled
- ✅ Prepares onboarding so you can quickly create an admin user

## Configuration

### Using .env File (Optional)

Copy `.env.example` to `.env` to customize:

```bash
cp .env.example .env
```

Available options:
- `HA_CONFIG_DIR` - Config directory (default: `./dev_config`)
- `HA_PORT` - Web server port (default: `8123`)
- `LOG_LEVEL` - Global log level (default: `debug`)
- `BOSCH_LOG_LEVEL` - Integration log level (default: `debug`)
- `TZ` - Timezone (default: `UTC`)

### Default Configuration

Without a `.env` file, the setup uses these defaults:
- Config directory: `./dev_config/`
- Port: `8123`
- Log level: `debug`

## Authentication Setup

After starting Home Assistant:

1. **Complete Onboarding:**
   - Open `http://localhost:8123`
   - Create an admin account
   - Complete the setup wizard

2. **Get Authorization Code:**
   - Open this URL in your browser:
     ```
     https://singlekey-id.com/auth/connect/authorize?state=nKqS17oMAxqUsQpMznajIr&nonce=5yPvyTqMS3iPb4c8RfGJg1&code_challenge=Fc6eY3uMBJkFqa4VqcULuLuKC5Do70XMw7oa_Pxafw0&redirect_uri=com.bosch.tt.dashtt.pointt://app/login&client_id=762162C0-FA2D-4540-AE66-6489F189FADC&response_type=code&prompt=login&scope=openid+email+profile+offline_access+pointt.gateway.claiming+pointt.gateway.removal+pointt.gateway.list+pointt.gateway.users+pointt.gateway.resource.dashapp+pointt.castt.flow.token-exchange+bacon+hcc.tariff.read&code_challenge_method=S256&style_id=tt_bsch
     ```
   - Open Browser DevTools (F12) → Network tab
   - Log in with your Bosch credentials
   - Complete the CAPTCHA
   - Look for the failed redirect in Network tab
   - Copy the `code` parameter (ends with `-1`)

3. **Add Integration:**
   - In Home Assistant: Settings → Devices & Services → Add Integration
   - Search for "Bosch HomeCom"
   - Enter your username
   - Paste the authorization code
   - Select which devices to add

## Development Workflow

### Making Changes

```bash
# 1. Edit code in custom_components/bosch_homecom/
vim custom_components/bosch_homecom/sensor.py

# 2. Restart Home Assistant
# Press Ctrl+C to stop
./dev_run.sh

# Or restart from UI: Developer Tools → Restart
```

### Viewing Logs

**Console Output:**
```bash
# Logs are shown in the terminal where dev_run.sh is running
# Debug level is enabled by default
```

**Log Files:**
```bash
# View log file
tail -f dev_config/home-assistant.log

# View only Bosch integration logs
tail -f dev_config/home-assistant.log | grep bosch_homecom
```

**UI Logs:**
- Settings → System → Logs
- Filter for `bosch_homecom` or `homecom_alt`

### Testing Changes

**Via UI:**
- Use Developer Tools → Services to call custom services
- Check entity states in Developer Tools → States
- View device details in Settings → Devices & Services

**Via API:**
```bash
# Get entity states
curl -X GET \
  -H "Authorization: Bearer YOUR_TOKEN" \
  http://localhost:8123/api/states

# Call a service
curl -X POST \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"entity_id": "climate.your_device"}' \
  http://localhost:8123/api/services/climate/turn_on
```

### Running Tests

```bash
# Activate virtual environment
source venv/bin/activate

# Run all tests
pytest --cov=custom_components --cov-report=term-missing tests

# Run specific test
pytest tests/test_config_flow.py -v
```

## Troubleshooting

### Port Already in Use

Change the port in `.env`:
```bash
echo "HA_PORT=8124" > .env
```

### Import Errors

Reinstall dependencies:
```bash
source venv/bin/activate
pip install --upgrade homeassistant homecom_alt
```

### Integration Not Loading

Check logs for errors:
```bash
tail -n 100 dev_config/home-assistant.log | grep -i error
```

### Symlink Issues (Windows)

On Windows, symlinks may require admin privileges. Use copy instead:
```bash
cp -r custom_components/bosch_homecom dev_config/custom_components/
```

### Authentication Fails

1. Verify you copied the correct code (ends with `-1`)
2. Make sure the code hasn't expired (they're time-limited)
3. Check logs for API errors
4. Try generating a new code

## Clean Up

To remove the development environment:

```bash
# Remove virtual environment
rm -rf venv/

# Remove development config
rm -rf dev_config/

# Remove environment file
rm .env
```

## Additional Resources

- [Home Assistant Developer Docs](https://developers.home-assistant.io/)
- [Integration Development](https://developers.home-assistant.io/docs/creating_integration_manifest)
- [Testing Integrations](https://developers.home-assistant.io/docs/development_testing)
