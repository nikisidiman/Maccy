import SwiftUI
import Defaults
import FoundationModels
import Settings

private struct PromptEditor: View {
  @Binding var prompt: String
  let defaultValue: String
  let reset: () -> Void

  var body: some View {
    HStack(alignment: .top) {
      TextField("", text: $prompt, axis: .vertical)
        .lineLimit(2...8)
        .frame(width: 280)

      Button {
        reset()
      } label: {
        Image(systemName: "arrow.uturn.backward.circle.fill")
          .imageScale(.large)
      }
      .buttonStyle(.borderless)
      .help(Text("ResetPrompt", tableName: "IntelligenceSettings"))
      .disabled(prompt == defaultValue)
    }
  }
}

struct IntelligenceSettingsPane: View {
  @Default(.aiFixTyposPrompt) private var fixTyposPrompt
  @Default(.aiRephrasePrompt) private var rephrasePrompt
  @Default(.aiSummarizePrompt) private var summarizePrompt
  @Default(.aiCustomPrompt) private var customPrompt

  @State private var isModelAvailable = false

  var body: some View {
    Settings.Container(contentWidth: 500) {
      Settings.Section(
        bottomDivider: true,
        label: { Text("Status", tableName: "IntelligenceSettings") }
      ) {
        if isModelAvailable {
          Text("StatusAvailable", tableName: "IntelligenceSettings")
            .foregroundStyle(.green)
        } else {
          Text("StatusUnavailable", tableName: "IntelligenceSettings")
            .foregroundStyle(.orange)
            .fixedSize(horizontal: false, vertical: true)
          Button {
            if let url = URL(string: "x-apple.systempreferences:com.apple.Intelligence-Settings.extension") {
              NSWorkspace.shared.open(url)
            }
          } label: {
            Text("OpenSystemSettings", tableName: "IntelligenceSettings")
          }
        }
      }

      Settings.Section(label: { Text("FixTyposPrompt", tableName: "IntelligenceSettings") }) {
        PromptEditor(
          prompt: $fixTyposPrompt,
          defaultValue: _fixTyposPrompt.defaultValue,
          reset: { _fixTyposPrompt.reset() }
        )
      }

      Settings.Section(label: { Text("RephrasePrompt", tableName: "IntelligenceSettings") }) {
        PromptEditor(
          prompt: $rephrasePrompt,
          defaultValue: _rephrasePrompt.defaultValue,
          reset: { _rephrasePrompt.reset() }
        )
      }

      Settings.Section(label: { Text("SummarizePrompt", tableName: "IntelligenceSettings") }) {
        PromptEditor(
          prompt: $summarizePrompt,
          defaultValue: _summarizePrompt.defaultValue,
          reset: { _summarizePrompt.reset() }
        )
      }

      Settings.Section(label: { Text("CustomPrompt", tableName: "IntelligenceSettings") }) {
        TextField("", text: $customPrompt, axis: .vertical)
          .lineLimit(2...8)
          .frame(width: 280)

        Text("PromptsDescription", tableName: "IntelligenceSettings")
          .controlSize(.small)
          .foregroundStyle(.gray)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .onAppear {
      if case .available = SystemLanguageModel.default.availability {
        isModelAvailable = true
      } else {
        isModelAvailable = false
      }
    }
  }
}

#Preview {
  IntelligenceSettingsPane()
    .environment(\.locale, .init(identifier: "en"))
}
