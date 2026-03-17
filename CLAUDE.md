# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Install dependencies
make install

# Run tests
make pytest              # standard test suite
make pytest-slow         # slow/marked tests with verbose output
make coverage            # tests with coverage

# Lint and format
make format              # ruff format + isort
make lint                # ruff + pylint
make ruff-lint           # ruff only
make pylint              # pylint only

# Docs
make build-docs
```

**Run a single test file:**
```bash
pytest tests/unit/test_environment.py -v
```

**Run a single test by name:**
```bash
pytest tests/unit/test_environment.py::test_methodname_expectedbehaviour -v
```

## Architecture

RocketPy simulates 6-DOF rocket trajectories. The core workflow is linear:

```
Environment → Motor → Rocket → Flight
```

**`rocketpy/environment/`** — Atmospheric models, weather data fetching (NOAA, Wyoming soundings, GFS forecasts). The `Environment` class (~116KB) is the entry point for atmospheric conditions.

**`rocketpy/motors/`** — `Motor` is the base class. `SolidMotor`, `HybridMotor`, and `LiquidMotor` extend it. `Tank`, `TankGeometry`, and `Fluid` support liquid/hybrid propellant modeling.

**`rocketpy/rocket/`** — `Rocket` aggregates a motor and aerodynamic surfaces. `aero_surface/` contains fins, nose cone, and tail implementations. `Parachute` uses trigger functions for deployment.

**`rocketpy/simulation/`** — `Flight` (~162KB) is the simulation engine, integrating equations of motion with scipy's LSODA solver. `MonteCarlo` orchestrates many `Flight` runs for dispersion analysis.

**`rocketpy/stochastic/`** — Wraps any component (Environment, Rocket, Motor, Flight) with uncertainty distributions for Monte Carlo input generation.

**`rocketpy/mathutils/`** — `Function` class wraps callable data (arrays, lambdas, files) with interpolation and mathematical operations. Heavily used throughout for aerodynamic curves, thrust profiles, etc.

**`rocketpy/plots/` and `rocketpy/prints/`** — Visualization and text output, each mirroring the module structure of the core classes.

**`rocketpy/sensors/`** — Simulated sensors (accelerometer, gyroscope, barometer, GNSS) that can be attached to a `Rocket`.

**`rocketpy/sensitivity/`** — Global sensitivity analysis via `SensitivityModel`.

## Coding Standards

- **Docstrings:** NumPy style with `Parameters`, `Returns`, and `Examples` sections. Always include units for physical quantities (e.g., "in meters", "in radians").
- **No type hints in function signatures** — put types in the docstring `Parameters` section instead.
- **SI units by default** throughout the codebase (meters, kilograms, seconds, radians).
- **No magic numbers** — name constants with `UPPER_SNAKE_CASE` and comment their physical meaning.
- **Performance:** Use vectorized numpy operations. Cache expensive computations with `cached_property`.
- **Test names:** `test_methodname_expectedbehaviour` pattern. Use `pytest.approx` for float comparisons.
- **Tests follow AAA** (Arrange, Act, Assert) with fixtures from `tests/fixtures/`.
- **Backward compatibility:** Use deprecation warnings before removing public API features; document changes in CHANGELOG.

# RocketPy fork instructions for Claude Code

## What this repo is
RocketPy is a 6-DOF rocket trajectory simulator in pure Python. The main source
code lives in `rocketpy/`. Tests live in `tests/`. The default branch is `master`.

## My workflow
- I am a solo contributor. Jules scouts issues and creates a branch. I hand off
  to you (Claude Code) to build the implementation.
- Branches follow the pattern `scout/YYYY-MM-DD-brief-description`.
- Read `scout_report.md` in the repo root at the start of every session — it
  contains the selected issue and any context Jules gathered.

## Scope rules — read these carefully
- Only touch files directly relevant to the issue. Do not refactor unrelated code.
- Do not modify existing function signatures unless the issue explicitly requires it.
- Do not add type hints — the codebase does not use them.
- Do not rename variables or reformat code outside the files you are changing.
- If you think something adjacent should be fixed, mention it in a comment to me
  instead of changing it.

## Code conventions
- Docstrings: NumPy format only. Every new public function and class needs one.
  Parameter types go in the docstring (e.g. `x : float`), not as type hints.
  Do not document units in the type field — just the type name.
- No magic numbers. Any numeric constant needs a comment explaining what it is.
- Follow the style of the surrounding code exactly — indentation, spacing, naming.

## Before you consider something done
- All new public functions have NumPy docstrings
- Tests written and passing
- No files modified outside the scope of the issue
- No type hints added anywhere
- Diff is clean — no stray whitespace changes, no reformatting of untouched lines

## What to ask me before doing
- Any change to an existing public API
- Adding a new dependency
- Creating a new file that isn't a test or a direct implementation of the issue
- Anything that feels like it goes beyond the issue scopeß