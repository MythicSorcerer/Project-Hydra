#!/usr/bin/swift
import Cocoa

func createTestImage() {
    let size = NSSize(width: 32, height: 32)
    let image = NSImage(size: size)
    image.lockFocus()
    NSColor.red.setFill()
    NSRect(x: 0, y: 0, width: 32, height: 32).fill()
    image.unlockFocus()
    
    if let data = image.tiffRepresentation,
       let bitmap = NSBitmapImageRep(data: data),
       let pngData = bitmap.representation(using: .png, properties: [:]) {
        try? pngData.write(to: URL(fileURLWithPath: "test.png"))
        print("Success")
    } else {
        print("Failed")
    }
}

createTestImage()
