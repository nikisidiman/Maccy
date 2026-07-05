import Defaults
import Foundation
import FoundationModels

enum AITextAction: String, CaseIterable, Identifiable {
  case fixTypos
  case rephraseFormal
  case summarize
  case custom

  var id: String { rawValue }

  // Cases shown in the menu; the custom action appears only when a prompt is configured.
  static var enabledCases: [AITextAction] {
    allCases.filter { action in
      action != .custom || !Defaults[.aiCustomPrompt].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
  }

  var title: String {
    switch self {
    case .fixTypos:
      NSLocalizedString("ai_fix_typos", comment: "")
    case .rephraseFormal:
      NSLocalizedString("ai_rephrase_formal", comment: "")
    case .summarize:
      NSLocalizedString("ai_summarize", comment: "")
    case .custom:
      NSLocalizedString("ai_custom", comment: "")
    }
  }

  var instructions: String {
    switch self {
    case .fixTypos:
      """
      You are a proofreader. Fix spelling, grammar and punctuation mistakes in the user's text.
      Keep the original language, meaning, tone and formatting.
      Reply with the corrected text only, without any comments.
      """
    case .rephraseFormal:
      """
      Rewrite the user's text in a polite, professional business tone.
      Keep the original language and meaning.
      Reply with the rewritten text only, without any comments.
      """
    case .summarize:
      """
      Summarize the user's text in two or three sentences in the same language as the text.
      Reply with the summary only, without any comments.
      """
    case .custom:
      Defaults[.aiCustomPrompt] + "\n\nReply with the result only, without any comments."
    }
  }
}

@MainActor
enum AITextActions {
  static var isModelAvailable: Bool {
    if case .available = SystemLanguageModel.default.availability {
      return true
    }
    return false
  }

  static func perform(_ action: AITextAction, on decorator: HistoryItemDecorator) {
    guard !decorator.isAccessoryActionRunning else { return }

    guard isModelAvailable else {
      Notifier.notify(body: NSLocalizedString("ai_unavailable", comment: ""), sound: nil)
      AppState.shared.openPreferences(pane: .intelligence)
      return
    }

    let text = decorator.item.previewableText
    guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

    decorator.isAccessoryActionRunning = true
    Task {
      defer { decorator.isAccessoryActionRunning = false }
      do {
        let session = LanguageModelSession(instructions: action.instructions)
        let response = try await session.respond(to: text)
        Clipboard.shared.copyInMaccy(response.content)
        // Make the result visible even when it deduplicates into an existing top item.
        AppState.shared.navigator.select(item: AppState.shared.history.unpinnedItems.first)
      } catch let error as LanguageModelSession.GenerationError {
        switch error {
        case .exceededContextWindowSize:
          Notifier.notify(body: NSLocalizedString("ai_too_long", comment: ""), sound: nil)
        default:
          Notifier.notify(body: NSLocalizedString("ai_failed", comment: ""), sound: nil)
        }
        NSLog("AI action failed: \(error)")
      } catch {
        Notifier.notify(body: NSLocalizedString("ai_failed", comment: ""), sound: nil)
        NSLog("AI action failed: \(error)")
      }
    }
  }
}
