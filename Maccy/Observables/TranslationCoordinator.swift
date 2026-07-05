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
  private var pendingStartedAt: Date?

  func translate(_ decorator: HistoryItemDecorator) {
    // A previous request that never completed must not block translation forever.
    if let startedAt = pendingStartedAt, Date().timeIntervalSince(startedAt) > 60 {
      resetPending()
    }
    guard pendingText == nil else { return } // one translation at a time

    let text = decorator.item.previewableText
    guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

    pendingText = text
    pendingDecorator = decorator
    pendingStartedAt = Date()
    decorator.isAccessoryActionRunning = true

    Task {
      let (source, target) = direction(for: text)

      // The popup is a nonactivating panel, so the system model-download prompt
      // cannot be presented from here — sending an unprepared pair into
      // translationTask would hang forever. Check first and redirect to the
      // settings pane, which lives in a regular window and can download models.
      let availability = LanguageAvailability()
      let status: LanguageAvailability.Status
      if let source {
        status = await availability.status(from: source, to: target)
      } else {
        status = (try? await availability.status(for: text, to: target)) ?? .unsupported
      }

      switch status {
      case .installed:
        if configuration != nil {
          configuration?.source = source
          configuration?.target = target
          configuration?.invalidate() // re-fires translationTask even for an unchanged pair
        } else {
          configuration = TranslationSession.Configuration(source: source, target: target)
        }
      case .supported:
        resetPending()
        Notifier.notify(body: NSLocalizedString("translation_models_missing", comment: ""), sound: nil)
        AppState.shared.openPreferences(pane: .translation)
      default:
        resetPending()
        Notifier.notify(body: NSLocalizedString("translation_failed", comment: ""), sound: nil)
      }
    }
  }

  // Called only from ContentView's .translationTask closure.
  func run(in session: TranslationSession) async {
    // Guards against spurious re-invocations (view re-appearing with a stale configuration).
    guard let text = pendingText else { return }
    defer { resetPending() }

    do {
      let response = try await session.translate(text)
      Clipboard.shared.copyInMaccy(response.targetText)
    } catch {
      Notifier.notify(body: NSLocalizedString("translation_failed", comment: ""), sound: nil)
      NSLog("Translation failed: \(error)")
    }
  }

  private func resetPending() {
    pendingText = nil
    pendingDecorator?.isAccessoryActionRunning = false
    pendingDecorator = nil
    pendingStartedAt = nil
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
