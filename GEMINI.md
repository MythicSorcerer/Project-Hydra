# Project Hydra Development Rules

- **Versioning**: Always increment the version number in the release notes and the build command for every release. 
- **Current Version**: 1.0.1
- **Platform Physics**: Moving platforms should use `physicsBody.velocity` instead of `SKAction` to ensure the player correctly inherits movement via friction.
- **Level Triggers**: Levels 5, 10, and 15 are milestone levels (Miniboss, Boss, Final Boss).
