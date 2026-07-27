#!/usr/bin/swift

import AppKit
import Foundation

guard CommandLine.arguments.count == 4 else {
    fputs(
        "Usage: render-dmg-background.swift <output.png> <brand-icon.png> <version>\n",
        stderr
    )
    exit(64)
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let iconURL = URL(fileURLWithPath: CommandLine.arguments[2])
let version = CommandLine.arguments[3]
let size = NSSize(width: 660, height: 430)
let image = NSImage(size: size)

func drawText(
    _ text: String,
    in rect: NSRect,
    font: NSFont,
    color: NSColor,
    alignment: NSTextAlignment = .left
) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = alignment
    (text as NSString).draw(
        in: rect,
        withAttributes: [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]
    )
}

image.lockFocus()

NSColor.white.setFill()
NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()

let headerLine = NSBezierPath()
headerLine.move(to: NSPoint(x: 32, y: 326))
headerLine.line(to: NSPoint(x: 628, y: 326))
headerLine.lineWidth = 1
NSColor(calibratedWhite: 0.84, alpha: 1).setStroke()
headerLine.stroke()

if let brandIcon = NSImage(contentsOf: iconURL) {
    brandIcon.draw(
        in: NSRect(x: 32, y: 348, width: 58, height: 58),
        from: .zero,
        operation: .sourceOver,
        fraction: 1
    )
}

drawText(
    "Mac Smooth Scroll",
    in: NSRect(x: 106, y: 369, width: 360, height: 28),
    font: .systemFont(ofSize: 24, weight: .semibold),
    color: NSColor(calibratedWhite: 0.10, alpha: 1)
)
drawText(
    "Version \(version) • Apple Silicon",
    in: NSRect(x: 108, y: 346, width: 300, height: 20),
    font: .systemFont(ofSize: 13, weight: .regular),
    color: NSColor(calibratedWhite: 0.40, alpha: 1)
)

drawText(
    "Drag Mac Smooth Scroll to Applications",
    in: NSRect(x: 80, y: 285, width: 500, height: 26),
    font: .systemFont(ofSize: 18, weight: .medium),
    color: NSColor(calibratedWhite: 0.12, alpha: 1),
    alignment: .center
)

let arrow = NSBezierPath()
arrow.move(to: NSPoint(x: 285, y: 207))
arrow.line(to: NSPoint(x: 375, y: 207))
arrow.move(to: NSPoint(x: 354, y: 227))
arrow.line(to: NSPoint(x: 376, y: 207))
arrow.line(to: NSPoint(x: 354, y: 187))
arrow.lineCapStyle = .round
arrow.lineJoinStyle = .round
arrow.lineWidth = 5
NSColor(calibratedRed: 0.24, green: 0.64, blue: 1, alpha: 0.9).setStroke()
arrow.stroke()

drawText(
    "1. Drag to install     2. Open from Applications     3. Allow Accessibility",
    in: NSRect(x: 42, y: 38, width: 576, height: 20),
    font: .systemFont(ofSize: 12, weight: .medium),
    color: NSColor(calibratedWhite: 0.28, alpha: 1),
    alignment: .center
)
drawText(
    "Preview build • Not notarized • macOS may require Open Anyway",
    in: NSRect(x: 42, y: 23, width: 576, height: 18),
    font: .systemFont(ofSize: 11, weight: .regular),
    color: NSColor(calibratedWhite: 0.50, alpha: 1),
    alignment: .center
)

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let representation = NSBitmapImageRep(data: tiff),
      let png = representation.representation(using: .png, properties: [:]) else {
    fputs("Could not render the DMG background.\n", stderr)
    exit(1)
}

try FileManager.default.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)
try png.write(to: outputURL, options: .atomic)
