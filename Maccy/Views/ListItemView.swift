import Defaults
import SwiftUI

enum SelectionAppearance {
  case none
  case topConnection
  case bottomConnection
  case topBottomConnection

  func rect(cornerRadius: CGFloat) -> some Shape {
    var cornerRadii = RectangleCornerRadii()
    switch self {
    case .none:
      cornerRadii.topLeading = cornerRadius
      cornerRadii.topTrailing = cornerRadius
      cornerRadii.bottomLeading = cornerRadius
      cornerRadii.bottomTrailing = cornerRadius
    case .topConnection:
      cornerRadii.bottomLeading = cornerRadius
      cornerRadii.bottomTrailing = cornerRadius
    case .bottomConnection:
      cornerRadii.topLeading = cornerRadius
      cornerRadii.topTrailing = cornerRadius
    case .topBottomConnection:
      break
    }
    return .rect(cornerRadii: cornerRadii)
  }
}

struct AccessoryMenuItem: Identifiable {
  let id = UUID()
  let title: String
  let action: () -> Void
}

struct ListItemView<Title: View, ID: Hashable>: View {
  var id: ID
  var selectionId: UUID
  var appIcon: ApplicationImage?
  var image: NSImage?
  var accessoryImage: NSImage?
  var attributedTitle: AttributedString?
  var shortcuts: [KeyShortcut]
  var isSelected: Bool
  var selectionIndex: Int?
  var help: LocalizedStringKey?
  var selectionAppearance: SelectionAppearance = .none
  var accessorySymbol: String?
  var accessoryBusy: Bool = false
  var accessoryHelp: LocalizedStringKey?
  var accessoryAction: (() -> Void)?
  var accessoryMenuSymbol: String?
  var accessoryMenuItems: [AccessoryMenuItem] = []
  @ViewBuilder var title: () -> Title

  @Default(.showApplicationIcons) private var showIcons
  @Environment(AppState.self) private var appState
  @Environment(ModifierFlags.self) private var modifierFlags

  var body: some View {
    HStack(spacing: 0) {
      if showIcons, let appIcon {
        VStack {
          Spacer(minLength: 0)
          AppImageView(appImage: appIcon, size: NSSize(width: 15, height: 15))
          Spacer(minLength: 0)
        }
        .padding(.leading, 4)
        .padding(.vertical, 5)
      }

      Spacer()
        .frame(width: showIcons ? 5 : 10)

      if let accessoryImage {
        Image(nsImage: accessoryImage)
          .accessibilityIdentifier("copy-history-item")
          .padding(.trailing, 5)
          .padding(.vertical, 5)
      }

      if let image {
        Image(nsImage: image)
          .accessibilityIdentifier("copy-history-item")
          .padding(.trailing, 5)
          .padding(.vertical, 5)
      } else {
        ListItemTitleView(attributedTitle: attributedTitle, title: title)
          .padding(.trailing, 5)
      }

      Spacer()

      HStack(spacing: 5) {
        if let index = selectionIndex {
          Text("\(index + 1)")
            .font(.caption)
            .frame(minWidth: 10, alignment: .center)
            .padding(3)
            .background(
              Color.secondary.opacity(isSelected ? 0.5 : 0.8),
              in: Capsule()
            )
            .foregroundStyle(Color.white)
        }

        if !shortcuts.isEmpty {
          ZStack(alignment: .trailing) {
            ForEach(shortcuts) { shortcut in
              let visible = shortcut.isVisible(shortcuts, modifierFlags.flags)
              KeyboardShortcutView(shortcut: shortcut)
                .opacity(visible ? 1 : 0)
                .frame(width: visible ? nil : 0)
            }
          }
        }

        if let accessorySymbol, let accessoryAction {
          // The button stays enabled while busy (the action guards instead):
          // clicks on a disabled Button fall through to the row's tap gesture
          // and would select the item and close the popup.
          Button {
            if !accessoryBusy {
              accessoryAction()
            }
          } label: {
            ZStack {
              Image(systemName: accessorySymbol)
                .opacity(accessoryBusy ? 0 : 1)
              if accessoryBusy {
                ProgressView()
                  .controlSize(.mini)
              }
            }
            .frame(width: 18, height: 18)
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          // macOS 26 does not hit-test views without a background (see the row
          // background workaround below).
          .background(Color.white.opacity(0.001))
          .help(accessoryHelp ?? "")
        }

        if let accessoryMenuSymbol, !accessoryMenuItems.isEmpty {
          Menu {
            ForEach(accessoryMenuItems) { entry in
              Button(entry.title, action: entry.action)
            }
          } label: {
            Image(systemName: accessoryMenuSymbol)
              .opacity(accessoryBusy ? 0.3 : 1)
              .frame(width: 18, height: 18)
              .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .menuIndicator(.hidden)
          .fixedSize()
          .background(Color.white.opacity(0.001))
        }
      }
      // Wide enough that the overlay scroll indicator doesn't cover the accessory icons.
      .padding(.trailing, 16)
    }
    .frame(minHeight: Popup.itemHeight)
    .id(id)
    .frame(maxWidth: .infinity, alignment: .leading)
    .foregroundStyle(isSelected ? Color.white : .primary)
    // macOS 26 broke hovering if no background is present.
    // The slight opcaity white background is a workaround
    .background(isSelected ? Color.accentColor.opacity(0.8) : .white.opacity(0.001))
    .clipShape(selectionAppearance.rect(cornerRadius: Popup.cornerRadius))
    .hoverSelectionId(selectionId)
    .help(help ?? "")
  }
}
