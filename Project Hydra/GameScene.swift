import SpriteKit
import GameplayKit

// -----------------------------------------------------------------------------
// MARK: - Constants & Physics
// -----------------------------------------------------------------------------

struct PhysicsCategory {
    static let none: UInt32 = 0
    static let player: UInt32 = 0x1 << 0
    static let playerProjectile: UInt32 = 0x1 << 1
    static let enemy: UInt32 = 0x1 << 2
    static let enemyProjectile: UInt32 = 0x1 << 3
    static let ground: UInt32 = 0x1 << 4
    static let boss: UInt32 = 0x1 << 5
    static let wall: UInt32 = 0x1 << 6
    static let trap: UInt32 = 0x1 << 7
    static let movingPlatform: UInt32 = 0x1 << 8
    static let portal: UInt32 = 0x1 << 9
}

// -----------------------------------------------------------------------------
// MARK: - Player
// -----------------------------------------------------------------------------

class Player: SKSpriteNode {
    
    private var facingRight = true
    var isGrounded = false
    var isTouchingWallLeft = false
    var isTouchingWallRight = false
    
    var health = 100
    var maxHealth = 100
    var isInvulnerable = false
    
    init() {
        let texture = SKTexture(imageNamed: "PlayerIdle")
        let targetSize = CGSize(width: 48, height: 48)
        super.init(texture: texture, color: .white, size: targetSize)
        
        self.name = "player"
        self.zPosition = 10
        
        // Physics body is slightly smaller than the visual to prevent getting stuck
        self.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: 28, height: 42))
        self.physicsBody?.categoryBitMask = PhysicsCategory.player
        self.physicsBody?.contactTestBitMask = PhysicsCategory.enemy | PhysicsCategory.enemyProjectile | PhysicsCategory.boss | PhysicsCategory.ground | PhysicsCategory.trap | PhysicsCategory.portal | PhysicsCategory.movingPlatform
        self.physicsBody?.collisionBitMask = PhysicsCategory.ground | PhysicsCategory.wall | PhysicsCategory.movingPlatform
        self.physicsBody?.allowsRotation = false
        self.physicsBody?.restitution = 0.0
        self.physicsBody?.friction = 0.1 // Lower friction prevents sticking to sides
        self.physicsBody?.linearDamping = 0.1
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func move(direction: CGFloat) {
        let speed: CGFloat = 400
        self.physicsBody?.velocity.dx = direction * speed
        
        if direction > 0 && !facingRight {
            self.xScale = 1
            facingRight = true
        } else if direction < 0 && facingRight {
            self.xScale = -1
            facingRight = false
        }
        
        if direction != 0 {
            if self.action(forKey: "run") == nil {
                let runTexture = SKTexture(imageNamed: "PlayerRun")
                let idleTexture = SKTexture(imageNamed: "PlayerIdle")
                let anim = SKAction.animate(with: [runTexture, idleTexture], timePerFrame: 0.1)
                self.run(SKAction.repeatForever(anim), withKey: "run")
            }
        } else {
            self.removeAction(forKey: "run")
            self.texture = SKTexture(imageNamed: "PlayerIdle")
        }
    }
    
    func jump() {
        if isGrounded {
            // Normal Jump
            self.physicsBody?.velocity.dy = 0 
            self.physicsBody?.applyImpulse(CGVector(dx: 0, dy: 65))
            isGrounded = false
        } else if isTouchingWallLeft {
            // Wall Jump Right
            self.physicsBody?.velocity = CGVector(dx: 400, dy: 600)
            self.run(SKAction.rotate(byAngle: -.pi * 2, duration: 0.4))
        } else if isTouchingWallRight {
            // Wall Jump Left
            self.physicsBody?.velocity = CGVector(dx: -400, dy: 600)
            self.run(SKAction.rotate(byAngle: .pi * 2, duration: 0.4))
        }
    }
    
    func shoot(scene: SKScene) {
        let bullet = SKSpriteNode(imageNamed: "BulletPlayer")
        bullet.size = CGSize(width: 16, height: 8)
        bullet.position = self.position
        bullet.position.x += facingRight ? 25 : -25
        bullet.zPosition = 9
        
        bullet.physicsBody = SKPhysicsBody(rectangleOf: bullet.size)
        bullet.physicsBody?.categoryBitMask = PhysicsCategory.playerProjectile
        bullet.physicsBody?.contactTestBitMask = PhysicsCategory.enemy | PhysicsCategory.boss
        bullet.physicsBody?.collisionBitMask = PhysicsCategory.none
        bullet.physicsBody?.affectedByGravity = false
        
        let speed: CGFloat = 1000
        let velocity = facingRight ? CGVector(dx: speed, dy: 0) : CGVector(dx: -speed, dy: 0)
        bullet.physicsBody?.velocity = velocity
        
        scene.addChild(bullet)
        
        bullet.run(SKAction.sequence([
            SKAction.wait(forDuration: 1.5),
            SKAction.removeFromParent()
        ]))
    }
    
    func takeDamage(_ amount: Int) {
        if isInvulnerable || health <= 0 { return }
        health -= amount
        if health < 0 { health = 0 }
        hit()
        isInvulnerable = true
        self.run(SKAction.sequence([
            SKAction.wait(forDuration: 1.0),
            SKAction.run { self.isInvulnerable = false }
        ]))
    }
    
    func hit() {
        let flashRed = SKAction.sequence([
            SKAction.colorize(with: .red, colorBlendFactor: 1.0, duration: 0.05),
            SKAction.colorize(with: .white, colorBlendFactor: 0.0, duration: 0.05)
        ])
        self.run(SKAction.repeat(flashRed, count: 3))
    }
    
    func reset() {
        health = maxHealth
        isInvulnerable = false
        self.alpha = 1.0
        self.colorBlendFactor = 0.0
        self.zRotation = 0
    }
}

// -----------------------------------------------------------------------------
// MARK: - Enemy
// -----------------------------------------------------------------------------

enum EnemyType {
    case walker
    case flyer
    case miniboss
    case boss
    case hydraHead
    case hydraSpawn
}

class Enemy: SKSpriteNode {
    
