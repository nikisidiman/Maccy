import SwiftUI
import Defaults
import Settings

struct TranslationSettingsPane: View {
  private static let languageCodes = [
    "en", "ru", "de", "fr", "es", "it", "pt", "nl", "pl", "uk",
    "tr", "ar", "hi", "id", "ja", "ko", "th", "vi", "zh"
  ]

  @Default(.translationNativeLanguage) private var nativeLanguage
  @Default(.translationForeignLanguage) private var foreignLanguage

  private func languageName(_ code: String) -> String {
    Locale.current.localizedString(forLanguageCode: code) ?? code
  }

  var body: some View {
    Settings.Container(contentWidth: 450) {
      Settings.Section(
        bottomDivider: true,
        label: { Text("MyLanguage", tableName: "TranslationSettings") }
      ) {
        Picker("", selection: $nativeLanguage) {
          ForEach(Self.languageCodes, id: \.self) { code in
            Text(languageName(code)).tag(code)
          }
        }
        .labelsHidden()
        .frame(width: 160, alignment: .leading)
      }

      Settings.Section(label: { Text("ForeignLanguage", tableName: "TranslationSettings") }) {
        Picker("", selection: $foreignLanguage) {
          ForEach(Self.languageCodes, id: \.self) { code in
            Text(languageName(code)).tag(code)
          }
        }
        .labelsHidden()
        .frame(width: 160, alignment: .leading)

        Text("Description", tableName: "TranslationSettings")
          .controlSize(.small)
          .foregroundStyle(.gray)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }
}

#Preview {
  TranslationSettingsPane()
    .environment(\.locale, .init(identifier: "en"))
}
