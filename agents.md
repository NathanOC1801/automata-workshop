
# Repository Architecture & Implementation Guidelines

## Visual & Rendering Standards (STRICT - DO NOT ALTER)
1. **No SurfaceGuis / Text Arrows**:
   - Directional port markers MUST ALWAYS be 3D flush neon parts (`Enum.Material.Neon`).
   - Output ports: Neon Bright Green (`Color3.fromRGB(0, 255, 100)`).
   - Input ports: Neon Orange (`Color3.fromRGB(255, 140, 0)`).
   - Under NO circumstance should `SurfaceGui`, `TextLabel`, or unicode arrow symbols (▲, ▼) be added to Conveyors, Ghosts, or Machines.

2. **Roblox Luau Syntax Guardrails**:
   - Raycast filter types must always use the full enum namespace: `Enum.RaycastFilterType.Exclude` (NOT `RaycastFilterType.Exclude`).
   - Character models must always be included in the raycast exclusion table so the player cannot click themselves.

3. **Coordinate & Grid Space**:
   - 0° -> (0, 0, -1) [-Z]
   - 90° -> (-1, 0, 0) [-X]
   - 180° -> (0, 0, 1) [+Z]
   - 270° -> (1, 0, 0) [+X]