    var type: EnemyType
    var health: Int
    var maxHealth: Int
    var bossName: String?
    private var moveDir: CGFloat = -1
    private var vulnerableSpot: SKShapeNode?
    
    init(type: EnemyType) {
        self.type = type
        
        var textureName = "EnemyWalker"
        var size = CGSize(width: 50, height: 50)
        var hp = 3
        var name: String? = nil
        
        switch type {
        case .walker:
            textureName = "EnemyWalker"
            hp = 3
        case .flyer:
            textureName = "EnemyFlyer"
            hp = 2
        case .miniboss:
            textureName = "Miniboss"
            size = CGSize(width: 120, height: 100)
            hp = 50
            name = "HEAVY ASSAULT TANK"
        case .boss:
            textureName = "BossGatekeeper"
            size = CGSize(width: 180, height: 180)
            hp = 250
            name = "THE GATEKEEPER"
        case .hydraHead:
            textureName = "HydraHead"
            size = CGSize(width: 80, height: 80)
            hp = 100
            name = "HYDRA HEAD"
        case .hydraSpawn:
            textureName = "HydraSpawn"
            size = CGSize(width: 32, height: 32)
            hp = 1
        }
        
        self.health = hp
        self.maxHealth = hp
        self.bossName = name
        
        let texture = SKTexture(imageNamed: textureName)
        super.init(texture: texture, color: .white, size: size)
        
        self.name = "enemy"
        self.zPosition = 5
        
        self.physicsBody = SKPhysicsBody(rectangleOf: self.size)
        self.physicsBody?.categoryBitMask = (type == .boss || type == .miniboss || type == .hydraHead) ? PhysicsCategory.boss : PhysicsCategory.enemy
        self.physicsBody?.contactTestBitMask = PhysicsCategory.playerProjectile | PhysicsCategory.player
        self.physicsBody?.collisionBitMask = PhysicsCategory.ground | PhysicsCategory.wall
        
        if type == .flyer || type == .hydraHead || type == .hydraSpawn {
            self.physicsBody?.affectedByGravity = false
        } else {
            self.physicsBody?.affectedByGravity = true
        }
        
        self.physicsBody?.allowsRotation = false
        self.physicsBody?.friction = 0.5
        
        if type == .boss {
            setupVulnerableSpot()
        }
    }
    
    func setupVulnerableSpot() {
        let spot = SKShapeNode(circleOfRadius: 20)
        spot.fillColor = .cyan
        spot.strokeColor = .white
        spot.glowWidth = 5
        spot.position = CGPoint(x: 0, y: 40)
        spot.name = "vulnerable_spot"
        spot.zPosition = 6
        self.addChild(spot)
        self.vulnerableSpot = spot
        
        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.2, duration: 0.5),
            SKAction.scale(to: 0.8, duration: 0.5)
        ])
        spot.run(SKAction.repeatForever(pulse))
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(player: Player, scene: SKScene) {
        if health <= 0 { return }
        
        if self.position.y < -1200 {
            self.takeDamage(amount: 1000)
            return
        }
        
        let dx = player.position.x - self.position.x
        let dy = player.position.y - self.position.y
        let dist = sqrt(dx*dx + dy*dy)
        
        switch type {
        case .walker:
            let speed: CGFloat = 80
            let probeX = self.position.x + (moveDir * 30)
            let probeY = self.position.y - 30
            
            let groundNodes = scene.nodes(at: CGPoint(x: probeX, y: probeY)).filter { $0.name == "platform" || $0.name == "ground" || $0.name == "moving_platform" }
            if groundNodes.isEmpty {
                moveDir *= -1
            }
            
            self.physicsBody?.velocity.dx = moveDir * speed
            self.xScale = moveDir > 0 ? -1 : 1
            
        case .flyer, .hydraSpawn:
            let followDist: CGFloat = type == .flyer ? 600 : 1000
            if dist < followDist {
                let speed: CGFloat = type == .flyer ? 120 : 200
                let angle = atan2(dy, dx)
                self.physicsBody?.velocity = CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed)
                self.xScale = dx > 0 ? -1 : 1
                
                if type == .flyer && Int.random(in: 0...120) < 1 {
                    shoot(target: player.position)
                }
            }
        case .miniboss:
             if abs(dx) < 1200 {
                let speed: CGFloat = 40
                self.physicsBody?.velocity.dx = dx > 0 ? speed : -speed
                self.xScale = dx > 0 ? -1 : 1
                 if Int.random(in: 0...100) < 1 { shoot(target: player.position) }
                 if Int.random(in: 0...300) < 1 { shootMissile(target: player.position) }
            }
        case .boss:
            if abs(dx) < 1500 {
                let speed: CGFloat = 30
                self.physicsBody?.velocity.dx = dx > 0 ? speed : -speed
                self.xScale = dx > 0 ? -1 : 1
                if Int.random(in: 0...60) < 1 { shoot(target: player.position) }
                if Int.random(in: 0...240) < 1 { beamAttack(player: player) }
            }
        case .hydraHead:
            if dist < 800 {
                let speed: CGFloat = 150
                let angle = atan2(dy, dx)
                self.physicsBody?.velocity = CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed)
            }
        }
    }
    
    func shoot(target: CGPoint) {
        let bullet = SKSpriteNode(imageNamed: "BulletEnemy")
        bullet.size = CGSize(width: 15, height: 15)
        bullet.position = self.position
        bullet.zPosition = 9
        bullet.physicsBody = SKPhysicsBody(circleOfRadius: 7)
        bullet.physicsBody?.categoryBitMask = PhysicsCategory.enemyProjectile
        bullet.physicsBody?.contactTestBitMask = PhysicsCategory.player
        bullet.physicsBody?.collisionBitMask = PhysicsCategory.none
        bullet.physicsBody?.affectedByGravity = false
        
        let dx = target.x - self.position.x
        let dy = target.y - self.position.y
        let angle = atan2(dy, dx)
        let speed: CGFloat = 350
        bullet.physicsBody?.velocity = CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed)
        self.scene?.addChild(bullet)
        bullet.run(SKAction.sequence([SKAction.wait(forDuration: 4.0), SKAction.removeFromParent()]))
    }
    
    func shootMissile(target: CGPoint) {
        let missile = SKShapeNode(rectOf: CGSize(width: 40, height: 15), cornerRadius: 5)
        missile.fillColor = .orange
        missile.strokeColor = .red
        missile.position = self.position
        missile.zPosition = 8
        missile.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: 40, height: 15))
        missile.physicsBody?.categoryBitMask = PhysicsCategory.enemyProjectile
        missile.physicsBody?.contactTestBitMask = PhysicsCategory.player
        missile.physicsBody?.collisionBitMask = PhysicsCategory.none
        missile.physicsBody?.affectedByGravity = false
        let dx = target.x - self.position.x
        let dy = target.y - self.position.y
        let angle = atan2(dy, dx)
        missile.zRotation = angle
        self.scene?.addChild(missile)
        let moveAction = SKAction.move(by: CGVector(dx: cos(angle) * 2000, dy: sin(angle) * 2000), duration: 5.0)
        missile.run(SKAction.sequence([moveAction, SKAction.removeFromParent()]))
    }
    
    func beamAttack(player: Player) {
        let beam = SKShapeNode()
        let path = CGMutablePath()
        path.move(to: .zero)
        let dx = player.position.x - self.position.x
        let dy = player.position.y - self.position.y
        path.addLine(to: CGPoint(x: dx, y: dy))
        beam.path = path
        beam.strokeColor = .magenta
        beam.lineWidth = 4
        beam.glowWidth = 10
        beam.zPosition = 4
        self.addChild(beam)
        beam.alpha = 0.2
        let flash = SKAction.sequence([SKAction.fadeAlpha(to: 0.8, duration: 0.1), SKAction.fadeAlpha(to: 0.2, duration: 0.1)])
        beam.run(SKAction.sequence([
            SKAction.repeat(flash, count: 5),
            SKAction.run {
                beam.alpha = 1.0
                beam.lineWidth = 15
                let dist = sqrt(dx*dx + dy*dy)
                if dist < 1000 { player.takeDamage(30) }
            },
            SKAction.wait(forDuration: 0.5),
            SKAction.fadeOut(withDuration: 0.2),
            SKAction.removeFromParent()
        ]))
    }
    
    func takeDamage(amount: Int) {
        health -= amount
        if health <= 0 {
            let explosion = SKAction.sequence([
                SKAction.group([SKAction.scale(to: 1.5, duration: 0.1), SKAction.fadeOut(withDuration: 0.1)]),
                SKAction.removeFromParent()
            ])
            self.run(explosion)
        } else {
            let flash = SKAction.sequence([
                SKAction.colorize(with: .white, colorBlendFactor: 0.8, duration: 0.05),
                SKAction.colorize(with: .white, colorBlendFactor: 0.0, duration: 0.05)
            ])
            self.run(flash)
        }
    }
}

