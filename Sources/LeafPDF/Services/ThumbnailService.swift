import CoreGraphics
import Foundation

actor ThumbnailService {
  private struct CacheKey: Hashable {
    let pageIndex: Int
    let maximumDimension: Int
    let displayScale: Int
  }

  private struct CacheEntry {
    let image: CGImage
    let cost: Int
    var lastAccess: UInt64
  }

  private let document: CGPDFDocument?
  private let costLimit: Int
  private let countLimit: Int
  private var entries: [CacheKey: CacheEntry] = [:]
  private var totalCost = 0
  private var accessCounter: UInt64 = 0

  init(url: URL, costLimit: Int = 48 * 1_024 * 1_024, countLimit: Int = 96) {
    document = CGPDFDocument(url as CFURL)
    self.costLimit = max(costLimit, 1)
    self.countLimit = max(countLimit, 1)
  }

  func thumbnail(
    pageIndex: Int,
    maximumDimension: CGFloat,
    displayScale: CGFloat
  ) throws -> CGImage {
    try Task.checkCancellation()
    let key = CacheKey(
      pageIndex: pageIndex,
      maximumDimension: max(Int(maximumDimension.rounded()), 1),
      displayScale: max(Int(displayScale.rounded()), 1)
    )
    accessCounter &+= 1

    if var entry = entries[key] {
      entry.lastAccess = accessCounter
      entries[key] = entry
      return entry.image
    }

    guard
      let document,
      let page = document.page(at: pageIndex + 1)
    else {
      throw ThumbnailError.pageUnavailable(pageIndex + 1)
    }

    let bounds = page.getBoxRect(.cropBox)
    guard bounds.width > 0, bounds.height > 0 else {
      throw ThumbnailError.invalidPageBounds(pageIndex + 1)
    }

    let scaleToFit = maximumDimension / max(bounds.width, bounds.height)
    let pointSize = CGSize(
      width: max(bounds.width * scaleToFit, 1),
      height: max(bounds.height * scaleToFit, 1)
    )
    let pixelSize = CGSize(
      width: max((pointSize.width * displayScale).rounded(.up), 1),
      height: max((pointSize.height * displayScale).rounded(.up), 1)
    )

    guard
      let context = CGContext(
        data: nil,
        width: Int(pixelSize.width),
        height: Int(pixelSize.height),
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
      )
    else {
      throw ThumbnailError.renderingFailed(pageIndex + 1)
    }

    try Task.checkCancellation()
    context.setFillColor(CGColor(gray: 1, alpha: 1))
    context.fill(CGRect(origin: .zero, size: pixelSize))
    let target = CGRect(origin: .zero, size: pixelSize)
    let transform = page.getDrawingTransform(
      .cropBox,
      rect: target,
      rotate: 0,
      preserveAspectRatio: true
    )
    context.concatenate(transform)
    context.drawPDFPage(page)
    try Task.checkCancellation()

    guard let image = context.makeImage() else {
      throw ThumbnailError.renderingFailed(pageIndex + 1)
    }

    let cost = image.bytesPerRow * image.height
    entries[key] = CacheEntry(image: image, cost: cost, lastAccess: accessCounter)
    totalCost += cost
    evictIfNeeded()
    return image
  }

  func removeAll() {
    entries.removeAll(keepingCapacity: false)
    totalCost = 0
  }

  private func evictIfNeeded() {
    while totalCost > costLimit || entries.count > countLimit {
      guard let oldest = entries.min(by: { $0.value.lastAccess < $1.value.lastAccess }) else {
        break
      }
      totalCost -= oldest.value.cost
      entries.removeValue(forKey: oldest.key)
    }
  }
}

enum ThumbnailError: LocalizedError {
  case pageUnavailable(Int)
  case invalidPageBounds(Int)
  case renderingFailed(Int)

  var errorDescription: String? {
    switch self {
    case .pageUnavailable(let page):
      "Page \(page) is unavailable."
    case .invalidPageBounds(let page):
      "Page \(page) has invalid dimensions."
    case .renderingFailed(let page):
      "A thumbnail for page \(page) could not be rendered."
    }
  }
}
