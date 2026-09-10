# Alternate

**Alternate** is a 2D platformer currently being developed in Godot as a final project.

The project focuses on responsive platforming, hand-built level chunks, and procedural level generation. The current goal is to build a small but complete gameplay loop around traversal, exploration, enemies, obstacles, and pickups.

## Current Features

- Player movement
  - Walking
  - Sprinting
  - Jumping
  - Coyote time

- Ledge climbing
  - Automatic ledge detection
  - Ledge grab and mantle animation
  - Dedicated climbable collision masking
  - Grab-point reach validation
  - Left and right facing ledges

- Tile-based environments
  - Separate terrain and backwall TileSets
  - Terrain collision
  - Dedicated climbable physics layer
  - Hand-built level chunks

- Early chunk-based level structure
  - Reusable chunk scenes
  - Chunk sockets / connection points
  - Preparation for procedural generation

- Basic player health and hurtbox system

## In Development

Planned systems currently include:

- UI and HUD
- Game manager
- Procedural level generation
- Enemies
- Doors
- Obstacles
- Environmental props
- Pickups and additional gameplay systems

## Built With

- **Godot 4.4.1**
- **GDScript**
- Pixel-art assets and animations

## How to Run

1. Install [Godot 4.4.1](https://godotengine.org/).
2. Clone this repository:

   ```bash
   git clone https://github.com/Lex047/alternate
   ```

3. Open Godot.
4. Select Import.
5. Navigate to the cloned project folder and select project.godot.
6. Open the project.
7. Press F5 to run the project.

## Controls

| Action     | Input           |
| ---------- | --------------- |
| Move Left  | A / Left Arrow  |
| Move Right | D / Right Arrow |
| Jump       | Space           |
| Sprint     | Shift           |

Controls may change during development.

## Project Structure

The project currently uses a chunk-based level structure.

Each level chunk is built as its own scene and contains separate layers for terrain, backwalls, and other environment elements.

Terrain and background elements use independent TileSet resources so gameplay collision and visual tiles can be managed separately.

Special ledge tiles use an additional Climbable physics layer, allowing the player to distinguish climbable ledges from ordinary solid terrain.

The long-term goal is for a level generator to select and connect compatible chunks during gameplay.

## Development Status

This project is actively in development.

Several systems are still experimental and are likely to change as the project progresses.

Current development is focused on completing the core gameplay systems before expanding procedural generation and level content.

## Credits

- BoldPixels Font by Yūki (@YukiPixels)  
  https://linktr.ee/yukipixels  
  Licensed under CC BY-SA 4.0

## License

This project is currently intended for educational and academic use.

Unless otherwise stated, project code and original assets should not be reused or redistributed without permission.
