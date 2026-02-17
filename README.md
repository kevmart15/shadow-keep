# Shadow Keep

A first-person 3D dungeon crawler with procedurally generated levels and real-time combat.

## 🎮 Overview

Shadow Keep is a streamlined first-person dungeon crawler built with Swift and SceneKit. Battle through procedurally generated dungeons with real-time melee combat, featuring a dash mechanic and progressively challenging floors.

## ✨ Features

### Combat System
- **First-Person Melee Combat**: Real-time action-based combat
- **Dash Mechanic**: Quick dodge ability with cooldown
- **Knockback System**: Send enemies flying with your attacks
- **Arc-Based Attacks**: 126° attack arc for strategic positioning
- **Timed Combat**: Attack and dash cooldowns for balanced gameplay

### Dungeon Generation
- **Procedurally Generated**: Every playthrough offers unique dungeon layouts
- **Progressive Difficulty**: Increasing challenge as you descend floors
- **Room-Corridor System**: Connected chambers with pathways
- **Dynamic Scaling**: More rooms on deeper floors (6-12 rooms)
- **Grid-Based Design**: 42x42 tile procedural generation

### Visual Design
- **Dark Fantasy Aesthetic**: Muted browns, blacks, and grays
- **Color-Coded Elements**: Distinct colors for different game systems
  - Cyan, Red, Green, Gold, Purple, Orange highlights
- **Atmospheric Dungeon**: Stone walls and floors
- **3D Rendering**: Real-time SceneKit graphics

## 🕹️ Controls

- **Mouse**: Camera control and looking around
- **WASD**: Character movement
- **Left Mouse Button**: Attack
- **Space/Shift**: Dash
- **Sensitivity**: 0.003 for smooth camera movement

## 🎯 Game Mechanics

### Player Attributes
- **Movement Speed**: 9.0 units/second
- **Attack Range**: 2.8 units
- **Attack Arc**: 126 degrees (π * 0.7 radians)
- **Attack Cooldown**: 0.35 seconds
- **Dash Speed**: 28.0 units/second
- **Dash Duration**: 0.18 seconds
- **Dash Cooldown**: 0.55 seconds

### Technical Specifications
- **Grid Dimensions**: 42x42 tiles
- **Tile Size**: 2.0 units
- **Wall Height**: Variable
- **Camera Height**: First-person perspective
- **Knockback Force**: 8.0 units

## 🛠️ Tech Stack

- **Language**: Swift
- **3D Graphics**: SceneKit
- **2D Graphics/UI**: SpriteKit
- **Framework**: AppKit (macOS)
- **Platform**: macOS

## 🚀 Getting Started

### Prerequisites
- macOS 10.15 or later
- Xcode 13.0 or later
- Swift 5.5+

### Installation

1. Clone the repository:
```bash
git clone https://github.com/kevmart15/shadow-keep.git
cd shadow-keep
```

2. Compile the game:
```bash
swiftc main.swift -o shadow-keep -framework AppKit -framework SceneKit -framework SpriteKit
```

3. Run the game:
```bash
./shadow-keep
```

Or run the pre-built application:
```bash
open ShadowKeep.app
```

## 🎮 How to Play

1. **Enter the Dungeon**: Start your descent into the keep
2. **Navigate Rooms**: Explore procedurally generated chambers
3. **Combat Enemies**: Use melee attacks and dash to survive
4. **Descend Floors**: Progress deeper for greater challenges
5. **Master Timing**: Learn attack and dash cooldowns
6. **Positioning Matters**: Use your attack arc strategically

## 🏗️ Architecture

### Core Systems
- **Procedural Generation**: Room placement and corridor connection algorithms
- **Combat Engine**: Arc-based melee combat with cooldown management
- **Movement System**: WASD + mouse camera control with dash ability
- **Rendering Pipeline**: SceneKit 3D scene graph
- **Vector Mathematics**: Custom SCNVector3 extensions for smooth gameplay

### Dungeon Generation Algorithm
1. Generate random rooms with size variation (5x5 to 9x9)
2. Ensure proper spacing between rooms (2+ tile buffer)
3. Connect rooms sequentially with corridors
4. Widen corridors for comfortable navigation
5. Scale room count based on floor depth

## 📊 Comparison: Shadow Keep vs Shadow Keep FP

| Feature | Shadow Keep | Shadow Keep FP |
|---------|-------------|----------------|
| Combat | ✓ First-Person Melee | ✓ First-Person Melee |
| Dash Ability | ✓ | ✓ |
| Procedural Dungeons | ✓ | ✓ |
| Card System | ✗ | ✓ Roguelike Cards |
| Fog Effects | ✗ | ✓ Distance Fog |
| XP System | ✓ Basic | ✓ Advanced |
| Complexity | Streamlined | Feature-Rich |

**Shadow Keep FP** is the enhanced version with roguelike card mechanics and atmospheric fog.

## 📜 License

This project is open source and available under the MIT License.

## 👤 Author

**kevmart15**
- GitHub: [@kevmart15](https://github.com/kevmart15)

## 🤝 Contributing

Contributions, issues, and feature requests are welcome!

---

*Face the darkness. Conquer the keep.* ⚔️
