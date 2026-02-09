import SwiftUI

struct ChannelsSectionView: View {
    let channels: [ArenaChannel]
    @Binding var isExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            }, label: {
                HStack {
                    Text("Channels (\(channels.count))")
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
                    ForEach(Array(channels.enumerated()), id: \.offset) { _, channel in
                        ChannelRow(channel: channel)
                    }
                }
                .padding(.leading, 16)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

struct ChannelRow: View {
    let channel: ArenaChannel

    var body: some View {
        Button(action: {
            if let url = URL(string: "https://are.na/\(channel.slug)") {
                NSWorkspace.shared.open(url)
            }
        }, label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(channel.title ?? "Untitled Channel")
                        .font(LectorFont.body)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    HStack {
                        if let username = channel.username {
                            Text("by \(username)")
                                .font(LectorFont.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if let blockCount = channel.blockCount {
                            Text("\(blockCount) blocks")
                                .font(LectorFont.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(LectorFont.caption)
                    .foregroundColor(.secondary)
            }
        })
        .buttonStyle(PlainButtonStyle())
        .padding(.vertical, 4)
        .onHover { isHovered in
            if isHovered {
                NSCursor.pointingHand.set()
            } else {
                NSCursor.arrow.set()
            }
        }
    }
}
