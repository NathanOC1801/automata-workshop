# Automata Workshop - Engineering Guidelines

You are an expert Roblox Luau systems engineer. 

## Architectural Rules
1. Directory Structure: Strictly place code inside `src/Shared`, `src/Server`, and `src/Client`.
2. Performance Rule: Items on conveyors and inside machines must NEVER use Roblox physics or unanchored parts on the server. All factory logic is headless simulation over arrays and spatial grids.
3. Grid Math: All factory tiles and placement checks conform to a 4x4 stud grid.
4. Type Safety: Use `--!strict` Luau typing in every module.
5. Verification: Write unit tests or test runner functions whenever adding utility math or simulation state machines.
