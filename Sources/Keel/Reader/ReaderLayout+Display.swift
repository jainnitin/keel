import KeelCore

extension ReaderLayout {
  var title: String {
    switch self {
    case .continuous: "Continuous"
    case .singlePage: "Single Page"
    case .twoPages: "Two Pages"
    case .twoPagesContinuous: "Two Pages Continuous"
    }
  }

  var symbolName: String {
    switch self {
    case .continuous: "rectangle.stack"
    case .singlePage: "rectangle"
    case .twoPages: "book"
    case .twoPagesContinuous: "book.pages"
    }
  }

  var isTwoPage: Bool {
    self == .twoPages || self == .twoPagesContinuous
  }
}

/// App-wide reader preferences stored in UserDefaults.
enum ReaderPreferences {
  static let darkPagesKey = "darkPages"
}
