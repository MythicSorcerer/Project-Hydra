#!/usr/bin/swift
import Cocoa

// Helper functions for drawing
func drawRect(_ rect: NSRect, color: NSColor) {
    color.setFill()
    rect.fill()
}

func drawCircle(_ rect: NSRect, color: NSColor) {
    color.setFill()
    NSBezierPath(ovalIn: rect).fill()
}

func saveImage(name: String, size: NSSize, draw: () -> Void) {
    let image = NSImage(size: size)
    image.lockFocus()
    // Clear background
    NSColor.clear.set()
    NSRect(origin: .zero, size: size).fill()
    draw()
    image.unlockFocus()
    
    if let data = image.tiffRepresentation,
       let bitmap = NSBitmapImageRep(data: data),
       let pngData = bitmap.representation(using: .png, properties: [:]) {
        let url = URL(fileURLWithPath: "Project Hydra/Assets.xcassets/\(name).imageset")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        try? pngData.write(to: url.appendingPathComponent("\(name).png"))
        
        let json = """
        {
          "images" : [
            {
              "filename" : "\(name).png",
              "idiom" : "universal",
              "scale" : "1x"
            },
            {
              "idiom" : "universal",
              "scale" : "2x"
            },
            {
              "idiom" : "universal",
              "scale" : "3x"
            }
          ],
          "info" : {
            "author" : "xcode",
            "version" : 1
          }
        }
        """
        try? json.write(to: url.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
        print("Saved \(name)")
    }
}

// ---------------- ASSETS ----------------

// Player (Blue Mech)
saveImage(name: "PlayerIdle", size: NSSize(width: 64, height: 64)) {
    // Body
    drawRect(NSRect(x: 20, y: 20, width: 24, height: 24), color: NSColor.systemBlue)
    // Head
    drawRect(NSRect(x: 24, y: 44, width: 16, height: 12), color: NSColor.systemTeal)
    // Legs
    drawRect(NSRect(x: 20, y: 4, width: 8, height: 16), color: NSColor.darkGray)
    drawRect(NSRect(x: 36, y: 4, width: 8, height: 16), color: NSColor.darkGray)
    // Arms
    drawRect(NSRect(x: 10, y: 24, width: 10, height: 20), color: NSColor.systemBlue) // Left Arm
    drawRect(NSRect(x: 44, y: 24, width: 12, height: 20), color: NSColor.systemBlue) // Right Arm (Gun)
    // Gun Barrel
    drawRect(NSRect(x: 56, y: 28, width: 8, height: 6), color: NSColor.gray)
}

saveImage(name: "PlayerRun", size: NSSize(width: 64, height: 64)) {
    // Body
    drawRect(NSRect(x: 22, y: 22, width: 24, height: 24), color: NSColor.systemBlue)
    // Head
    drawRect(NSRect(x: 26, y: 46, width: 16, height: 12), color: NSColor.systemTeal)
    // Legs (Running pose)
    drawRect(NSRect(x: 14, y: 8, width: 10, height: 14), color: NSColor.darkGray) // Back leg
    drawRect(NSRect(x: 40, y: 8, width: 10, height: 14), color: NSColor.darkGray) // Front leg
    // Booster flame
    drawCircle(NSRect(x: 10, y: 4, width: 8, height: 8), color: NSColor.orange)
}

// Enemy Walker (Red)
saveImage(name: "EnemyWalker", size: NSSize(width: 64, height: 64)) {
    // Body
    drawCircle(NSRect(x: 16, y: 16, width: 32, height: 32), color: NSColor.systemRed)
    // Eye
    drawCircle(NSRect(x: 36, y: 32, width: 8, height: 8), color: NSColor.yellow)
    // Legs
    drawRect(NSRect(x: 20, y: 0, width: 6, height: 16), color: NSColor.gray)
    drawRect(NSRect(x: 38, y: 0, width: 6, height: 16), color: NSColor.gray)
}

// Enemy Flyer (Green Drone)
saveImage(name: "EnemyFlyer", size: NSSize(width: 64, height: 64)) {
    // Body
    drawCircle(NSRect(x: 20, y: 20, width: 24, height: 24), color: NSColor.systemGreen)
    // Wings/Rotors
    drawRect(NSRect(x: 8, y: 36, width: 48, height: 4), color: NSColor.lightGray)
    // Eye
    drawCircle(NSRect(x: 28, y: 24, width: 8, height: 8), color: NSColor.red)
}

// Miniboss (Big Tank)
saveImage(name: "Miniboss", size: NSSize(width: 96, height: 96)) {
    // Tracks
    drawRect(NSRect(x: 10, y: 10, width: 76, height: 20), color: NSColor.darkGray)
    // Body
    drawRect(NSRect(x: 20, y: 30, width: 56, height: 40), color: NSColor.systemOrange)
    // Turret
    drawRect(NSRect(x: 30, y: 70, width: 36, height: 20), color: NSColor.brown)
    // Barrel
    drawRect(NSRect(x: 66, y: 76, width: 24, height: 8), color: NSColor.black)
}

// Boss Gatekeeper (Huge Mech)
saveImage(name: "BossGatekeeper", size: NSSize(width: 128, height: 128)) {
    // Legs
    drawRect(NSRect(x: 30, y: 10, width: 20, height: 50), color: NSColor.black)
    drawRect(NSRect(x: 78, y: 10, width: 20, height: 50), color: NSColor.black)
    // Body
    drawRect(NSRect(x: 30, y: 60, width: 68, height: 60), color: NSColor.systemPurple)
    // Head
    drawRect(NSRect(x: 54, y: 100, width: 20, height: 20), color: NSColor.cyan)
    // Arms
    drawRect(NSRect(x: 10, y: 60, width: 20, height: 50), color: NSColor.darkGray)
    drawRect(NSRect(x: 98, y: 60, width: 20, height: 50), color: NSColor.darkGray)
}

// Hydra Head (Serpent)
saveImage(name: "HydraHead", size: NSSize(width: 64, height: 64)) {
    // Head shape
    let path = NSBezierPath()
    path.move(to: NSPoint(x: 10, y: 20))
    path.line(to: NSPoint(x: 50, y: 32)) // Snout tip
    path.line(to: NSPoint(x: 10, y: 44))
    path.close()
    NSColor.systemGreen.setFill()
    path.fill()
    
    // Eye
    drawCircle(NSRect(x: 30, y: 34, width: 6, height: 6), color: NSColor.yellow)
    // Teeth
    drawRect(NSRect(x: 40, y: 28, width: 4, height: 4), color: NSColor.white)
}

// Hydra Neck (Segment)
saveImage(name: "HydraNeck", size: NSSize(width: 32, height: 32)) {
    drawCircle(NSRect(x: 4, y: 4, width: 24, height: 24), color: NSColor.systemGreen.withAlphaComponent(0.8))
}

// Tiles
saveImage(name: "TileGround", size: NSSize(width: 64, height: 64)) {
    drawRect(NSRect(x: 0, y: 0, width: 64, height: 64), color: NSColor.darkGray)
    // Detail
    drawRect(NSRect(x: 4, y: 4, width: 56, height: 56), color: NSColor.gray)
    drawRect(NSRect(x: 8, y: 8, width: 48, height: 48), color: NSColor.lightGray)
}

saveImage(name: "TilePlatform", size: NSSize(width: 64, height: 20)) {
    drawRect(NSRect(x: 0, y: 0, width: 64, height: 20), color: NSColor.brown)
    // Stripes
    NSColor.yellow.setFill()
    let path = NSBezierPath()
    path.move(to: NSPoint(x: 10, y: 0)); path.line(to: NSPoint(x: 20, y: 20)); path.line(to: NSPoint(x: 30, y: 20)); path.line(to: NSPoint(x: 20, y: 0)); path.close()
    path.fill()
}

// Projectiles
saveImage(name: "BulletPlayer", size: NSSize(width: 16, height: 8)) {
    drawRect(NSRect(x: 0, y: 0, width: 16, height: 8), color: NSColor.yellow)
}

saveImage(name: "BulletEnemy", size: NSSize(width: 12, height: 12)) {
    drawCircle(NSRect(x: 0, y: 0, width: 12, height: 12), color: NSColor.red)
}

// Hydra Body (Main Mass)
saveImage(name: "HydraBody", size: NSSize(width: 160, height: 120)) {
    // Body mass
    let path = NSBezierPath()
    path.appendArc(withCenter: NSPoint(x: 80, y: 60), radius: 60, startAngle: 0, endAngle: 180)
    path.line(to: NSPoint(x: 20, y: 40))
    path.line(to: NSPoint(x: 140, y: 40))
    path.close()
    NSColor.systemGreen.setFill()
    path.fill()
    // Scales/Detail
    NSColor.black.withAlphaComponent(0.2).setStroke()
    for i in 0..<5 {
        let x = 40 + CGFloat(i * 20)
        NSBezierPath(ovalIn: NSRect(x: x, y: 50, width: 10, height: 10)).stroke()
    }
}

// Hydra Spawn (Small Crawler)
saveImage(name: "HydraSpawn", size: NSSize(width: 32, height: 32)) {
    drawCircle(NSRect(x: 4, y: 8, width: 24, height: 16), color: NSColor.systemGreen)
    drawCircle(NSRect(x: 20, y: 16, width: 6, height: 6), color: NSColor.yellow) // Eye
    // Tiny legs
    drawRect(NSRect(x: 8, y: 4, width: 4, height: 4), color: NSColor.darkGray)
    drawRect(NSRect(x: 20, y: 4, width: 4, height: 4), color: NSColor.darkGray)
}

print("All assets generated.")
