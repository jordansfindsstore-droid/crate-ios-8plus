// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import UniformTypeIdentifiers

/// "Set Up JIT": the steps Built-in StikJIT needs, each with its status and
/// the action that gets it, then Turn On JIT.
struct JITSetupView: View {
    @EnvironmentObject private var jit: JITSession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var setup = JITSetup()
    @State private var importing = false
    @State private var confirmingForget = false

    var body: some View {
        NavigationStack {
            Form {
                pairingSection
                vpnSection
                diskImageSection
                Section {
                    Button {
                        dismiss()
                        Task { await jit.turnOn(.builtInStikJIT) }
                    } label: {
                        Label("Turn On JIT", systemImage: "bolt.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .controlSize(.large)
                    // One helper at a time: not while Prepare Now runs.
                    .disabled(!setup.isReady || setup.preparation == .working)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
            }
            .navigationTitle("Set Up JIT")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.propertyList, .data, .item]) {
                setup.importFile($0)
            }
            .task { await setup.checkTunnel() }
            .onChange(of: scenePhase) { phase in
                AppLog.write("jit: setup: crate is \(scenePhase == .active ? "in front" : scenePhase == .background ? "in the background" : "inactive")")
                // Back from LocalDevVPN or Settings.
                if phase == .active {
                    setup.returnedToFront()
                    Task { await setup.checkTunnel() }
                }
            }
            .onDisappear {
                setup.cancelPairing()
                jit.pairingChanged()
            }
        }
    }

    // MARK: - 1. Pairing

    private var pairingSection: some View {
        Section {
            StepStatus(title: "This iPhone", done: setup.hasPairingFile,
                       status: setup.hasPairingFile ? "Paired" : "Not Paired")
            switch setup.pairing {
            case .idle:
                if setup.canPairOnDevice {
                    Button(setup.hasPairingFile ? "Pair Again" : "Pair This iPhone", systemImage: "link") {
                        setup.startPairing()
                    }
                }
            case .starting:
                HStack {
                    Text("Getting ready to pair…")
                    Spacer()
                    ProgressView()
                }
            case .showing(let code, _):
                pairingInProgress(code: code)
            case .failed(let message):
                Text(message)
                    .foregroundStyle(.orange)
                Button("Try Again", systemImage: "arrow.clockwise") { setup.startPairing() }
            }
            Button("Use a Pairing File Instead", systemImage: "doc.badge.plus") { importing = true }
            if setup.hasPairingFile && setup.pairing == .idle {
                Button("Forget Pairing", systemImage: "link.badge.minus", role: .destructive) {
                    confirmingForget = true
                }
                .confirmationDialog("Forget this iPhone's pairing?", isPresented: $confirmingForget,
                                    titleVisibility: .visible) {
                    Button("Forget Pairing", role: .destructive) { setup.forgetPairing() }
                } message: {
                    Text("Built-in StikJIT can't turn JIT on until crate is paired again. StikDebug doesn't use this pairing.")
                }
            }
            if let importError = setup.importError {
                Text(importError)
                    .foregroundStyle(.orange)
            }
        } header: {
            Text("1. Pair")
        } footer: {
            Text(pairingFooter)
        }
    }

    /// The code card, which is also what floats over Settings, kept small,
    /// with Open Settings right under it.
    @ViewBuilder
    private func pairingInProgress(code: String) -> some View {
        PairingCodeView(pictureInPicture: setup.pictureInPicture)
            .aspectRatio(16 / 9, contentMode: .fit)
            .frame(maxHeight: 110)
            .frame(maxWidth: .infinity)
            .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
            .accessibilityElement()
            .accessibilityLabel("Pairing code \(code.map(String.init).joined(separator: " "))")
        Button {
            setup.openSettings()
        } label: {
            Label("Open Settings", systemImage: "gear")
                .font(.headline)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
        Button("Cancel Pairing", role: .cancel) { setup.cancelPairing() }
    }

    private var pairingFooter: String {
        switch setup.pairing {
        case .showing(let code, true):
            return "Settings is asking for the code. Type \(PairingCodePictureInPicture.spaced(code)) there, then come back."
        case .showing:
            return "In Settings, go to Privacy & Security, then Developer Mode, tap Pair with crate, and type this code. It stays on screen over Settings."
        default:
            return setup.canPairOnDevice
                ? "crate pairs with this iPhone itself, so no computer is needed. A pairing file from StikDebug, idevice_pair or iloader works too."
                : "Pairing on the iPhone needs iOS 27. Make a pairing file on a computer with idevice_pair or iloader, then pick it here."
        }
    }

    // MARK: - 2. LocalDevVPN

    private var vpnSection: some View {
        Section {
            StepStatus(title: "LocalDevVPN", done: setup.tunnel == .up, status: tunnelStatus)
            if setup.tunnel != .up {
                Button(LocalDevVPN.isInstalled ? "Connect LocalDevVPN" : "Get LocalDevVPN",
                       systemImage: "network.badge.shield.half.filled") {
                    setup.connectVPN()
                }
            }
            Button("Check Again", systemImage: "arrow.clockwise") {
                Task { await setup.checkTunnel() }
            }
            .disabled(setup.tunnel == nil)
        } header: {
            Text("2. Connect")
        } footer: {
            Text(setup.tunnel == .localNetworkDenied
                 ? "crate needs Local Network access to reach LocalDevVPN. Turn it on in Settings > Privacy & Security > Local Network."
                 : "LocalDevVPN, free on the App Store, lets crate reach this iPhone's own debugging service. Without Wi-Fi, turn on cellular data, connect it, then turn on Airplane Mode.")
        }
    }

    private var tunnelStatus: String {
        switch setup.tunnel {
        case nil: "Checking…"
        case .up: "Connected"
        case .localNetworkDenied: "Local Network Off"
        case .down: "Not Connected"
        }
    }

    // MARK: - 3. Disk image

    private var diskImageSection: some View {
        Section {
            switch setup.preparation {
            case .idle:
                StepStatus(title: "Developer Disk Image", done: false, status: "Not Checked")
                Button("Prepare Now", systemImage: "externaldrive.badge.checkmark") { setup.prepare() }
                    // One helper at a time: not while JIT is being turned on,
                    // at launch say, which mounts the disk image itself.
                    .disabled(!setup.isReady || jit.isTurningOn)
            case .working:
                HStack {
                    Text("Developer Disk Image")
                    Spacer()
                    ProgressView()
                }
            case .ready:
                StepStatus(title: "Developer Disk Image", done: true, status: "Ready")
            case .failed(let message):
                StepStatus(title: "Developer Disk Image", done: false, status: "Didn't Work")
                Text(message)
                    .foregroundStyle(.orange)
                Button("Try Again", systemImage: "arrow.clockwise") { setup.prepare() }
                    .disabled(!setup.isReady || jit.isTurningOn)
            }
        } header: {
            Text("3. Prepare")
        } footer: {
            Text("Apple's developer disk image, which turning JIT on mounts by itself. It downloads once and stays mounted until the iPhone restarts. If it keeps failing, restart the iPhone.")
        }
    }
}

/// A step's name and where it stands, with a check once it's done.
private struct StepStatus: View {
    let title: String
    let done: Bool
    let status: String

    var body: some View {
        LabeledContent {
            HStack(spacing: 6) {
                if done {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
                Text(status)
            }
        } label: {
            Text(title)
        }
    }
}
