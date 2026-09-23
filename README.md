# Alternate

**Alternate** is a 2D pixel-art platformer currently being developed in Godot as a final project.

The game combines responsive platforming with hand-authored level chunks assembled through procedural generation. The player explores a generated dystopian environment, reaches a target at the end of the level, triggers an altered version of the world, and must make their way back to escape.

## Current Features

### Player Movement

- Walking
- Sprinting
- Jumping
- Coyote time
- Ledge grabbing and climbing
- Automatic ledge detection
- Grab-point reach validation
- Left and right facing ledges
- Dedicated climbable collision layer

### Player Systems

- Health system
- Hurtbox and damage handling
- Death and restart handling
- Movement and action sound effects

### Procedural Level Generation

- Graph-based procedural level structure
- Reusable hand-authored chunk scenes
- Growth rooms, corridors, terminals, start rooms, and goal rooms
- Horizontal and vertical chunk connections
- Socket-based chunk placement
- Collision and bounds validation
- Solver backtracking
- Automatic generation retries
- Graph regeneration after repeated placement failures
- Deterministic seeded generation
- Random player-readable level seeds
- Optional level seed display
- Weighted chunk selection
- Usage balancing between room variants
- Prevention of identical consecutive growth rooms
- Multiple small and large room variants
- Generation debugging and validation

### User Interface

- Main menu
- Pause menu
- Game over interface
- Health display
- Reusable settings panel
- Master, music, and SFX volume controls
- Fullscreen setting
- Level seed visibility setting
- Keyboard and mouse focus navigation
- UI interaction sound effects
- Level generation splash screen

### Audio

- Player movement and action SFX
- UI navigation and confirmation SFX
- Main menu music
- Gameplay music
- Separate Master, Music, SFX, and UI audio buses
- Persistent audio settings

## In Development

Current development is focused on completing the main gameplay loop.

Planned and in-progress systems include:

- Player spawning from generated start-room markers
- Artifact interaction in the generated goal room
- Alternate world state and transition
- Return journey after collecting the artifact
- Exit portal and level completion
- Enemies
  - Animation
  - Player detection
  - Movement and pathfinding
  - Combat and damage interaction
- Enemy spawn markers inside generated chunks
- Environmental hazards such as spikes and moving traps
- Additional room and terminal variants
- Treasure rooms
- Treasure chests and a small weapon pool
- Alternate-state environment changes

## Built With

- **Godot 4.4.1**
- **GDScript**
- Pixel-art assets and animations

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

Alternate uses reusable scenes and component-focused systems.

Levels are assembled from hand-authored chunk scenes. Each chunk contains its own terrain, background elements, gameplay objects, connection sockets, and generation bounds.

Chunks are connected procedurally using compatible directional sockets. Horizontal and vertical corridors are used as structural connections between gameplay rooms.

The generator first creates a logical level graph and then attempts to realise that graph using physical chunk scenes. Placement is validated using chunk bounds, socket compatibility, collision checks, and backtracking.

Chunk selection uses generation weights and usage balancing so common rooms can appear more frequently while distinctive or larger rooms can remain less common.

Generated levels use deterministic seeds, allowing individual layouts to be reproduced for debugging and testing.

Gameplay systems such as the player, HUD, settings, audio, and procedural generation are kept separate where possible so they can be developed and tested independently.

## Planned Gameplay Loop

The intended core gameplay loop is:

Generate a new level.
Spawn the player in the starting chunk.
Explore the generated environment.
Avoid hazards and fight enemies.
Reach the goal room and interact with the artifact.
Trigger the Alternate state.
Return through the altered level.
Reach the activated exit portal.
Escape and complete the level.

## Development Status

This project is actively in development as a final academic project.

The procedural generation, player movement, UI, settings, audio, and core supporting systems are currently functional.

Development is now focused on completing the playable gameplay loop, enemy systems, environmental interaction, and final level content before testing and polish.

## Credits

- Warped City by Ansimuz
  https://ansimuz.itch.io/warped-city
  Licensed under CC0 1.0 (https://creativecommons.org/publicdomain/zero/1.0/)

- BoldPixels Font by Yūki (@YukiPixels)
  https://yukipixels.itch.io/boldpixels
  Licensed under CC BY-SA 4.0 (https://creativecommons.org/licenses/by-sa/4.0/)

- 12 Player Movement SFX by leohpaz
  https://opengameart.org/content/12-player-movement-sfx
  Licensed under CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/)

- SoupTonic's sound SFX Pack 1 - UI menu sounds by SoupTonic
  https://souptonic.itch.io/souptonic-sfx-pack-1-ui-sounds
  Licensed under CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/)

- Future Noir (Looping) by Eric Matyas
  https://opengameart.org/content/future-noir-looping
  Licensed under CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/)

- Cyberpunk Streets In The Dead Of Night by Eric Matyas
  https://opengameart.org/content/cyberpunk-streets-in-the-dead-of-night
  Licensed under CC BY 3.0 (https://creativecommons.org/licenses/by/3.0/)

- Pixel art portal by f1xtach
  https://f1xtach.itch.io/pixel-art-portal

- Pixel art Artifact generated with PixelLab
  https://www.pixellab.ai/

- Pixel Art Animated Traps — Free Game Assets / CraftPix
  https://free-game-assets.itch.io/pixel-art-animated-traps
  https://craftpix.net/file-licenses/

## License

This project is currently intended for educational and academic use.

Unless otherwise stated, project code and original assets should not be reused or redistributed without permission.
