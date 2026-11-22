// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import UIKit

/// Turning JIT on: getting a debugger to attach to crate while it runs.
extension JITSession {
    /// Asks `method` to attach, waits for the debugger to arrive, then claims
    /// the code region with it. Leaves `enablerError` set if it didn't work.
    /// `interactive` is false for the attempt crate makes by itself at launch,
    /// which doesn't open the setup sheet unasked.
    func turnOn(_ method: JITMethod, interactive: Bool = true, waitForVPN: Duration? = nil) async {
        guard !isTurningOn, !isOn else { return }
        enablerError = nil
        waitingForVPN = false
        isTurningOn = true
        defer { isTurningOn = false }
        AppLog.write("jit: turning on with \(method.rawValue)")

        let asked: Bool
        switch method {
        case .stikDebug:
            asked = await askStikDebug()
        case .builtInStikJIT:
            if #unavailable(iOS 17.4) {
                fail("Built-in StikJIT requires iOS 17.4 or later. Use StikDebug on iOS 16.")
                return
            }
            asked = await askBuiltIn(interactive: interactive,
                                     waitForVPN: waitForVPN ?? (interactive ? .seconds(3) : .seconds(8)))
        }
        guard asked else { return }

        // The built-in helper may first download Apple's developer disk image.
        let timeout: Duration = method == .builtInStikJIT ? .seconds(300) : .seconds(120)
        guard await waitForDebugger(upTo: timeout) else {
            if let helperFailure {
                fail("Built-in StikJIT didn't work: \(helperFailure)" + Self.hint(for: helperFailure))
            } else {
                fail("\(method.title) didn't attach to crate. Check that it's set up, then try again.")
            }
            return
        }
        AppLog.write("jit: debugger attached")
        await check()
    }

    /// Opens StikDebug and asks it to attach to this process with legacy.js,
    /// the script that answers crate's `brk #0x69`. StikDebug asks the user to
    /// confirm, attaches, and brings crate back to the front.
    private func askStikDebug() async -> Bool {
        var url = URLComponents()
        url.scheme = "stikdebug"
        url.host = "enable-jit"
        url.queryItems = [
            URLQueryItem(name: "bundle-id", value: Bundle.main.bundleIdentifier),
            URLQueryItem(name: "pid", value: String(getpid())),
            URLQueryItem(name: "script-name", value: "legacy.js"),
        ]
        guard let target = url.url, await UIApplication.shared.open(target) else {
            fail("StikDebug isn't installed. Install it, or choose Built-in StikJIT.")
            return false
        }
        AppLog.write("jit: opened \(target.absoluteString)")
        return true
    }

    /// Starts crate's helper extension, which attaches with StikJIT through
    /// LocalDevVPN's tunnel and runs legacy.js. Its reply comes after it has
    /// detached, or early with what stopped it, which ends the wait.
    ///
    /// First the tunnel is checked, which also finds the port to give the
    /// helper. At launch it's given a few seconds to come up, since LocalDevVPN
    /// may still be connecting. If it isn't up, the helper isn't started (it
    /// would only time out), and crate tries again when it's next in front:
    /// back from LocalDevVPN, say (`cameToFront()`).
    private func askBuiltIn(interactive: Bool, waitForVPN: Duration) async -> Bool {
        if getenv("LC_HOME_PATH") != nil {
            fail("Built-in StikJIT can't run inside LiveContainer, which can't start crate's helper. Choose StikDebug.")
            return false
        }
        guard let pairing = PairingFile.read() else {
            AppLog.write("jit: built-in isn't set up (no pairing)")
            if interactive { showingSetup = true }
            return false
        }
        let checkStarted = cameToFrontCount
        var check = await LocalDevVPN.check(waitingUpTo: waitForVPN)
        // Back from LocalDevVPN while that was going on: its tunnel may only
        // just be up, so once more before giving up.
        if check.tunnel == .down, cameToFrontCount != checkStarted {
            check = await LocalDevVPN.check(waitingUpTo: .seconds(3))
        }
        switch check.tunnel {
        case .up:
            break
        case .down:
            waitingForVPN = true
            fail("LocalDevVPN isn't connected. Open LocalDevVPN and connect it: crate turns JIT on when you come back.")
            return false
        case .localNetworkDenied:
            // The helper may still get through; it says what stopped it if not.
            AppLog.write("jit: trying the helper anyway")
        }
        helperFailure = nil
        var request: [String: Any] = ["pid": Int(getpid()), "pairing": pairing]
        if let port = check.portForHelper { request["port"] = Int(port) }
        crate_helper_request(request) { reply, failure in
            let ok = reply?["ok"] as? Bool ?? false
            let summary = reply?["summary"] as? String ?? failure ?? "no reply"
            let lines = reply?["log"] as? [String] ?? []
            Task { @MainActor in
                for line in lines { AppLog.write("helper: \(line)") }
                AppLog.write("jit: helper replied: \(ok ? "" : "FAILED: ")\(summary)")
                if !ok { self.helperFailure = summary }
            }
        }
        AppLog.write("jit: started the built-in helper")
        return true
    }

    /// Polls for the debugger. crate may be in the background meanwhile; iOS
    /// suspends it there, and the polling picks up when it's back in front.
    private func waitForDebugger(upTo timeout: Duration) async -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now + timeout
        while clock.now < deadline {
            if Self.debuggerReady { return true }
            if helperFailure != nil { return false }
            try? await Task.sleep(for: .milliseconds(200))
            if Task.isCancelled { return false }
        }
        return Self.debuggerReady
    }

    private func fail(_ message: String) {
        AppLog.write("jit: turning on failed: \(message)")
        enablerError = message
    }

    /// What to do about the helper's failure, when its text says: StikJIT's own
    /// words stay first, since they're what a bug report needs.
    static func hint(for failure: String) -> String {
        let text = failure.lowercased()
        if ["timed out", "refused", "unreachable", "no route", "network is down"].contains(where: text.contains) {
            return " Check that LocalDevVPN is connected, then turn JIT on again."
        }
        if ["pairing", "reset by peer", "connection reset", "invalidhostid", "sessioninactive"].contains(where: text.contains) {
            return " The pairing may be out of date: pair again in Set Up JIT."
        }
        if text.contains("developer mode") {
            return " Turn on Developer Mode in Settings > Privacy & Security."
        }
        return ""
    }

    /// crate is in front again. If turning JIT on stopped for want of the
    /// tunnel, it tries again now: LocalDevVPN has just been connected, most
    /// likely. Not while Set Up JIT is open, which checks the tunnel itself.
    func cameToFront() {
        cameToFrontCount += 1
        guard waitingForVPN, !isOn, !isTurningOn, !showingSetup else { return }
        let method = JITMethod(rawValue: UserDefaults.standard.string(forKey: SettingsKey.jitMethod) ?? "") ?? .standard
        guard method == .builtInStikJIT else { return }
        AppLog.write("jit: back in front; trying again now LocalDevVPN may be connected")
        // As long as at launch: LocalDevVPN's tunnel can take several seconds
        // to answer after crate is back in front.
        Task { await turnOn(method, interactive: false, waitForVPN: .seconds(8)) }
    }
}
