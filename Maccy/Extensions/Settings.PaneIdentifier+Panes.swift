import Settings

// Disambiguates from SwiftUI.Settings in files that import both modules.
typealias SettingsPaneIdentifier = Settings.PaneIdentifier

extension Settings.PaneIdentifier {
  static let advanced = Self("advanced")
  static let appearance = Self("appearance")
  static let general = Self("general")
  static let ignore = Self("ignore")
  static let pins = Self("pins")
  static let storage = Self("storage")
  static let translation = Self("translation")
  static let intelligence = Self("intelligence")
}
