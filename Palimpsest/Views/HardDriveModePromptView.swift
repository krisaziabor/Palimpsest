//
//  HardDriveModePromptView.swift
//  Palimpsest
//
//  Modal prompt when an archive drive is detected.
//

import SwiftUI

struct HardDriveModePromptView: View {
    @EnvironmentObject private var hardDriveModeManager: HardDriveModeManager

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "externaldrive.fill")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)

            VStack(spacing: 8) {
                Text("Archive Drive Detected")
                    .font(LectorFont.title)

                if let driveName = hardDriveModeManager.connectedDriveName {
                    Text(driveName)
                        .font(LectorFont.headline)
                        .foregroundColor(.secondary)
                }
            }

            Text(
                "Enter Hard Drive Mode to browse your archived sources with full detail—titles, URLs, "
                    + "screenshots, everything you transferred."
            )
            .font(LectorFont.body)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("Choosing to look back means no new searches until tomorrow.")
                    .font(LectorFont.subheadline)
                    .foregroundColor(.orange)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(8)

            HStack(spacing: 16) {
                Button("Not Now") {
                    hardDriveModeManager.dismissPrompt()
                }
                .keyboardShortcut(.cancelAction)

                Button("Enter Hard Drive Mode") {
                    hardDriveModeManager.enterHardDriveMode()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(32)
        .frame(width: 420)
    }
}
