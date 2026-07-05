import Defaults
import Foundation
import NaturalLanguage
import Observation
import Translation

@Observable
@MainActor
final class TranslationCoordinator {
  static let shared = TranslationCoordinator()

  // Observed by ContentView's .translationTask.
  var configuration: TranslationSession.Configuration?

  private var pendingText: String?
  private var pendingDecorator: HistoryItemDecorator?

  func translate(_ decorator: HistoryItemDecorator) {
    guard pendingText == nil else { return } // one translation at a time
    let text = decorator.item.previewableText
    guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

    let (source, target) = direction(for: text)
    pendingText = text
    pendingDecorator = decorator
    decorator.isAccessoryActionRunning = true

    if configuration != nil {
      configuration?.source = source
      configuration?.target = target
      configuration?.invalidate() // re-fires translationTask even for an unchanged pair
    } else {
      configuration = TranslationSession.Configuration(source: source, target: target)
    }
  }

  // Called only from ContentView's .translationTask closure.
  func run(in session: TranslationSession) async {
    // Guards against spurious re-invocations (view re-appearing with a stale configuration).
    guard let text = pendingText else { return }
    defer {
      pendingText = nil
      pendingDecorator?.isAccessoryActionRunning = false
      pendingDecorator = nil
    }

    do {
      // Presents the system model-download prompt when models are missing.
      try await session.prepareTranslation()
      let response = try await session.translate(text)
      Clipboard.shared.copyInMaccy(response.targetText)
    } catch {
      Notifier.notify(body: NSLocalizedString("translation_failed", comment: ""), sound: nil)
      NSLog("Translation failed: \(error)")
    }
  }

  // Text in the native language goes native→foreign; anything else goes →native
  // (with the detected language as source when known).
  private func direction(for text: String) -> (Locale.Language?, Locale.Language) {
    let recognizer = NLLanguageRecognizer()
    recognizer.processString(String(text.prefix(500)))
    let detected = recognizer.dominantLanguage?.rawValue

    let native = Defaults[.translationNativeLanguage]
    let foreign = Defaults[.translationForeignLanguage]

    if let detected, detected == native || detected.hasPrefix(native + "-") {
      return (Locale.Language(identifier: native), Locale.Language(identifier: foreign))
    }
    return (detected.map { Locale.Language(identifier: $0) }, Locale.Language(identifier: native))
  }
}
