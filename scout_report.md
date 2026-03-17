---
# Scout Report — 2026-03-17

## ✅ SELECTED ISSUE: 1
*(Fill in 1, 2, or 3 after reviewing the briefs below)*

---

## Issue 1 — BUG: Wind Heading Profile Plots are not that good (https://github.com/RocketPy-Team/RocketPy/issues/253)

### What's broken
When plotting the wind heading profile, the angle values can wrap around from 359° to 0° (or vice-versa). This causes matplotlib to draw a straight line straight across the plot, creating visual artifacts that look like massive sudden shifts in wind heading, confusing users. The line should either break or visually wrap smoothly.

### Files to touch
`rocketpy/environment/environment.py` or `rocketpy/plots/environment_analysis_plots.py` (depending on where the plot function is defined, likely where `wind_heading` is being processed for matplotlib plots).
`tests/test_environment.py` (or test_environment_plots.py)

### Implementation approach
1. Locate the function responsible for plotting the wind heading (often associated with `Environment.wind_heading` plotting or `EnvironmentAnalysis.wind_heading_profile_grid`).
2. Before passing the wind heading arrays to matplotlib, apply `numpy.unwrap` to the data. Note: `numpy.unwrap` expects angles in radians, so convert to radians using `np.deg2rad(angles)`, unwrap, and then convert back with `np.rad2deg(unwrapped_angles)`. Alternatively, use `numpy.unwrap(angles, period=360)`.
3. If unwrapping is difficult because of `Function` class constraints, an alternative is to insert `np.nan` values where the absolute difference between consecutive angles is greater than 180°, which tells matplotlib to break the line instead of connecting the dots across the graph.
4. Add a test case that creates an environment with a wind heading that crosses the 360-degree boundary and assert that the plotting function executes without raising an exception and the output data array (if accessible) contains unwrapped values or NaNs at the boundary.

### Acceptance criteria
* The plotted line for wind heading no longer crosses the entire plot area horizontally when the wind shifts from ~359° to ~0° or vice-versa.
* Test cases cover a scenario with boundary-crossing wind heading values.
* Ensure `Environment` and `EnvironmentAnalysis` wind heading plots are both addressed.

### Guardrails
Do not change the underlying physics computations or the mathematical definition of wind heading used in the simulation. This should strictly be a visualization/plotting fix. Do not introduce heavy dependencies outside of the existing scientific Python stack (numpy, matplotlib).

### Difficulty
1 — Extremely straightforward, suitable for a beginner who understands matplotlib and numpy array manipulation.

---

## Issue 2 — ENH: Implement Parachute Opening Shock Force Estimation (https://github.com/RocketPy-Team/RocketPy/issues/161)

### What's broken
Currently, RocketPy cannot estimate the peak opening shock force (inflation load) of a parachute. Users cannot properly size their recovery hardware without this peak transient force, which often greatly exceeds the steady-state drag force. This limits the realism and engineering utility of the recovery system simulation.

### Files to touch
`rocketpy/rocket/parachute.py`
`tests/test_parachute.py`

### Implementation approach
1. Modify `Parachute.__init__` to accept a new optional parameter `opening_shock_coefficient` (default to a standard value like 1.5 or 1.6). Store it as `self.opening_shock_coefficient`.
2. Create a new method `calculate_opening_shock(self, density, velocity)` in the `Parachute` class.
3. In this method, implement the Knacke formula: `F_o = opening_shock_coefficient * (0.5 * density * velocity**2) * self.cd_s`.
4. Optionally, you can add a post-processing calculation in the `Flight` class to print or store this peak force when a parachute event triggers (capturing the velocity and density at that timestamp), though just adding the method to `Parachute` is a good first step.
5. Write a test in `test_parachute.py` that verifies `calculate_opening_shock` returns the expected value given specific density, velocity, cd_s, and opening shock coefficient inputs.

### Acceptance criteria
* The `Parachute` class accepts an `opening_shock_coefficient` upon initialization.
* The `calculate_opening_shock` method returns the correct peak force value based on the formula provided in the issue description.
* Appropriate unit tests are added verifying the output.

### Guardrails
Do not change the actual 6-DOF equation of motion integration logic to include this transient force as a dynamic load yet; the issue specifically asks for this as an *estimation* (post-processing/informational method) rather than integrating the shock load directly into the flight trajectory calculations.

### Difficulty
2 — Requires understanding object-oriented Python, adding basic class methods, and translating a physics formula into code.

---

## Issue 3 — ENH: Custom Exception errors and messages (https://github.com/RocketPy-Team/RocketPy/issues/285)

### What's broken
When users make common mistakes (like creating a rocket with a negative static margin or passing incorrect types), RocketPy currently relies on generic Python exceptions (like `ValueError` or `TypeError`) or silently allows physics-breaking setups. This makes it hard for new users to debug their simulations.

### Files to touch
`rocketpy/exceptions.py` (Create this file if it doesn't exist)
`rocketpy/rocket/rocket.py`
`tests/test_rocket.py` (and potentially other test files)

### Implementation approach
1. Create a new module (e.g., `exceptions.py`) to hold custom exception classes inheriting from Python's built-in `Exception` or `ValueError`. For example, create `NegativeStaticMarginError`.
2. Locate the static margin calculation in `Rocket` (often accessed via `Rocket.static_margin`).
3. Add a check during rocket assembly or when static margin is accessed: if the static margin evaluates to a negative number, raise the new `NegativeStaticMarginError` with a helpful, descriptive message explaining why this is physically problematic and what the user should check (e.g., center of mass vs. center of pressure).
4. Add tests to ensure that these custom exceptions are raised correctly when a user provides bad inputs.

### Acceptance criteria
* A new custom exception class is created for at least one common user error (e.g., negative static margin).
* The code raises this specific custom exception instead of a generic error or failing silently.
* Tests use `pytest.raises` to ensure the correct custom exception is triggered with invalid configurations.

### Guardrails
Do not change the physics calculations for the static margin or other components. Do not break existing public APIs. Be careful to ensure exceptions are raised at the right time (e.g., when the user actually tries to assemble the rocket or run the flight, as static margin might be temporarily negative while components are being added).

### Difficulty
2 — Involves standard Python exception handling and understanding where validation checks should be inserted without breaking the object initialization flow.

---
