# Installing crate on iOS 16

This iPhone 8 Plus port targets iOS 16.0 and produces an unsigned IPA. Install
it with SideStore; SideStore signs the app with your Apple ID and enables JIT.
No paid developer account is required. A free Apple ID's development
provisioning expires after seven days, so refresh the app with SideStore before
it expires.

## Windows 10 install and JIT

1. Install Apple's [iTunes for Windows](https://www.apple.com/itunes/) and
   [iloader](https://github.com/nab138/iloader/releases). The iloader project
   documents iTunes as its Windows USB device service and lists SideStore
   installation as a supported action. Only download iloader from its
   [official site](https://iloader.app) or
   [GitHub releases](https://github.com/nab138/iloader/releases).
2. Connect the iPhone by USB, unlock it, and trust the computer if prompted.
   In iloader, choose its SideStore install action and follow
   [SideStore's setup](https://docs.sidestore.io/), including any pairing or
   Apple ID steps it requests.
3. SideStore documents LocalDevVPN as part of its remote-debug integration.
   Install LocalDevVPN separately from its official App Store distribution and
   follow SideStore's setup instructions. Use it only as a personal-use
   external app: this project does not bundle, modify, or redistribute it.
4. Download the `crate-8plus.ipa` artifact from the repository's **iOS 16 IPA**
   Actions run. In SideStore, install that IPA and let SideStore finish signing
   and installing it. The unsigned IPA itself is not a ready-to-install signed
   app.
5. In SideStore, use **Enable JIT** for crate. Return to crate; it checks the
   debugger attachment again when it comes to the foreground. If the VM screen
   still says JIT is off, use **Check JIT Status**.

SideStore is AGPL-3.0 and iloader is MIT; both are separate tools, not app
dependencies and not included in the IPA. iTunes, Apple's signing service,
macOS, and Xcode are also external Apple requirements and are not bundled or
redistributed here. See [docs/PROVENANCE.md](docs/PROVENANCE.md).

## Build artifact

The `ipa` GitHub Actions workflow builds `crate-8plus.ipa` on a hosted macOS
runner with Xcode and XcodeGen, with code signing disabled. It checks the
version, minimum iOS version, and arm64 architecture. The artifact is
unsigned; it has no provisioning profile or device-tested signature.

The iPhone 8 Plus and iOS 16.7.16 have not been physically tested with this
port. See [docs/IOS16_PORT.md](docs/IOS16_PORT.md) for what is verified from
source and what still needs a device test.
