import AppKit
import Defaults
import Foundation
import KeyboardShortcuts
import NaturalLanguage
import Observation
import Translation

@Observable
@MainActor
final class TranslationCoordinator {
  static let shared = TranslationCoordinator()

  enum RequestError: Error {
    case modelsNotInstalled
    case busy
  }

  // Observed by ContentView's .translationTask.
  var configuration: TranslationSession.Configuration?

  private struct PendingRequest {
    let text: String
    let startedAt: Date
    let continuation: CheckedContinuation<String, Error>
  }
  private var pendingRequest: PendingRequest?

  init() {
    KeyboardShortcuts.onKeyDown(for: .translateAndPaste) { [weak self] in
      self?.translateClipboardAndPaste()
    }
  }

  static func detectLanguage(of text: String) -> Locale.Language? {
    let recognizer = NLLanguageRecognizer()
    recognizer.processString(String(text.prefix(500)))
    return recognizer.dominantLanguage.map { Locale.Language(identifier: $0.rawValue) }
  }

  // MARK: - High-level flows

  func translate(_ decorator: HistoryItemDecorator) {
    let text = decorator.item.previewableText
    guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
          !decorator.isAccessoryActionRunning else { return }

    decorator.isAccessoryActionRunning = true
    Task {
      defer { decorator.isAccessoryActionRunning = false }
      await translateToClipboard(text, pasteAfter: false)
    }
  }

  // Global hotkey: translate whatever is in the clipboard right now and paste
  // the result into the frontmost application.
  func translateClipboardAndPaste() {
    guard let text = NSPasteboard.general.string(forType: .string),
          !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      Notifier.notify(body: NSLocalizedString("translation_nothing_to_translate", comment: ""), sound: nil)
      return
    }
    Task {
      await translateToClipboard(text, pasteAfter: true)
    }
  }

  private func translateToClipboard(_ text: String, pasteAfter: Bool) async {
    do {
      let (source, target) = direction(for: text)
      let result = try await requestTranslation(text, source: source, target: target)
      Clipboard.shared.copyInMaccy(result)
      if pasteAfter {
        Clipboard.shared.paste()
      } else {
        // Make the result visible even when it deduplicates into an existing
        // top item — otherwise a repeated translation looks like a no-op.
        AppState.shared.navigator.select(item: AppState.shared.history.unpinnedItems.first)
      }
    } catch RequestError.modelsNotInstalled {
      Notifier.notify(body: NSLocalizedString("translation_models_missing", comment: ""), sound: nil)
      AppState.shared.openPreferences(pane: .translation)
    } catch RequestError.busy {
      // Another translation is in flight; ignore the extra click.
    } catch {
      Notifier.notify(body: NSLocalizedString("translation_failed", comment: ""), sound: nil)
      NSLog("Translation failed: \(error)")
    }
  }

  // MARK: - Generic translation primitive

  // Translates a string using the session provided by ContentView's
  // translationTask. Also used by AITextActions to bridge languages the
  // on-device language model does not support.
  func requestTranslation(_ text: String, source: Locale.Language?, target: Locale.Language) async throws -> String {
    // A request whose session never fired must not block translation forever.
    if let pending = pendingRequest, Date().timeIntervalSince(pending.startedAt) > 60 {
      pending.continuation.resume(throwing: CancellationError())
      pendingRequest = nil
    }
    guard pendingRequest == nil else { throw RequestError.busy }

    // The popup is a nonactivating panel, so the system model-download prompt
    // cannot be presented from here — sending an unprepared pair into
    // translationTask would hang forever. Models are downloaded from the
    // Translation settings pane instead.
    let availability = LanguageAvailability()
    let status: LanguageAvailability.Status
    if let source {
      status = await availability.status(from: source, to: target)
    } else {
      status = (try? await availability.status(for: text, to: target)) ?? .unsupported
    }
    guard case .installed = status else { throw RequestError.modelsNotInstalled }

    return try await withCheckedThrowingContinuation { continuation in
      pendingRequest = PendingRequest(text: text, startedAt: Date(), continuation: continuation)
      if configuration != nil {
        configuration?.source = source
        configuration?.target = target
        configuration?.invalidate() // re-fires translationTask even for an unchanged pair
      } else {
        configuration = TranslationSession.Configuration(source: source, target: target)
      }
    }
  }

  // Called only from ContentView's .translationTask closure.
  func run(in session: TranslationSession) async {
    // Guards against spurious re-invocations (view re-appearing with a stale configuration).
    guard let request = pendingRequest else { return }
    pendingRequest = nil

    do {
      let response = try await session.translate(request.text)
      request.continuation.resume(returning: response.targetText)
    } catch {
      request.continuation.resume(throwing: error)
    }
  }

  // Text in the native language goes native→foreign; anything else goes →native
  // (with the detected language as source when known).
  private func direction(for text: String) -> (Locale.Language?, Locale.Language) {
    let detected = Self.detectLanguage(of: text)

    let native = Defaults[.translationNativeLanguage]
    let foreign = Defaults[.translationForeignLanguage]

    if let code = detected?.languageCode?.identifier, code == native {
      return (Locale.Language(identifier: native), Locale.Language(identifier: foreign))
    }
    return (detected, Locale.Language(identifier: native))
  }
}
