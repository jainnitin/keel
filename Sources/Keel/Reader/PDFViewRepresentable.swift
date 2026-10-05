import KeelCore
import PDFKit
import SwiftUI

struct PDFViewRepresentable: NSViewRepresentable {
  let document: PDFDocument
  let layout: ReaderLayout
  let showsCoverSeparately: Bool
  let darkPages: Bool
  let controller: PDFViewController

  func makeNSView(context: Context) -> PDFView {
    let view = PDFView()
    attach(view)
    return view
  }

  func updateNSView(_ view: PDFView, context: Context) {
    attach(view)
  }

  private func attach(_ view: PDFView) {
    controller.attach(
      view,
      document: document,
      layout: layout,
      showsCoverSeparately: showsCoverSeparately,
      darkPages: darkPages
    )
  }

  static func dismantleNSView(_ view: PDFView, coordinator: Void) {
    view.document = nil
  }
}
