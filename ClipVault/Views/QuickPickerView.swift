//
//  QuickPickerView.swift
//  ClipVault
//
//  Two-pane hold-and-cycle picker shown by QuickPickerManager next to the
//  cursor while ⌘⇧ is held. Left pane is the scrolling list of recent items
//  with a single highlighted selection; right pane previews the selected
//  item's full content plus its metadata.
//

import SwiftUI
import AppKit

final class QuickPickerViewModel: ObservableObject {
    @Published var items: [ClipItem]
    @Published var selectedIndex: Int = 0

    var onRowClicked: ((Int) -> Void)?

    init(items: [ClipItem]) {
        self.items = items
    }

    func moveSelection(by delta: Int) {
        guard !items.isEmpty else { return }
        let count = items.count
        selectedIndex = (selectedIndex + delta + count) % count
    }
}

struct QuickPickerView: View {
    @ObservedObject var viewModel: QuickPickerViewModel

    static let panelSize = CGSize(width: 720, height: 400)

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                listPane
                    .frame(width: 300)

                Divider()

                previewPane
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Divider()

            Text("↑↓ or tap 7 to move · release to paste · esc cancel")
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .frame(width: Self.panelSize.width, height: Self.panelSize.height)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
        )
    }

    // MARK: - List Pane

    private var listPane: some View {
        Group {
            if viewModel.items.isEmpty {
                Text("No clipboard history")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(Array(viewModel.items.enumerated()), id: \.offset) { index, item in
                                row(for: item, at: index)
                                    .id(index)
                            }
                        }
                        .padding(8)
                    }
                    .onChange(of: viewModel.selectedIndex) { newIndex in
                        withAnimation(.easeOut(duration: 0.12)) {
                            proxy.scrollTo(newIndex, anchor: .center)
                        }
                    }
                }
            }
        }
    }

    private func row(for item: ClipItem, at index: Int) -> some View {
        let isSelected = index == viewModel.selectedIndex

        return HStack(spacing: 8) {
            Text("\(index + 1)")
                .font(.caption.monospacedDigit())
                .foregroundColor(isSelected ? .white : .secondary)
                .frame(width: 18, alignment: .trailing)

            appIcon(for: item)

            Text(item.getPreviewText(maxLength: 40))
                .lineLimit(1)
                .foregroundColor(isSelected ? .white : .primary)

            Spacer(minLength: 4)

            Text(item.getRelativeTimeString())
                .font(.caption2)
                .foregroundColor(isSelected ? Color.white.opacity(0.8) : .secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.onRowClicked?(index)
        }
    }

    // MARK: - Preview Pane

    @ViewBuilder
    private var previewPane: some View {
        if viewModel.items.indices.contains(viewModel.selectedIndex) {
            let item = viewModel.items[viewModel.selectedIndex]

            VStack(alignment: .leading, spacing: 0) {
                ScrollView {
                    Text(item.getDecryptedText() ?? "[Unable to decrypt]")
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                }

                Divider()

                metadata(for: item)
                    .padding(12)
            }
        } else {
            Text("Nothing to preview")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func metadata(for item: ClipItem) -> some View {
        let text = item.getDecryptedText() ?? ""
        let lines = text.isEmpty ? 0 : text.components(separatedBy: .newlines).count

        return VStack(alignment: .leading, spacing: 4) {
            metadataRow(label: "Source", value: appName(for: item))
            metadataRow(label: "Copied", value: absoluteDate(for: item))
            metadataRow(label: "Type", value: item.rtfData != nil ? "Rich text (RTF)" : "Plain text")
            metadataRow(label: "Size", value: "\(text.count) chars · \(lines) line\(lines == 1 ? "" : "s")")
            if item.isPinned {
                metadataRow(label: "Pinned", value: "Yes")
            }
        }
        .font(.caption)
    }

    private func metadataRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .foregroundColor(.secondary)
                .frame(width: 52, alignment: .leading)
            Text(value)
                .foregroundColor(.primary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    private func absoluteDate(for item: ClipItem) -> String {
        guard let dateAdded = item.dateAdded else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return "\(formatter.string(from: dateAdded)) (\(item.getRelativeTimeString()))"
    }

    private func appName(for item: ClipItem) -> String {
        guard let bundleID = item.appBundleID else { return "Unknown" }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return bundleID
        }
        return FileManager.default.displayName(atPath: url.path)
    }

    @ViewBuilder
    private func appIcon(for item: ClipItem) -> some View {
        if let bundleID = item.appBundleID,
           let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: appURL.path))
                .resizable()
                .frame(width: 16, height: 16)
        } else {
            Image(systemName: "questionmark.app")
                .frame(width: 16, height: 16)
                .foregroundColor(.secondary)
        }
    }
}