// -----------------------------------------------------------------------------
// MARK: - Moving Platform
// -----------------------------------------------------------------------------

class MovingPlatform: SKSpriteNode {
    init(size: CGSize, range: CGFloat, horizontal: Bool) {
        let texture = SKTexture(imageNamed: "TilePlatform")
        super.init(texture: texture, color: .white, size: size)
        self.name = "moving_platform"
        self.physicsBody = SKPhysicsBody(rectangleOf: size)
        self.physicsBody?.isDynamic = false
        self.physicsBody?.categoryBitMask = PhysicsCategory.movingPlatform
        self.physicsBody?.collisionBitMask = PhysicsCategory.player
        self.physicsBody?.friction = 0.8
        
        let moveAction = horizontal ? 
            SKAction.moveBy(x: range, y: 0, duration: 2.5) : 
            SKAction.moveBy(x: 0, y: range, duration: 2.5)
        let sequence = SKAction.sequence([moveAction, moveAction.reversed()])
        self.run(SKAction.repeatForever(sequence))
    }
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// -----------------------------------------------------------------------------
// MARK: - Trap
// -----------------------------------------------------------------------------

class Trap: SKSpriteNode {
    init() {
        let texture = SKTexture(imageNamed: "TileGround")
        super.init(texture: texture, color: .red, size: CGSize(width: 40, height: 20))
        self.name = "trap"
        self.colorBlendFactor = 1.0
        self.color = .red
        self.physicsBody = SKPhysicsBody(rectangleOf: self.size)
        self.physicsBody?.isDynamic = false
        self.physicsBody?.categoryBitMask = PhysicsCategory.trap
        self.physicsBody?.contactTestBitMask = PhysicsCategory.player
    }
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// -----------------------------------------------------------------------------
// MARK: - Hydra Boss
// -----------------------------------------------------------------------------

enum HydraState { case shooting, charging, summoning, resting }

class HydraBoss: SKNode {
    var bodyNode: SKSpriteNode!
    var heads: [SKSpriteNode] = []
    var necks: [SKShapeNode] = []
    var headHealth: [Int] = []
    var headMaxHealth: [Int] = []
    var bodyHealth = 600
    var maxBodyHealth = 600
    var state: HydraState = .shooting
    var stateTimer: TimeInterval = 0
    var nextStateTime: TimeInterval = 5.0
    var bossName = "PROJECT HYDRA: CORE"

