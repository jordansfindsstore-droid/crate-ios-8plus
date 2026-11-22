# iOS 16 port: JIT verification and change inventory

## What the sources establish

The SideStore source checked at
[commit `4f3d18d`](https://github.com/SideStore/SideStore/commit/4f3d18d98c5fbee72c80f787ceb2e8e09ded60a6)
uses its `safeDebugApp` path when running below iOS 17 in
[`EnableJITOperation.swift`](https://github.com/SideStore/SideStore/blob/4f3d18d98c5fbee72c80f787ceb2e8e09ded60a6/SideStore/Core/Operations/StandaloneOperations/EnableJITOperation.swift).
[`MinimuxerWrapper.swift`](https://github.com/SideStore/SideStore/blob/4f3d18d98c5fbee72c80f787ceb2e8e09ded60a6/SideStore/Core/DeviceApi/MinimuxerWrapper.swift)
shows that `safeDebugApp` prepares SideStore's device connection and calls
its app-debug operation. SideStore's README documents its separate
LocalDevVPN/EM Proxy integration; neither SideStore nor LocalDevVPN is included
in this app.

In crate, [`JITSession.swift`](../Sources/Crate/JIT/JITSession.swift) reads the
process code-signing flags and requires `CS_DEBUGGED` before claiming the code
region. `needsAuthorization` is enabled only on iOS 26 and later.
[`CodeRegion.c`](../Sources/Crate/JIT/CodeRegion.c) executes `brk #0x69` only
when that flag is true, so the iOS 16 path does not execute the trap. The
debugger attachment is enough for the code-region implementation's iOS 16
path to map writable/executable aliases and test generated code.

This is static source verification, not a device test. It does not establish
that a particular SideStore or LocalDevVPN installation, Apple ID, or iPhone
will complete setup successfully.

## Physical-device status

No physical iPhone 8 Plus/iOS 16.7.16 SideStore installation, JIT session, VM
boot, or Windows 10/iTunes pairing test has been performed. The Actions build
checks the generated IPA's metadata and architecture; a successful CI build
does not substitute for those device tests. An unsigned IPA also does not
prove that Apple's signing service will grant the optional increased-memory
entitlements.

## Change inventory

| Area | Port changes |
|---|---|
| `Sources/Crate/JIT/` and `Sources/Crate/Model/JIT.swift` | Keep the engine code-region claim and status check; remove in-app StikJIT, StikDebug, pairing, VPN, and helper-extension integration. |
| `Sources/Crate/App/RootView.swift` and Home/Settings views | Recheck JIT when crate returns to the foreground; show SideStore instructions instead of in-app JIT setup controls. |
| `project.yml`, `Resources/Info.plist`, `.gitignore` | Remove the upstream development-team value and JIT-specific pairing metadata; ignore local pairing and signing credentials. |
| `.github/workflows/` and `Scripts/` | Stop building/fetching removed JIT dependencies; retain app signing as a separate user-owned step. |
| `README.md`, `INSTALL.md`, `docs/PROVENANCE.md`, `THIRD_PARTY_NOTICES.md` | Document the Windows/SideStore workflow, external tools and licenses, source verification, and the untested device path. |
