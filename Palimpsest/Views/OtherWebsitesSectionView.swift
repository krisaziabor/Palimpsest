import SwiftUI

struct OtherWebsitesSectionView: View {
    let discoveredURLs: [DiscoveredURL]
    @Binding var isExpanded: Bool
    @EnvironmentObject private var collectionManager: CollectionManager

    @State private var urlForSave: DiscoveredURL?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            }, label: {
                HStack {
                    Text("Other Websites (\(discoveredURLs.count))")
                        .font(LectorFont.headline)
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .foregroundColor(.secondary)
                        .animation(.easeInOut(duration: 0.2), value: isExpanded)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            })
            .buttonStyle(PlainButtonStyle())

            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(discoveredURLs) { discoveredURL in
                        DiscoveredURLRow(
                            discoveredURL: discoveredURL,
                            onSaveTapped: { urlForSave = discoveredURL },
                            onLinkTapped: {
                                if let url = URL(string: discoveredURL.url) {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                        )
                    }
                }
                .padding(.leading, 16)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .sheet(item: $urlForSave) { discoveredURL in
            RecordingPanelView(
                sourceTitle: discoveredURL.url,
                sourceURL: discoveredURL.url,
                onSave: { item in
                    collectionManager.add(item)
                    urlForSave = nil
                },
                onCancel: { urlForSave = nil }
            )
        }
    }
}

struct DiscoveredURLRow: View {
    let discoveredURL: DiscoveredURL
    let onSaveTapped: () -> Void
    let onLinkTapped: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(discoveredURL.url)
                    .font(LectorFont.body)
                    .foregroundColor(.primary)
                    .lineLimit(4)
            }
            Spacer()
            HStack(spacing: 8) {
                if discoveredURL.isTopResult {
                    Image(systemName: "star.fill")
                        .font(LectorFont.caption)
                        .foregroundColor(.yellow)
                }
                Text("\(discoveredURL.count)")
                    .font(LectorFont.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(4)
                Button(action: onLinkTapped) {
                    Image(systemName: "arrow.up.right")
                        .font(LectorFont.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
                .onHover { isHovered in
                    if isHovered {
                        NSCursor.pointingHand.set()
                    } else {
                        NSCursor.arrow.set()
                    }
                }
                Button(action: onSaveTapped) {
                    Image(systemName: "bookmark")
                        .font(LectorFont.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.vertical, 4)
    }
}