    init(position: CGPoint) {
        super.init()
        self.position = position
        self.name = "hydra_boss"

        // Body
        bodyNode = SKSpriteNode(imageNamed: "HydraBody")
        bodyNode.size = CGSize(width: 200, height: 150)
        bodyNode.position = .zero
        bodyNode.zPosition = 5
        bodyNode.physicsBody = SKPhysicsBody(rectangleOf: bodyNode.size)
        bodyNode.physicsBody?.categoryBitMask = PhysicsCategory.boss
        bodyNode.physicsBody?.contactTestBitMask = PhysicsCategory.playerProjectile | PhysicsCategory.player
        bodyNode.physicsBody?.collisionBitMask = PhysicsCategory.ground | PhysicsCategory.wall
        bodyNode.physicsBody?.allowsRotation = false
        bodyNode.physicsBody?.friction = 0.5
        bodyNode.physicsBody?.affectedByGravity = true
        self.addChild(bodyNode)

        // Heads and necks
        for i in 0..<3 {
            let head = SKSpriteNode(imageNamed: "HydraHead")
            head.size = CGSize(width: 80, height: 80)
            head.position = CGPoint(x: -80 + CGFloat(i * 80), y: 100)
            head.zPosition = 6
            headHealth.append(150)
            headMaxHealth.append(150)
            heads.append(head)
            self.addChild(head)

            let neck = SKShapeNode()
            neck.strokeColor = .green
            neck.lineWidth = 12
            neck.glowWidth = 4
            neck.zPosition = 4
            necks.append(neck)
            self.addChild(neck)
        }
    }
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func updateNecks() {
        let bodyTop: CGFloat = 70
        for (i, head) in heads.enumerated() {
            guard headHealth[i] > 0 else {
                necks[i].isHidden = true
                continue
            }
            necks[i].isHidden = false
            let startX = head.position.x
            let path = CGMutablePath()
            path.move(to: CGPoint(x: startX, y: bodyTop))
            path.addLine(to: head.position)
            necks[i].path = path
        }
    }

    func scenePosition() -> CGPoint {
        return self.convert(bodyNode.position, to: self.scene!)
    }

    func shootFromHead(headIndex: Int, target: CGPoint) {
        guard headIndex < heads.count, headHealth[headIndex] > 0 else { return }
        let head = heads[headIndex]
        let worldPos = self.convert(head.position, to: self.scene!)

        let bullet = SKSpriteNode(imageNamed: "BulletEnemy")
        bullet.size = CGSize(width: 15, height: 15)
        bullet.position = worldPos
        bullet.zPosition = 9
        bullet.physicsBody = SKPhysicsBody(circleOfRadius: 7)
        bullet.physicsBody?.categoryBitMask = PhysicsCategory.enemyProjectile
        bullet.physicsBody?.contactTestBitMask = PhysicsCategory.player
        bullet.physicsBody?.collisionBitMask = PhysicsCategory.none
        bullet.physicsBody?.affectedByGravity = false

        let dx = target.x - worldPos.x
        let dy = target.y - worldPos.y
        let angle = atan2(dy, dx)
        let speed: CGFloat = 350
        bullet.physicsBody?.velocity = CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed)
        self.scene?.addChild(bullet)
        bullet.run(SKAction.sequence([SKAction.wait(forDuration: 4.0), SKAction.removeFromParent()]))
    }

    func takeHeadDamage(index: Int, amount: Int) {
        guard index < headHealth.count else { return }
        headHealth[index] -= amount
        if headHealth[index] <= 0 {
            headHealth[index] = 0
            heads[index].run(SKAction.sequence([
                SKAction.group([SKAction.scale(to: 1.5, duration: 0.1), SKAction.fadeOut(withDuration: 0.1)]),
                SKAction.removeFromParent()
            ]))
        } else {
            let flash = SKAction.sequence([
                SKAction.colorize(with: .white, colorBlendFactor: 0.8, duration: 0.05),
                SKAction.colorize(with: .white, colorBlendFactor: 0.0, duration: 0.05)
            ])
            heads[index].run(flash)
        }
    }

    func takeBodyDamage(amount: Int) {
        bodyHealth -= amount
        if bodyHealth <= 0 {
            bodyHealth = 0
            let explosion = SKAction.sequence([
                SKAction.group([SKAction.scale(to: 1.5, duration: 0.1), SKAction.fadeOut(withDuration: 0.1)]),
                SKAction.removeFromParent()
            ])
            bodyNode.run(explosion)
        } else {
            let flash = SKAction.sequence([
                SKAction.colorize(with: .white, colorBlendFactor: 0.8, duration: 0.05),
                SKAction.colorize(with: .white, colorBlendFactor: 0.0, duration: 0.05)
            ])
            bodyNode.run(flash)
        }
    }

    func isAlive() -> Bool {
        return bodyHealth > 0
    }

    func update(player: Player, currentTime: TimeInterval, dt: TimeInterval) {
        if !isAlive() { return }
        if self.position.y < -1200 { bodyHealth = 0; return }

        stateTimer += dt
        if stateTimer >= nextStateTime { stateTimer = 0; switchState() }

        let playerWorldPos = player.position
        let dx = playerWorldPos.x - self.position.x

        switch state {
        case .shooting:
            for (i, head) in heads.enumerated() where headHealth[i] > 0 {
                if Int.random(in: 0...60) < 1 {
                    shootFromHead(headIndex: i, target: playerWorldPos)
                }
                let offset = sin(currentTime * 2 + CGFloat(i)) * 20
                head.position.y = 100 + offset
            }
        case .charging:
            let speed: CGFloat = 350
            bodyNode.physicsBody?.velocity.dx = dx > 0 ? speed : -speed
            for head in heads { head.position.y = 60 }
        case .summoning:
            if Int.random(in: 0...80) < 2 {
                let spawn = Enemy(type: .hydraSpawn)
                spawn.position = self.position
                self.scene?.addChild(spawn)
            }
            for (i, head) in heads.enumerated() where headHealth[i] > 0 {
                let offset = sin(currentTime * 3 + CGFloat(i)) * 15
                head.position.y = 80 + offset
            }
        case .resting:
            bodyNode.physicsBody?.velocity = .zero
            let targetY: CGFloat = -100
            self.position.y += (targetY - self.position.y) * 0.05
            for head in heads { head.position.y = 40 }
        }
        updateNecks()
    }

    func switchState() {
        let states: [HydraState] = [.shooting, .charging, .summoning, .resting]
        state = states.randomElement()!
        switch state {
        case .shooting: nextStateTime = 5.0
        case .charging: nextStateTime = 3.0
        case .summoning: nextStateTime = 4.0
        case .resting: nextStateTime = 6.0
        }
    }
}

// -----------------------------------------------------------------------------
// MARK: - Level Manager
// -----------------------------------------------------------------------------

class LevelManager {
    weak var scene: SKScene?
    var currentLevel = 1
    var portalSpawned = false
    init(scene: SKScene) { self.scene = scene }
    
