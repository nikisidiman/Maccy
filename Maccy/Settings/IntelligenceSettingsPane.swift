import SwiftUI
import Defaults
import FoundationModels
import Settings

struct IntelligenceSettingsPane: View {
  @Default(.aiCustomPrompt) private var customPrompt

  @State private var isModelAvailable = false

  var body: some View {
    Settings.Container(contentWidth: 450) {
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

      Settings.Section(label: { Text("CustomPrompt", tableName: "IntelligenceSettings") }) {
        TextField("", text: $customPrompt, axis: .vertical)
          .lineLimit(3...6)
          .frame(width: 300)

        Text("CustomPromptDescription", tableName: "IntelligenceSettings")
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
