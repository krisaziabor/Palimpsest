import SwiftUI

struct BlocksSectionView: View {
    let classifiedBlocks: [ClassifiedBlock]
    @Binding var isExpanded: Bool
    @EnvironmentObject private var collectionManager: CollectionManager

    @State private var blockForSave: ClassifiedBlock?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            }, label: {
                HStack {
                    Text("Blocks (\(classifiedBlocks.count))")
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
                    ForEach(Array(classifiedBlocks.enumerated()), id: \.offset) { _, classifiedBlock in
                        BlockRow(
                            classifiedBlock: classifiedBlock,
                            onSaveTapped: {
                                blockForSave = classifiedBlock
                            }
                        )
                    }
                }
                .padding(.leading, 16)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .sheet(item: $blockForSave) { block in
            RecordingPanelView(
                sourceTitle: block.block.title ?? "Untitled",
                sourceURL: block.block.source?.url ?? "",
                onSave: { item in
                    collectionManager.add(item)
                    blockForSave = nil
                },
                onCancel: {
                    blockForSave = nil
                }
            )
        }
    }
}

struct BlockRow: View {
    let classifiedBlock: ClassifiedBlock
    let onSaveTapped: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(classifiedBlock.block.title ?? "Untitled")
                        .font(LectorFont.body)
                        .lineLimit(2)
                    Spacer()
                    Text(classifiedBlock.isExact ? "Exact" : "Inexact")
                        .font(LectorFont.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(classifiedBlock.isExact ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                        .foregroundColor(classifiedBlock.isExact ? .green : .orange)
                        .cornerRadius(4)
                }
                if let sourceURL = classifiedBlock.block.source?.url {
                    Text(sourceURL)
                        .font(LectorFont.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(4)
                }
            }
            Button(action: onSaveTapped) {
                Image(systemName: "bookmark")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 4)
    }
}