    func loadLevel(_ level: Int) {
        guard let scene = scene else { return }
        portalSpawned = false
        scene.children.filter { 
            $0.name == "enemy" || $0.name == "platform" || $0.name == "ground" || 
            $0.name == "bullet" || $0.name == "wall" || $0.name == "hydra_boss" ||
            $0.name == "moving_platform" || $0.name == "trap" || $0.name == "portal"
        }.forEach { $0.removeFromParent() }
        self.currentLevel = level
        let savedMax = UserDefaults.standard.integer(forKey: "ProjectHydra_MaxLevel")
        if level > savedMax { UserDefaults.standard.set(level, forKey: "ProjectHydra_MaxLevel") }
        let ground = SKSpriteNode(imageNamed: "TileGround")
        ground.size = CGSize(width: 2500, height: 120)
        ground.position = CGPoint(x: 400, y: -250)
        ground.physicsBody = SKPhysicsBody(rectangleOf: ground.size)
        ground.physicsBody?.isDynamic = false
        ground.physicsBody?.categoryBitMask = PhysicsCategory.ground
        ground.name = "ground"
        scene.addChild(ground)
        if level == 5 { spawnMiniboss() } else if level == 10 { spawnBoss() } else if level == 15 { spawnHydra() } else { spawnStandardLevel(difficulty: level) }
    }
    
    func spawnStandardLevel(difficulty: Int) {
        guard let scene = scene else { return }
        var lastX: CGFloat = 800
        var lastY: CGFloat = -150
        let clusterCount = 5 + (difficulty / 2)
        for i in 0..<clusterCount {
            let clusterBaseX = lastX + CGFloat.random(in: 250...400)
            let clusterBaseY = max(-250, min(300, lastY + CGFloat.random(in: -100...100)))
            let platformsInCluster = 2 + Int.random(in: 0...2)
            for j in 0..<platformsInCluster {
                let x = clusterBaseX + CGFloat(j * 220)
                let y = clusterBaseY + CGFloat.random(in: -30...30)
                if difficulty >= 3 && i > 2 && Int.random(in: 0...10) > 6 {
                    let mp = MovingPlatform(size: CGSize(width: 200, height: 40), range: 250, horizontal: Bool.random())
                    mp.position = CGPoint(x: x, y: y)
                    scene.addChild(mp)
                } else {
                    let width = CGFloat.random(in: 180...300)
                    let platform = SKSpriteNode(imageNamed: "TilePlatform")
                    platform.size = CGSize(width: width, height: 40)
                    platform.position = CGPoint(x: x, y: y)
                    platform.physicsBody = SKPhysicsBody(rectangleOf: platform.size)
                    platform.physicsBody?.isDynamic = false
                    platform.physicsBody?.categoryBitMask = PhysicsCategory.ground
                    platform.name = "platform"
                    scene.addChild(platform)
                    if difficulty >= 4 && Int.random(in: 0...10) > 7 {
                        let trap = Trap(); trap.position = CGPoint(x: x, y: y + 30); scene.addChild(trap)
                    }
                }
                if Bool.random() || (i == 0 && j == 0) {
                    let enemyType: EnemyType = (difficulty > 3 && Int.random(in: 0...10) > 6) ? .flyer : .walker
                    let enemy = Enemy(type: enemyType); enemy.position = CGPoint(x: x, y: y + 80); scene.addChild(enemy)
                }
                lastX = x; lastY = y
            }
        }
        let endX = lastX + 600
        let endPlatform = SKSpriteNode(imageNamed: "TileGround")
        endPlatform.size = CGSize(width: 800, height: 80)
        endPlatform.position = CGPoint(x: endX, y: -100)
        endPlatform.physicsBody = SKPhysicsBody(rectangleOf: endPlatform.size)
        endPlatform.physicsBody?.isDynamic = false
        endPlatform.physicsBody?.categoryBitMask = PhysicsCategory.ground
        endPlatform.name = "platform"
        scene.addChild(endPlatform)
    }
    
    func spawnMiniboss() {
        guard let scene = scene else { return }
        let boss = Enemy(type: .miniboss); boss.position = CGPoint(x: 1000, y: 0); scene.addChild(boss)
        let arena = SKSpriteNode(imageNamed: "TileGround"); arena.size = CGSize(width: 2500, height: 60)
        arena.position = CGPoint(x: 1000, y: -150); arena.physicsBody = SKPhysicsBody(rectangleOf: arena.size)
        arena.physicsBody?.isDynamic = false; arena.physicsBody?.categoryBitMask = PhysicsCategory.ground
        arena.name = "platform"; scene.addChild(arena)
    }
    
    func spawnBoss() {
        guard let scene = scene else { return }
        let boss = Enemy(type: .boss); boss.position = CGPoint(x: 1200, y: 100); scene.addChild(boss)
        let arena = SKSpriteNode(imageNamed: "TileGround"); arena.size = CGSize(width: 3000, height: 80)
        arena.position = CGPoint(x: 1200, y: -150); arena.physicsBody = SKPhysicsBody(rectangleOf: arena.size)
        arena.physicsBody?.isDynamic = false; arena.physicsBody?.categoryBitMask = PhysicsCategory.ground
        arena.name = "platform"; scene.addChild(arena)
    }
    
    func spawnHydra() {
        guard let scene = scene else { return }
        let hydra = HydraBoss(position: CGPoint(x: 1500, y: 100)); scene.addChild(hydra)
        let arena = SKSpriteNode(imageNamed: "TileGround"); arena.size = CGSize(width: 4000, height: 80)
        arena.position = CGPoint(x: 1500, y: -200); arena.physicsBody = SKPhysicsBody(rectangleOf: arena.size)
        arena.physicsBody?.isDynamic = false; arena.physicsBody?.categoryBitMask = PhysicsCategory.ground
        arena.name = "platform"; scene.addChild(arena)
    }
    
