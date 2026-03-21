# Project Hydra

A high-octane 2D side-scrolling platformer built with Swift and SpriteKit. Battle through levels of enemies, navigate treacherous parkour, and take down massive bosses.

## 🚀 Installation

1.  Download the latest `Project Hydra.dmg` from the root of this repository.
2.  Open the DMG file.
3.  Drag **Project Hydra.app** into your **Applications** folder.

## 🛠 Troubleshooting (macOS Security)

Because this app is built locally and not notarized by Apple, you will likely see a "Malware" or "Unverified Developer" warning.

### The Quick Way
1.  **Right-click** (or Control-click) the app in your Applications folder.
2.  Select **Open**.
3.  Click **Open** again on the security dialog.

### The Developer Way
If the app still won't open, run this command in your Terminal:
```bash
xattr -rd com.apple.quarantine "/Applications/Project Hydra.app"
```

## 🎮 Controls

*   **A / D**: Move Left / Right
*   **Space**: Jump
*   **W / Left Click**: Shoot
*   **Mouse**: Aim bullets/projectiles

## 🕹 Features
*   **15+ Levels**: Progressing difficulty with unique platforming clusters.
*   **Moving Platforms & Traps**: Watch your step as the levels evolve.
*   **Boss Fights**: 
    *   Level 5: Heavy Assault Tank (Miniboss)
    *   Level 10: The Gatekeeper (Beam attacks & weak spots)
    *   Level 15: The Hydra (Core & Heads)
*   **Portal System**: Defeat all enemies to spawn the exit portal and advance.

## 💻 Tech Stack
*   **Language**: Swift 5
*   **Framework**: SpriteKit, GameplayKit
*   **Platform**: macOS 15.0+
