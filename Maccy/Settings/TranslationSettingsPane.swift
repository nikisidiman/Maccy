import SwiftUI
import Defaults
import Settings
import Translation

struct TranslationSettingsPane: View {
  private enum DownloadState {
    case idle
    case running
    case done
    case failed
  }

  private static let languageCodes = [
    "en", "ru", "de", "fr", "es", "it", "pt", "nl", "pl", "uk",
    "tr", "ar", "hi", "id", "ja", "ko", "th", "vi", "zh"
  ]

  @Default(.translationNativeLanguage) private var nativeLanguage
  @Default(.translationForeignLanguage) private var foreignLanguage

  @State private var downloadConfiguration: TranslationSession.Configuration?
  @State private var downloadState: DownloadState = .idle

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

      Settings.Section(
        bottomDivider: true,
        label: { Text("ForeignLanguage", tableName: "TranslationSettings") }
      ) {
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

      Settings.Section(label: { Text("LanguageModels", tableName: "TranslationSettings") }) {
        HStack {
          Button {
            downloadState = .running
            let source = Locale.Language(identifier: nativeLanguage)
            let target = Locale.Language(identifier: foreignLanguage)
            if downloadConfiguration != nil {
              downloadConfiguration?.source = source
              downloadConfiguration?.target = target
              downloadConfiguration?.invalidate()
            } else {
              downloadConfiguration = TranslationSession.Configuration(source: source, target: target)
            }
          } label: {
            Text("DownloadLanguages", tableName: "TranslationSettings")
          }
          .disabled(downloadState == .running)

          if downloadState == .running {
            ProgressView()
              .controlSize(.small)
          }
        }

        switch downloadState {
        case .done:
          Text("DownloadDone", tableName: "TranslationSettings")
            .controlSize(.small)
            .foregroundStyle(.green)
        case .failed:
          Text("DownloadFailed", tableName: "TranslationSettings")
            .controlSize(.small)
            .foregroundStyle(.red)
        default:
          Text("DownloadDescription", tableName: "TranslationSettings")
            .controlSize(.small)
            .foregroundStyle(.gray)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
    }
    // The settings window is a regular window, so the system model-download
    // prompt can be presented here (unlike the nonactivating popup panel).
    .translationTask(downloadConfiguration) { session in
      guard downloadState == .running else { return }
      do {
        try await session.prepareTranslation()
        downloadState = .done
      } catch {
        NSLog("Translation model download failed: \(error)")
        downloadState = .failed
      }
    }
  }
}

#Preview {
  TranslationSettingsPane()
    .environment(\.locale, .init(identifier: "en"))
}