    func spawnPortal() {
        guard let scene = scene, !portalSpawned else { return }
        portalSpawned = true
        let portal = SKShapeNode(circleOfRadius: 50)
        portal.fillColor = .purple; portal.strokeColor = .magenta; portal.glowWidth = 10
        portal.name = "portal"; portal.zPosition = 5
        let endNodes = scene.children.filter { $0.name == "platform" || $0.name == "ground" }
        if let lastNode = endNodes.sorted(by: { $0.position.x < $1.position.x }).last { portal.position = CGPoint(x: lastNode.position.x, y: lastNode.position.y + 120) } else { portal.position = CGPoint(x: 1000, y: 100) }
        portal.physicsBody = SKPhysicsBody(circleOfRadius: 50); portal.physicsBody?.isDynamic = false
        portal.physicsBody?.categoryBitMask = PhysicsCategory.portal; portal.physicsBody?.contactTestBitMask = PhysicsCategory.player
        scene.addChild(portal)
        let rotate = SKAction.rotate(byAngle: .pi * 2, duration: 2.0); portal.run(SKAction.repeatForever(rotate))
        let label = SKLabelNode(fontNamed: "Courier-Bold")
        var labelText = "NEXT LEVEL"
        if currentLevel == 4 { labelText = "NEXT: MINIBOSS" } else if currentLevel == 9 { labelText = "NEXT: BOSS" } else if currentLevel == 14 { labelText = "NEXT: FINAL BOSS" } else if currentLevel >= 15 { labelText = "FINISH" }
        label.text = labelText; label.fontSize = 20; label.position = CGPoint(x: 0, y: 70); portal.addChild(label)
    }
    
    func checkLevelCompletion() -> Int {
        guard let scene = scene else { return 0 }
        let enemies = scene.children.filter { ($0.name == "enemy" || $0.name == "hydra_boss") }
        var totalHealth = 0
        for node in enemies {
            if let enemy = node as? Enemy { if enemy.health > 0 { totalHealth += 1 } } else if let hydra = node as? HydraBoss { if hydra.isAlive() { totalHealth += 1 } }
        }
        if totalHealth == 0 && !portalSpawned { spawnPortal() }
        return totalHealth
    }
}

// -----------------------------------------------------------------------------
// MARK: - GameScene
// -----------------------------------------------------------------------------

class GameScene: SKScene, SKPhysicsContactDelegate {

    var player: Player!
    var levelManager: LevelManager!
    var cam: SKCameraNode!
    var lastUpdateTime: TimeInterval = 0
    var leftPressed = false
    var rightPressed = false
    var jumpPressed = false
    var isLevelSelecting = false
    var levelTitleClickCount = 0
    var levelTitleLastClickTime: TimeInterval = 0
    
    override func didMove(to view: SKView) {
        self.removeAllChildren()
        physicsWorld.gravity = CGVector(dx: 0, dy: -25.0)
        physicsWorld.contactDelegate = self
        cam = SKCameraNode(); self.camera = cam; self.addChild(cam)
        player = Player(); player.position = CGPoint(x: -200, y: 0); self.addChild(player)
        levelManager = LevelManager(scene: self)
        let savedMax = UserDefaults.standard.integer(forKey: "ProjectHydra_MaxLevel")
        levelManager.loadLevel(max(1, savedMax))
        setupHUD()
    }
    
    func setupHUD() {
        let label = SKLabelNode(fontNamed: "Courier-Bold"); label.text = "LEVEL \(levelManager.currentLevel)"
        label.name = "levelLabel"; label.position = CGPoint(x: 0, y: 340); label.fontSize = 32; label.fontColor = .white
        label.zPosition = 100; cam.addChild(label)
        let healthLabel = SKLabelNode(fontNamed: "Courier-Bold"); healthLabel.text = "HEALTH: 100%"
        healthLabel.name = "healthLabel"; healthLabel.position = CGPoint(x: -350, y: 340); healthLabel.fontSize = 20
        healthLabel.fontColor = .green; healthLabel.zPosition = 100; cam.addChild(healthLabel)
        let enemyLabel = SKLabelNode(fontNamed: "Courier-Bold"); enemyLabel.text = "ENEMIES: 0"
        enemyLabel.name = "enemyLabel"; enemyLabel.position = CGPoint(x: 350, y: 340); enemyLabel.fontSize = 20
        enemyLabel.fontColor = .orange; enemyLabel.zPosition = 100; cam.addChild(enemyLabel)
        let hintLabel = SKLabelNode(fontNamed: "Courier"); hintLabel.text = "PRESS 'L' FOR LEVEL SELECT"
        hintLabel.fontSize = 14; hintLabel.position = CGPoint(x: 0, y: -360); hintLabel.fontColor = .gray
        hintLabel.zPosition = 100; cam.addChild(hintLabel)
        let bossBarBg = SKShapeNode(rectOf: CGSize(width: 500, height: 25)); bossBarBg.name = "bossBarBg"; bossBarBg.fillColor = .darkGray
        bossBarBg.strokeColor = .white; bossBarBg.position = CGPoint(x: 0, y: 300); bossBarBg.isHidden = true
        bossBarBg.zPosition = 100; cam.addChild(bossBarBg)
        let bossBarFill = SKShapeNode(rectOf: CGSize(width: 500, height: 25)); bossBarFill.name = "bossBarFill"; bossBarFill.fillColor = .red
        bossBarFill.strokeColor = .clear; bossBarFill.position = CGPoint(x: 0, y: 300); bossBarFill.isHidden = true
        bossBarFill.zPosition = 101; cam.addChild(bossBarFill)
        let bossNameLabel = SKLabelNode(fontNamed: "Courier-Bold"); bossNameLabel.name = "bossNameLabel"
        bossNameLabel.position = CGPoint(x: 0, y: 260); bossNameLabel.fontSize = 22; bossNameLabel.fontColor = .white
        bossNameLabel.isHidden = true; bossNameLabel.zPosition = 100; cam.addChild(bossNameLabel)
    }
    
