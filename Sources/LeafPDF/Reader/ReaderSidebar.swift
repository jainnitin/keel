import AppKit
import LeafPDFCore
import SwiftUI

struct ReaderSidebar: View {
  @ObservedObject var model: ReaderViewModel

  var body: some View {
    VStack(spacing: 0) {
      SidebarSectionPicker(selection: $model.sidebarSection)
        .padding()

      Divider()

      Group {
        switch model.sidebarSection {
        case .thumbnails:
          ThumbnailSidebar(model: model)
        case .outline:
          OutlineSidebar(model: model)
        case .search:
          SearchResultsSidebar(model: model)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .accessibilityIdentifier("reader.sidebar.content")
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background(.thinMaterial)
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Document sidebar")
  }
}

private struct SidebarSectionPicker: View {
  @Binding var selection: ReaderSidebarSection

  var body: some View {
    ViewThatFits(in: .horizontal) {
      Picker("Sidebar", selection: $selection) {
        Text("Thumbnails")
          .tag(ReaderSidebarSection.thumbnails)
        Text("Contents")
          .tag(ReaderSidebarSection.outline)
        Text("Search")
          .tag(ReaderSidebarSection.search)
      }
      .pickerStyle(.segmented)
      .labelsHidden()
      .frame(width: 244)

      Picker("Sidebar", selection: $selection) {
        Label("Thumbnails", systemImage: "rectangle.stack")
          .labelStyle(.iconOnly)
          .help("Thumbnails")
          .accessibilityLabel("Thumbnails")
          .tag(ReaderSidebarSection.thumbnails)
        Label("Contents", systemImage: "list.bullet.indent")
          .labelStyle(.iconOnly)
          .help("Contents")
          .accessibilityLabel("Contents")
          .tag(ReaderSidebarSection.outline)
        Label("Search", systemImage: "text.magnifyingglass")
          .labelStyle(.iconOnly)
          .help("Search")
          .accessibilityLabel("Search")
          .tag(ReaderSidebarSection.search)
      }
      .pickerStyle(.segmented)
      .labelsHidden()
      .frame(maxWidth: 160)
    }
    .frame(maxWidth: .infinity)
    .accessibilityIdentifier("reader.sidebar.sectionPicker")
  }
}

private struct ThumbnailSidebar: View {
  @ObservedObject var model: ReaderViewModel

  private let columns = [
    GridItem(.adaptive(minimum: 104, maximum: 150), spacing: 12)
  ]

  var body: some View {
    ScrollView {
      LazyVGrid(columns: columns, spacing: 16) {
        ForEach(0..<model.pageCount, id: \.self) { pageIndex in
          ThumbnailCell(
            pageIndex: pageIndex,
            service: model.thumbnailService,
            isCurrent: pageIndex == model.viewer.currentPageIndex
          ) {
            model.viewer.go(toPageIndex: pageIndex)
          }
        }
      }
      .padding(12)
    }
    .accessibilityLabel("Page thumbnails")
  }
}

private struct ThumbnailCell: View {
  let pageIndex: Int
  let service: ThumbnailService
  let isCurrent: Bool
  let action: () -> Void

  @Environment(\.displayScale) private var displayScale
  @State private var image: CGImage?
  @State private var errorDescription: String?

  var body: some View {
    Button(action: action) {
      VStack(spacing: 6) {
        ZStack {
          RoundedRectangle(cornerRadius: 4)
            .fill(.background)
            .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
          if let image {
            Image(decorative: image, scale: displayScale)
              .resizable()
              .scaledToFit()
          } else if errorDescription != nil {
            Image(systemName: "exclamationmark.triangle")
              .foregroundStyle(.secondary)
          } else {
            ProgressView()
              .controlSize(.small)
          }
        }
        .frame(minHeight: 120)
        .overlay {
          RoundedRectangle(cornerRadius: 5)
            .stroke(
              isCurrent ? Color.accentColor : Color.clear,
              lineWidth: 3
            )
        }

        Text("Page \(pageIndex + 1)")
          .font(.caption)
          .foregroundStyle(isCurrent ? .primary : .secondary)
          .monospacedDigit()
      }
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .help(errorDescription ?? "Go to page \(pageIndex + 1)")
    .accessibilityLabel("Page \(pageIndex + 1)")
    .accessibilityAddTraits(isCurrent ? .isSelected : [])
    .task(id: "\(pageIndex)-\(Int(displayScale))") {
      do {
        image = try await service.thumbnail(
          pageIndex: pageIndex,
          maximumDimension: 150,
          displayScale: displayScale
        )
        errorDescription = nil
      } catch is CancellationError {
        return
      } catch {
        errorDescription = error.localizedDescription
      }
    }
  }
}

private struct OutlineSidebar: View {
  @ObservedObject var model: ReaderViewModel

  var body: some View {
    if model.outline.isEmpty {
      ContentUnavailableView(
        "No Table of Contents",
        systemImage: "list.bullet.indent",
        description: Text("This PDF does not contain an outline.")
      )
    } else {
      List(model.outline, children: \.optionalChildren) { item in
        Button {
          if let pageIndex = item.pageIndex {
            model.viewer.go(toPageIndex: pageIndex)
          }
        } label: {
          Text(item.title)
            .lineLimit(2)
            .foregroundStyle(Color(nsColor: .labelColor))
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .disabled(item.pageIndex == nil)
        .help(item.pageIndex.map { "Go to page \($0 + 1)" } ?? item.title)
      }
      .listStyle(.sidebar)
      .accessibilityLabel("Table of contents")
    }
  }
}

private struct SearchResultsSidebar: View {
  @ObservedObject var model: ReaderViewModel
  @ObservedObject private var searchService: PDFSearchService

  init(model: ReaderViewModel) {
    self.model = model
    searchService = model.searchService
  }

  var body: some View {
    Group {
      if model.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        ContentUnavailableView(
          "Search This PDF",
          systemImage: "text.magnifyingglass",
          description: Text("Use the search field in the toolbar.")
        )
      } else if searchService.results.isEmpty, searchService.isSearching {
        ProgressView("Searching…")
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else if searchService.results.isEmpty {
        ContentUnavailableView.search(text: model.searchQuery)
      } else {
        List(searchService.results) { result in
          Button {
            model.goToSearchResult(result)
          } label: {
            VStack(alignment: .leading, spacing: 4) {
              Text("Page \(result.pageLabel)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color(nsColor: .secondaryLabelColor))
              Text(result.excerpt)
                .font(.callout)
                .foregroundStyle(Color(nsColor: .labelColor))
                .lineLimit(4)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 3)
          }
          .buttonStyle(.plain)
          .help("Go to result on page \(result.pageLabel)")
        }
        .listStyle(.sidebar)
      }
    }
    .accessibilityLabel("Search results")
  }
}

extension PDFOutlineNode {
  fileprivate var optionalChildren: [PDFOutlineNode]? {
    children.isEmpty ? nil : children
  }
}
