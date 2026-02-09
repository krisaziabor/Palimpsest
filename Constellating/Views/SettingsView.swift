//
//  SettingsView.swift
//  Constellating
//
//  Settings for Are.na API token, drive name, and rate limit.
//

import AppKit
import SwiftUI

struct SettingsView: View {
    @State private var tokenInput: String = ""
    @State private var saveMessage: String?
    @State private var saveError: String?
    @State private var driveSelectionMessage: String?

    let tokenStorage: TokenStorage
    let driveSettings: DriveSettingsStorage

    var body: some View {
        Form {
            Section {
                SecureField("Personal Access Token", text: $tokenInput)
                    .textContentType(.password)
                Text("Get a token from are.na/settings/oauth to use Premium rate limits (300/min).")
                    .font(LectorFont.caption)
                    .foregroundColor(.secondary)
                HStack {
                    Button("Save") {
                        saveToken()
                    }
                    .disabled(tokenInput.isEmpty)
                    Button("Clear") {
                        clearToken()
                    }
                }
                if let msg = saveMessage {
                    Text(msg)
                        .font(LectorFont.caption)
                        .foregroundColor(.green)
                }
                if let err = saveError {
                    Text(err)
                        .font(LectorFont.caption)
                        .foregroundColor(.red)
                }
            } header: {
                Text("Are.na API")
            }

            Section {
                if let driveName = driveSettings.driveName {
                    HStack {
                        Text("Selected drive:")
                        Spacer()
                        Text(driveName)
                            .foregroundColor(.secondary)
                    }
                }

                Button("Select Drive Folder") {
                    selectDriveFolder()
                }

                if let msg = driveSelectionMessage {
                    Text(msg)
                        .font(LectorFont.caption)
                        .foregroundColor(.green)
                }

                Text(
                    "Select the root folder of your external drive. "
                        + "The app will create a 'Palimpsest' folder automatically if needed."
                )
                .font(LectorFont.caption)
                .foregroundColor(.secondary)
            } header: {
                Text("Transfer")
            } footer: {
                Text(
                    "Transfer your saved items to the configured drive each week."
                )
            }
        }
        .navigationTitle("Settings")
        .onAppear {
            if let existing = tokenStorage.getToken() {
                tokenInput = existing
            }
        }
    }

    private func saveToken() {
        saveMessage = nil
        saveError = nil
        do {
            try tokenStorage.setToken(tokenInput)
            saveMessage = "Token saved."
        } catch {
            saveError = "Failed to save: \(error.localizedDescription)"
        }
    }

    private func clearToken() {
        saveMessage = nil
        saveError = nil
        do {
            try tokenStorage.clearToken()
            tokenInput = ""
            saveMessage = "Token cleared."
        } catch {
            saveError = "Failed to clear: \(error.localizedDescription)"
        }
    }

    private func selectDriveFolder() {
        driveSelectionMessage = nil

        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select your external drive folder"
        panel.prompt = "Select"

        // Try to start at /Volumes
        panel.directoryURL = URL(fileURLWithPath: "/Volumes")

        panel.begin { response in
            guard response == .OK, let url = panel.url else {
                driveSelectionMessage = "No folder selected."
                return
            }

            do {
                // Save the drive with bookmark
                try driveSettings.saveDrive(url: url)

                if let driveName = driveSettings.driveName {
                    driveSelectionMessage = "Drive '\(driveName)' configured successfully. You can now transfer items."
                } else {
                    driveSelectionMessage = "Drive configured successfully."
                }
            } catch {
                print("Error saving drive: \(error)")
                driveSelectionMessage = "Failed to save drive: \(error.localizedDescription)"
            }
        }
    }
}