    override func update(_ currentTime: TimeInterval) {
        if lastUpdateTime == 0 { lastUpdateTime = currentTime }
        let dt = currentTime - lastUpdateTime
        lastUpdateTime = currentTime
        if isLevelSelecting { return }
        if let hLabel = cam.childNode(withName: "healthLabel") as? SKLabelNode {
            hLabel.text = "HEALTH: \(player.health)%"; hLabel.fontColor = player.health < 30 ? .red : (player.health < 60 ? .yellow : .green)
        }
        let enemiesCount = levelManager.checkLevelCompletion()
        if let eLabel = cam.childNode(withName: "enemyLabel") as? SKLabelNode {
            eLabel.text = "ENEMIES: \(enemiesCount)"
            if enemiesCount == 0 { eLabel.fontColor = .cyan; eLabel.text = "FIND PORTAL" } else { eLabel.fontColor = .orange }
        }
        updateBossBar()
        if player.health <= 0 { gameOver(); return }
        var dx: CGFloat = 0
        if leftPressed { dx -= 1 }
        if rightPressed { dx += 1 }
        player.move(direction: dx)
        if jumpPressed { player.jump() }
        let lerp: CGFloat = 0.1; let targetX = player.position.x; let targetY = max(player.position.y + 100, 0)
        cam.position.x += (targetX - cam.position.x) * lerp; cam.position.y += (targetY - cam.position.y) * lerp
        self.children.filter { $0 is Enemy }.forEach { ($0 as? Enemy)?.update(player: player, scene: self) }
        if let hydra = self.childNode(withName: "hydra_boss") as? HydraBoss { hydra.update(player: player, currentTime: currentTime, dt: dt) }
        if player.position.y < -1200 { player.takeDamage(100) }
        
        // GROUND CHECK REINFORCEMENT (Prevents "stuck" state)
        // If the player has a vertical velocity near zero, they are likely grounded
        if abs(player.physicsBody?.velocity.dy ?? 0) < 0.1 {
            player.isGrounded = true
        }
    }
    
    func updateBossBar() {
        let boss = self.children.compactMap { $0 as? Enemy }.first { $0.bossName != nil }
        let hydra = self.childNode(withName: "hydra_boss") as? HydraBoss

        if let hydra = hydra, hydra.isAlive() {
            cam.childNode(withName: "bossBarBg")?.isHidden = false
            cam.childNode(withName: "bossBarFill")?.isHidden = false
            cam.childNode(withName: "bossNameLabel")?.isHidden = false
            if let fill = cam.childNode(withName: "bossBarFill") as? SKShapeNode {
                let pct = CGFloat(hydra.bodyHealth) / CGFloat(hydra.maxBodyHealth)
                fill.xScale = max(0, pct)
            }
            if let nameLabel = cam.childNode(withName: "bossNameLabel") as? SKLabelNode {
                nameLabel.text = hydra.bossName
            }
        } else if let b = boss {
            cam.childNode(withName: "bossBarBg")?.isHidden = false
            cam.childNode(withName: "bossBarFill")?.isHidden = false
            cam.childNode(withName: "bossNameLabel")?.isHidden = false
            if let fill = cam.childNode(withName: "bossBarFill") as? SKShapeNode {
                let pct = CGFloat(b.health) / CGFloat(b.maxHealth)
                fill.xScale = max(0, pct)
            }
            if let nameLabel = cam.childNode(withName: "bossNameLabel") as? SKLabelNode {
                nameLabel.text = b.bossName ?? "BOSS"
            }
        } else {
            cam.childNode(withName: "bossBarBg")?.isHidden = true
            cam.childNode(withName: "bossBarFill")?.isHidden = true
            cam.childNode(withName: "bossNameLabel")?.isHidden = true
        }
    }
    
    func gameOver() {
        player.health = 100; player.reset(); levelManager.loadLevel(levelManager.currentLevel); player.position = CGPoint(x: -200, y: 0); player.physicsBody?.velocity = .zero
        let overlay = SKLabelNode(fontNamed: "Courier-Bold"); overlay.text = "SYSTEM FAILURE - REBOOTING..."; overlay.fontSize = 40; overlay.fontColor = .red; overlay.position = CGPoint(x: 0, y: 0)
        cam.addChild(overlay); overlay.run(SKAction.sequence([SKAction.wait(forDuration: 1.5), SKAction.removeFromParent()]))
    }
    
    func showWinScreen() {
        let overlay = SKShapeNode(rectOf: CGSize(width: 2000, height: 2000)); overlay.fillColor = .black; overlay.alpha = 0.0; overlay.zPosition = 200; cam.addChild(overlay)
        let winLabel = SKLabelNode(fontNamed: "Courier-Bold"); winLabel.text = "PROJECT HYDRA NEUTRALIZED"; winLabel.fontSize = 40; winLabel.fontColor = .green; winLabel.position = CGPoint(x: 0, y: 50); overlay.addChild(winLabel)
        let subLabel = SKLabelNode(fontNamed: "Courier"); subLabel.text = "YOU WIN! SYSTEM RESTORED."; subLabel.fontSize = 20; subLabel.fontColor = .white; subLabel.position = CGPoint(x: 0, y: -20); overlay.addChild(subLabel)
        overlay.run(SKAction.fadeAlpha(to: 0.9, duration: 2.0))
    }
    
    func toggleLevelSelect() {
        isLevelSelecting = !isLevelSelecting
        levelTitleClickCount = 0
        if isLevelSelecting {
            let menu = SKShapeNode(rectOf: CGSize(width: 600, height: 500), cornerRadius: 20); menu.fillColor = .black; menu.strokeColor = .white; menu.lineWidth = 4; menu.name = "levelSelectMenu"; menu.zPosition = 300; cam.addChild(menu)
            let title = SKLabelNode(fontNamed: "Courier-Bold"); title.text = "LEVEL SELECT"; title.fontSize = 30; title.position = CGPoint(x: 0, y: 200); title.name = "levelSelectTitle"; title.isUserInteractionEnabled = true; menu.addChild(title)
            let subtitle = SKLabelNode(fontNamed: "Courier"); subtitle.text = "Type Level Number + Enter"; subtitle.fontSize = 16; subtitle.position = CGPoint(x: 0, y: 170); menu.addChild(subtitle)
            let maxLevel = max(1, UserDefaults.standard.integer(forKey: "ProjectHydra_MaxLevel"))
            for i in 1...15 {
                let label = SKLabelNode(fontNamed: "Courier"); label.text = "\(i)"; label.fontSize = 24
                let col = (i - 1) % 5; let row = (i - 1) / 5; label.position = CGPoint(x: -200 + CGFloat(col * 100), y: 80 - CGFloat(row * 80))
                label.fontColor = i <= maxLevel ? .green : .darkGray; menu.addChild(label)
            }
        } else { cam.childNode(withName: "levelSelectMenu")?.removeFromParent() }
    }
    
