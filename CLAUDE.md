# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Home Assistant custom integration for Bosch HomeCom Easy enabled appliances (air conditioners, boilers, heat pumps, water heaters). It integrates with the Bosch SingleKey ID authentication system and communicates with Bosch cloud services to control and monitor devices.

**Integration Type**: Cloud polling (iot_class: cloud_polling)
**External Library**: `homecom_alt` (version >=1.4.13)
**Python Version**: 3.12+
**Home Assistant Integration**: Custom Component

## Development Commands

### Testing
```bash
# Run all tests with coverage
pytest --cov=custom_components --cov-report=term-missing tests

# Run tests using tox
tox -e py312
```

### Linting and Formatting
```bash
# Run all linters
tox -e lint

# Individual tools
flake8 custom_components
isort --check-only --diff custom_components tests
black --check custom_components tests

# Auto-fix formatting
isort custom_components tests
black custom_components tests
```

### Type Checking
```bash
# Run mypy
tox -e type
# or directly
mypy custom_components tests
```

## Architecture

### Core Components

**Coordinator Pattern**: The integration uses Home Assistant's `DataUpdateCoordinator` pattern with device-type-specific coordinators:

- `BoschComModuleCoordinatorRac` - Residential Air Conditioning (rac)
- `BoschComModuleCoordinatorK40` - Boilers and heat pumps (k30, k40, icom)
- `BoschComModuleCoordinatorWddw2` - Water heaters (wddw2)
- `BoschComModuleCoordinatorGeneric` - Fallback for other device types

Each coordinator manages:
- Periodic data updates (default 60 seconds, configurable via options)
- Token refresh and persistence
- Error handling and auth failure recovery

### Authentication Flow

Authentication uses SingleKey ID OAuth-like flow:

1. User initiates config flow (`config_flow.py`)
2. User manually obtains authorization code from browser (see README for detailed steps due to CAPTCHA)
3. Integration exchanges code for access token and refresh token via `homecom_alt.HomeComAlt.create()`
4. Tokens are stored in config entry and automatically refreshed by coordinators

**Token Management**: Only one coordinator per entry is designated as `auth_provider=True` to handle token refresh. Other coordinators reuse tokens from the config entry to avoid concurrent refresh issues.

### Platform Files

The integration creates Home Assistant entities via platform files:

- **climate.py**: Climate entities for RAC and K40/K30/icom devices (HVAC control, temperature, fan modes, presets)
- **sensor.py**: Sensors for notifications, temperatures, operational states
- **select.py**: Dropdown controls for modes (DHW, heating circuits, vertical/horizontal positions)
- **switch.py**: On/off controls (e.g., plasmacluster for RAC)
- **fan.py**: Fan control entities
- **water_heater.py**: Water heater entities for K40 devices

All platforms use `CoordinatorEntity` pattern to automatically receive updates from their coordinator.

### Custom Services

Three custom services are registered in `__init__.py`:

1. **`bosch_homecom.set_dhw_tempreture`**: Set DHW (Domestic Hot Water) temperature for specific levels (eco/low/high)
2. **`bosch_homecom.set_dhw_extrahot_water`**: Control extra hot water charge with duration
3. **`bosch_homecom.get_custom_path_service`**: Query arbitrary API endpoints (returns JSON response)

### Data Flow

```
User/HA → Platform Entity → Coordinator → homecom_alt library → Bosch Cloud API
                                ↓
                        Periodic Updates (60s)
                                ↓
                        Entity State Updates
```

## Device Type Specifics

### RAC (Residential Air Conditioning)
- Climate entity with full HVAC modes, fan control, swing modes, presets
- Select entities for air flow direction (horizontal/vertical)
- Switch for plasmacluster air purification
- Sensor for notifications

### K40/K30/icom (Boilers & Heat Pumps)
- Climate entity for temperature control
- Water heater entity for DHW control
- Multiple select entities (away mode, DHW operation mode, heating circuit mode, heat/cool mode, summer/winter mode, holiday modes)
- Sensors for DHW state, heating circuit state, heat source metrics (modulation, temperatures, start counts, etc.)

### WDDW2 (Water Heaters)
- Select entities for DHW control
- Sensors for temperatures (air box, inlet, outlet), water flow, heat source starts

## Important Patterns

### Async Throughout
All I/O operations are async. Never use blocking calls. All entity methods that interact with the API should be async.

### Update Interval Configuration
The update interval is configurable via options flow (setup.cfg specifies min 15s, max 3600s). Changes to options dynamically update all coordinator intervals via the update listener in `__init__.py:206-211`.

### Error Handling
- `ApiError`, `InvalidSensorDataError`, `RetryError` → `UpdateFailed` (coordinator continues retrying)
- `AuthFailedError` → triggers reauth flow
- Firmware fetch 504 errors → logged as warning, firmware set to "unknown"

### Multi-Device Support
A single config entry can manage multiple devices. Each device gets its own coordinator instance, stored in `entry.runtime_data` as a list.

### Device Registry Integration
Each coordinator creates a device in Home Assistant's device registry with manufacturer="Bosch", model based on device type (see `const.MODEL`), and firmware version.

## Testing Patterns

Tests use `pytest-homeassistant-custom-component` which provides Home Assistant test fixtures:

- `auto_enable_custom_integrations` fixture enables the custom integration
- Mock the `homecom_alt` library responses when testing flows and coordinators
- Test fixtures are in `tests/conftest.py`
- Thread cleanup for pycares is handled in `whitelist_pycares_shutdown_thread` fixture

## Key Constants

Located in `const.py`:

- `DOMAIN = "bosch_homecom"`
- `DEFAULT_UPDATE_INTERVAL = 60 seconds`
- `MODEL` dict maps device types to human-readable names
- `BOSCH_SENSOR_DESCRIPTORS` defines sensor configurations per device type
- Attribute names for various device properties (mode, speed, temperature, etc.)

## Integration Manifest

Key dependencies and metadata in `manifest.json`:

- Domain: `bosch_homecom`
- Config flow: enabled
- Requirements: `homecom_alt>=1.4.13`
- Loggers: `custom_components.bosch_homecom`, `homecom_alt`
- IoT class: `cloud_polling`

## Notes for Development

- When adding new device types, create a new coordinator class if the data structure differs significantly
- New entity platforms require adding to `PLATFORMS` list in `__init__.py`
- Authentication is sensitive - never commit credentials, use mock data in tests
- The integration updates state both on user actions AND on the periodic coordinator refresh
- Use `_LOGGER` (module-level logger) for all logging, not print statements
