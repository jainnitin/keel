#!/usr/bin/env swift
import AppKit
import Foundation

let outputDirectory = URL(
  fileURLWithPath: CommandLine.arguments.dropFirst().first
    ?? "Sources/LeafPDF/Resources/Assets.xcassets/AppIcon.appiconset")
try FileManager.default.createDirectory(
  at: outputDirectory,
  withIntermediateDirectories: true
)

let variants: [(filename: String, pixels: Int)] = [
  ("AppIcon-16.png", 16),
  ("AppIcon-16@2x.png", 32),
  ("AppIcon-32.png", 32),
  ("AppIcon-32@2x.png", 64),
  ("AppIcon-128.png", 128),
  ("AppIcon-128@2x.png", 256),
  ("AppIcon-256.png", 256),
  ("AppIcon-256@2x.png", 512),
  ("AppIcon-512.png", 512),
  ("AppIcon-512@2x.png", 1_024),
]

func scaledPath(_ points: [(CGFloat, CGFloat)], size: CGFloat, closed: Bool = true) -> NSBezierPath
{
  let path = NSBezierPath()
  guard let first = points.first else {
    return path
  }
  path.move(to: NSPoint(x: first.0 * size, y: first.1 * size))
  for point in points.dropFirst() {
    path.line(to: NSPoint(x: point.0 * size, y: point.1 * size))
  }
  if closed {
    path.close()
  }
  return path
}

func renderIcon(pixels: Int, destination: URL) throws {
  let size = CGFloat(pixels)
  guard
    let bitmap = NSBitmapImageRep(
      bitmapDataPlanes: nil,
      pixelsWide: pixels,
      pixelsHigh: pixels,
      bitsPerSample: 8,
      samplesPerPixel: 4,
      hasAlpha: true,
      isPlanar: false,
      colorSpaceName: .deviceRGB,
      bytesPerRow: 0,
      bitsPerPixel: 0
    ),
    let context = NSGraphicsContext(bitmapImageRep: bitmap)
  else {
    throw NSError(domain: "LeafPDFIcon", code: 1)
  }

  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = context
  defer {
    NSGraphicsContext.restoreGraphicsState()
  }

  context.imageInterpolation = .high

  let outerRect = NSRect(
    x: size * 0.035,
    y: size * 0.035,
    width: size * 0.93,
    height: size * 0.93
  )
  let outer = NSBezierPath(
    roundedRect: outerRect,
    xRadius: size * 0.215,
    yRadius: size * 0.215
  )
  let background = NSGradient(
    starting: NSColor(calibratedRed: 0.055, green: 0.35, blue: 0.31, alpha: 1),
    ending: NSColor(calibratedRed: 0.02, green: 0.15, blue: 0.18, alpha: 1)
  )!
  background.draw(in: outer, angle: -52)

  let highlight = NSBezierPath(
    ovalIn: NSRect(
      x: size * 0.08,
      y: size * 0.50,
      width: size * 0.82,
      height: size * 0.57
    ))
  NSGraphicsContext.saveGraphicsState()
  outer.addClip()
  NSColor(calibratedWhite: 1, alpha: 0.075).setFill()
  highlight.fill()
  NSGraphicsContext.restoreGraphicsState()

  let shadow = NSShadow()
  shadow.shadowColor = NSColor(calibratedWhite: 0, alpha: 0.25)
  shadow.shadowBlurRadius = size * 0.035
  shadow.shadowOffset = NSSize(width: 0, height: -size * 0.018)
  NSGraphicsContext.saveGraphicsState()
  shadow.set()

  let document = NSBezierPath(
    roundedRect: NSRect(
      x: size * 0.235,
      y: size * 0.18,
      width: size * 0.53,
      height: size * 0.67
    ),
    xRadius: size * 0.055,
    yRadius: size * 0.055
  )
  NSColor(calibratedRed: 0.965, green: 0.975, blue: 0.96, alpha: 1).setFill()
  document.fill()
  NSGraphicsContext.restoreGraphicsState()

  let fold = scaledPath(
    [
      (0.60, 0.85),
      (0.765, 0.685),
      (0.765, 0.83),
      (0.745, 0.85),
    ], size: size)
  NSColor(calibratedRed: 0.72, green: 0.84, blue: 0.79, alpha: 1).setFill()
  fold.fill()

  let leaf = NSBezierPath()
  leaf.move(to: NSPoint(x: size * 0.34, y: size * 0.38))
  leaf.curve(
    to: NSPoint(x: size * 0.665, y: size * 0.66),
    controlPoint1: NSPoint(x: size * 0.35, y: size * 0.60),
    controlPoint2: NSPoint(x: size * 0.53, y: size * 0.74)
  )
  leaf.curve(
    to: NSPoint(x: size * 0.34, y: size * 0.38),
    controlPoint1: NSPoint(x: size * 0.69, y: size * 0.45),
    controlPoint2: NSPoint(x: size * 0.56, y: size * 0.30)
  )
  leaf.close()
  let leafGradient = NSGradient(
    starting: NSColor(calibratedRed: 0.20, green: 0.69, blue: 0.43, alpha: 1),
    ending: NSColor(calibratedRed: 0.04, green: 0.39, blue: 0.29, alpha: 1)
  )!
  leafGradient.draw(in: leaf, angle: 40)

  let vein = NSBezierPath()
  vein.move(to: NSPoint(x: size * 0.365, y: size * 0.38))
  vein.curve(
    to: NSPoint(x: size * 0.63, y: size * 0.625),
    controlPoint1: NSPoint(x: size * 0.45, y: size * 0.43),
    controlPoint2: NSPoint(x: size * 0.54, y: size * 0.54)
  )
  vein.lineWidth = max(size * 0.018, 1)
  vein.lineCapStyle = .round
  NSColor(calibratedWhite: 1, alpha: 0.82).setStroke()
  vein.stroke()

  let readingLine = NSBezierPath()
  readingLine.move(to: NSPoint(x: size * 0.35, y: size * 0.29))
  readingLine.line(to: NSPoint(x: size * 0.65, y: size * 0.29))
  readingLine.lineWidth = max(size * 0.025, 1)
  readingLine.lineCapStyle = .round
  NSColor(calibratedRed: 0.13, green: 0.32, blue: 0.29, alpha: 0.65).setStroke()
  readingLine.stroke()

  guard let png = bitmap.representation(using: .png, properties: [:]) else {
    throw NSError(domain: "LeafPDFIcon", code: 1)
  }
  try png.write(to: destination, options: .atomic)
}

for variant in variants {
  let destination = outputDirectory.appendingPathComponent(variant.filename)
  try renderIcon(pixels: variant.pixels, destination: destination)
}