    func startNextLevel() {
        if levelManager.currentLevel >= 15 { showWinScreen(); return }
        goToLevel(levelManager.currentLevel + 1)
    }
    
    func goToLevel(_ level: Int) {
        levelManager.loadLevel(level)
        if let label = cam.childNode(withName: "levelLabel") as? SKLabelNode {
            label.text = "LEVEL \(level)"
            if level == 5 { label.text = "MINIBOSS: TANK" }
            if level == 10 { label.text = "BOSS: GATEKEEPER" }
            if level == 15 { label.text = "THE HYDRA" }
        }
        player.position = CGPoint(x: -200, y: 0); player.physicsBody?.velocity = .zero; player.health = 100; player.reset()
    }
    
    var levelInputBuffer = ""
    
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 37 { toggleLevelSelect(); return }
        if isLevelSelecting {
            if event.keyCode == 36 {
                if let level = Int(levelInputBuffer) {
                    let maxLevel = max(1, UserDefaults.standard.integer(forKey: "ProjectHydra_MaxLevel"))
                    if level > 0 && level <= maxLevel { goToLevel(level); toggleLevelSelect() }
                }
                levelInputBuffer = ""
            } else if let chars = event.characters, let _ = Int(chars) { levelInputBuffer += chars }
            return
        }
        switch event.keyCode {
        case 0: leftPressed = true
        case 2: rightPressed = true
        case 49: jumpPressed = true
        case 13: player.shoot(scene: self)
        default: break
        }
    }
    
    override func keyUp(with event: NSEvent) {
        switch event.keyCode {
        case 0: leftPressed = false
        case 2: rightPressed = false
        case 49: jumpPressed = false
        default: break
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        if isLevelSelecting {
            let location = event.location(in: self)
            let nodesAtLocation = self.nodes(at: location)
            for node in nodesAtLocation {
                if node.name == "levelSelectTitle" {
                    let currentTime = event.timestamp
                    if currentTime - levelTitleLastClickTime < 1.0 {
                        levelTitleClickCount += 1
                    } else {
                        levelTitleClickCount = 1
                    }
                    levelTitleLastClickTime = currentTime
                    if levelTitleClickCount >= 7 {
                        UserDefaults.standard.set(15, forKey: "ProjectHydra_MaxLevel")
                        if let menu = cam.childNode(withName: "levelSelectMenu") {
                            for child in menu.children {
                                if let label = child as? SKLabelNode, label.fontColor == .darkGray {
                                    label.fontColor = .green
                                }
                            }
                        }
                        let flash = SKAction.sequence([
                            SKAction.colorize(with: .green, colorBlendFactor: 1.0, duration: 0.1),
                            SKAction.colorize(with: .white, colorBlendFactor: 0.0, duration: 0.1)
                        ])
                        if let title = node as? SKLabelNode {
                            title.run(flash)
                        }
                    }
                    return
                }
            }
        }
        if !isLevelSelecting { player.shoot(scene: self) }
    }
    
    func didBegin(_ contact: SKPhysicsContact) {
        let maskA = contact.bodyA.categoryBitMask
        let maskB = contact.bodyB.categoryBitMask

        let playerNode = (maskA == PhysicsCategory.player) ? contact.bodyA.node : ((maskB == PhysicsCategory.player) ? contact.bodyB.node : nil)
        let otherNode = (maskA == PhysicsCategory.player) ? contact.bodyB.node : ((maskB == PhysicsCategory.player) ? contact.bodyA.node : nil)

        if let player = playerNode as? Player, let other = otherNode {
            let otherMask = other.physicsBody?.categoryBitMask ?? 0

            // Wall/Ground Check for Jump
            if otherMask == PhysicsCategory.ground || otherMask == PhysicsCategory.movingPlatform {
                let playerBottom = player.position.y - (player.size.height / 2)
                let otherTop = other.position.y + (other.frame.size.height / 2)

                if playerBottom > otherTop - 10 {
                    player.isGrounded = true
                } else {
                    // Wall check
                    if player.position.x < other.position.x {
                        player.isTouchingWallRight = true
                    } else {
                        player.isTouchingWallLeft = true
                    }
                }
            }

            if otherMask == PhysicsCategory.portal { startNextLevel() }
            if otherMask == PhysicsCategory.trap { player.takeDamage(25) }
            if otherMask == PhysicsCategory.enemyProjectile { player.takeDamage(15); other.removeFromParent() }
            if otherMask == PhysicsCategory.enemy || otherMask == PhysicsCategory.boss { player.takeDamage(20) }
        }

        // Projectile collisions
        if (maskA == PhysicsCategory.playerProjectile && (maskB == PhysicsCategory.enemy || maskB == PhysicsCategory.boss)) ||
           (maskB == PhysicsCategory.playerProjectile && (maskA == PhysicsCategory.enemy || maskA == PhysicsCategory.boss)) {
            let projectile = (maskA == PhysicsCategory.playerProjectile) ? contact.bodyA.node : contact.bodyB.node
            let enemy = (maskA == PhysicsCategory.playerProjectile) ? contact.bodyB.node : contact.bodyA.node

            projectile?.removeFromParent()

            // Check if it hit the Hydra body
            if let hydra = enemy?.parent as? HydraBoss, enemy === hydra.bodyNode {
                hydra.takeBodyDamage(amount: 1)
            } else if let e = enemy as? Enemy {
                e.takeDamage(amount: 1)
            }
        }
    }
    
    func didEnd(_ contact: SKPhysicsContact) {
        let maskA = contact.bodyA.categoryBitMask
        let maskB = contact.bodyB.categoryBitMask
        if maskA == PhysicsCategory.player || maskB == PhysicsCategory.player {
            player.isGrounded = false
            player.isTouchingWallLeft = false
            player.isTouchingWallRight = false
        }
    }
}
