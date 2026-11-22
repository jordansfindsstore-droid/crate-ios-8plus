# Installing crate on iOS 16

This iPhone 8 Plus port targets iOS 16.0 and is built as an unsigned IPA.
Install and sign it from Windows with [Sideloadly](https://sideloadly.io/).
The app's JIT helper is not included: StikJIT and StikDebug require iOS 17.4
or later. Sideloadly documents JIT support through iOS 16.

## Install and enable JIT from Windows

1. Install Sideloadly for Windows and connect the iPhone by USB. Unlock the
   phone, tap **Trust** if prompted, and enable Developer Mode at
   **Settings > Privacy & Security > Developer Mode**.
2. Drag `crate-8plus.ipa` into Sideloadly, select the iPhone, enter your Apple
   ID, and start sideloading. If iOS asks, trust the developer profile at
   **Settings > General > VPN & Device Management**. A free Apple ID signature
   expires after seven days and must be refreshed.
3. Keep the iPhone connected. From Sideloadly's tray/daemon menu, choose its
   **Enable JIT** action and select crate. Sideloadly says this opens the app
   and enables JIT. Enable JIT again after crate exits or the phone reboots;
   JIT does not persist across launches.

The app uses conservative defaults for the iPhone 8 Plus: a 2 GB VM memory
limit, at most two guest CPUs, and 2D graphics. iOS may still terminate a VM
under memory pressure. A physical iPhone 8 Plus/iOS 16.7.16 installation and
JIT session have not yet been tested.

This unsigned build does not carry a provisioning profile or a device-tested
signature. Sideloadly signs it for your Apple ID during installation; the
available memory entitlements depend on your signing setup and may not be
granted. Start with a 1–2 GB VM either way.

## Build artifact

The private repository's **iOS 16 IPA** GitHub Actions workflow builds
`crate-8plus.ipa` on `macos-latest` with XcodeGen and Xcode, with code signing
disabled. The artifact is not a ready-to-install signed app. The workflow
checks the package's app metadata, minimum iOS version, and arm64 architecture.
