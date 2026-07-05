import Defaults
import SwiftUI

struct HistoryItemView: View {
  @Bindable var item: HistoryItemDecorator
  var previous: HistoryItemDecorator?
  var next: HistoryItemDecorator?
  var index: Int

  private var visualIndex: Int? {
    if appState.navigator.isMultiSelectInProgress && item.selectionIndex >= 0 {
      return item.selectionIndex
    }
    return nil
  }

  private var selectionAppearance: SelectionAppearance {
    let previousSelected = previous?.isSelected ?? false
    let nextSelected = next?.isSelected ?? false
    switch (previousSelected, nextSelected) {
    case (true, false):
      return .topConnection
    case (false, true):
      return .bottomConnection
    case (true, true):
      return .topBottomConnection
    default:
      return .none
    }
  }

  @Default(.showHexColorSwatch) private var showHexColorSwatch
  @Environment(AppState.self) private var appState
  @Environment(TranslationCoordinator.self) private var translationCoordinator

  private var colorSwatchImage: NSImage? {
    guard showHexColorSwatch else { return nil }
    return ColorImage.from(item.title)
  }

  private var isTranslatableText: Bool {
    !item.hasImage
      && item.item.fileURLs.isEmpty
      && !item.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  private var accessorySymbol: String? {
    if item.hasImage { return "text.viewfinder" }
    if isTranslatableText { return "translate" }
    return nil
  }

  var body: some View {
    ListItemView(
      id: item.id,
      selectionId: item.id,
      appIcon: item.applicationImage,
      image: item.thumbnailImage,
      accessoryImage: item.thumbnailImage != nil ? nil : colorSwatchImage,
      attributedTitle: item.attributedTitle,
      shortcuts: item.shortcuts,
      isSelected: item.isSelected,
      selectionIndex: visualIndex,
      selectionAppearance: selectionAppearance,
      accessorySymbol: accessorySymbol,
      accessoryBusy: item.isAccessoryActionRunning,
      accessoryHelp: item.hasImage ? "ocr_tooltip" : "translate_tooltip",
      accessoryAction: accessorySymbol == nil ? nil : { performAccessoryAction() }
    ) {
      Text(verbatim: item.title)
    }
    .onAppear {
      item.ensureThumbnailImage()
    }
    .onTapGesture {
      if NSEvent.modifierFlags.contains(.command) && appState.multiSelectionEnabled {
        appState.navigator.addToSelection(item: item)
      } else {
        Task {
          appState.history.select(item)
        }
      }
    }
  }

  private func performAccessoryAction() {
    if item.hasImage {
      performOCR()
    } else {
      translationCoordinator.translate(item) // sets isAccessoryActionRunning itself
    }
  }

  private func performOCR() {
    guard !item.isAccessoryActionRunning, let image = item.item.image else { return }
    item.isAccessoryActionRunning = true
    Task {
      defer { item.isAccessoryActionRunning = false }
      do {
        let text = try await TextRecognizer.recognizeText(in: image)
        guard !text.isEmpty else {
          Notifier.notify(body: NSLocalizedString("ocr_no_text", comment: ""), sound: nil)
          return
        }
        Clipboard.shared.copyInMaccy(text)
        // Make the result visible even when it deduplicates into an existing top item.
        appState.navigator.select(item: appState.history.unpinnedItems.first)
      } catch {
        Notifier.notify(body: NSLocalizedString("ocr_failed", comment: ""), sound: nil)
        NSLog("OCR failed: \(error)")
      }
    }
  }
}
