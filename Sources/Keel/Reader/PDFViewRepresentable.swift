import KeelCore
import PDFKit
import SwiftUI

struct PDFViewRepresentable: NSViewRepresentable {
  let document: PDFDocument
  let layout: ReaderLayout
  let controller: PDFViewController

  func makeNSView(context: Context) -> PDFView {
    let view = KeelPDFView()
    controller.attach(view, document: document, layout: layout)
    return view
  }

  func updateNSView(_ view: PDFView, context: Context) {
    controller.attach(view, document: document, layout: layout)
  }

  static func dismantleNSView(_ view: PDFView, coordinator: Void) {
    view.document = nil
  }
}
