# Installing crate

crate can't come from the App Store: it needs JIT, which iOS gives only to an
app a debugger has attached to, and only apps signed for development can be
attached to. So each [release](https://github.com/oneamendez/crate-ios/releases)
has an unsigned IPA, `crate-unsigned.ipa`, and you sign it with your own Apple
account on a Mac, then install it on your iPhone or iPad.

## iPhone 8 Plus on iOS 16 (Windows)

This port uses Sideloadly for both signing/installing and enabling JIT. Sideloadly
lists support for JIT through iOS 16; StikDebug requires iOS 17.4 or later.

1. Install [Sideloadly for Windows](https://sideloadly.io/) and connect the
   iPhone by USB. Unlock it and tap **Trust** when asked. Enable Developer Mode
   on the iPhone at **Settings > Privacy & Security > Developer Mode**.
2. Drag `crate-8plus.ipa` into Sideloadly, choose the iPhone, enter your Apple
   ID, and start sideloading. A free Apple ID signature expires after 7 days;
   Sideloadly can refresh it. Trust the developer profile in
   **Settings > General > VPN & Device Management** if iOS asks.
3. Keep the iPhone connected to Windows. From Sideloadly's tray/daemon menu,
   choose **Enable JIT**, then select crate. Sideloadly says this opens the app
   and enables JIT. Repeat after crate exits; JIT does not persist across
   launches.

Sideloading can succeed without the memory entitlements; iOS may then give
crate less memory. Use the 1–2 GB VM settings first. This path has not yet been
tested on an iPhone 8 Plus.

## The quick way: ask Claude Code

On a Mac with Xcode, with your iPhone connected by cable, start
[Claude Code](https://claude.com/claude-code) and paste:

> Install crate on my iPhone from https://github.com/oneamendez/crate-ios,
> following its INSTALL.md. Download the latest release's crate-unsigned.ipa
> and verify it with `gh attestation verify`. Sign it with my own Apple
> development certificate using the repository's Scripts/sign-ipa.sh, under a
> bundle ID of mine. If my account allows it, give the app ID the Increased
> Memory Limit and Extended Virtual Address Space capabilities; it's fine
> without them. Then install it on my iPhone and tell me how to turn on JIT.

It will ask you for what only you can do, such as signing in to your Apple
account in Xcode. The steps below are what it follows, if you'd rather do it
yourself.

## What you need

- A Mac with Xcode, signed in to your Apple account (Xcode > Settings >
  Accounts). A paid Apple Developer Program membership gives profiles that
  last a year; a free account's last 7 days, after which you sign again.
- An iPhone or iPad with Developer Mode on (Settings > Privacy & Security >
  Developer Mode), connected to the Mac and trusted.
- Optionally, the [GitHub CLI](https://cli.github.com) (`gh`), to check where
  the IPA came from.

## 1. Download the IPA

    curl -LO https://github.com/oneamendez/crate-ios/releases/latest/download/crate-unsigned.ipa
    gh attestation verify crate-unsigned.ipa --repo oneamendez/crate-ios

The second command checks that this repository's GitHub workflow built the
file. Each release's notes also list its SHA-256.

## 2. Make development profiles for your bundle ID

Pick a bundle ID under your name, such as `com.yourname.crate`. crate's JIT
helper lives inside the app as `com.yourname.crate.jithelper`. Both need a
development provisioning profile on the Mac. The easiest way to get them is to
let Xcode make them:

1. In Xcode, File > New > Project > iOS App. Set the Bundle Identifier to
   `com.yourname.crate` and the Team to yours.
2. Optional, but it lets VMs use more memory: in the target's Signing &
   Capabilities, add **Increased Memory Limit** and **Extended Virtual Address
   Space**. If your account can't add them, leave them out; crate runs
   without them.
3. Pick your iPhone as the run destination and Run once. Xcode registers the
   bundle ID and creates the profile. You can delete the app afterwards.
4. Do the same for `com.yourname.crate.jithelper`, with no capabilities.
   You can skip this one if Xcode has already made your team a wildcard
   profile ("iOS Team Provisioning Profile: \*"); the script uses it.

With a paid membership you can make them in the
[developer portal](https://developer.apple.com/account/resources) instead:
an App ID for each bundle ID (with the two capabilities on the app's, if you
want them), then an iOS App Development profile for each that includes your
device. Download them and double-click to install.

## 3. Sign and install

Get the signing script, and your device's identifier:

    curl -LO https://raw.githubusercontent.com/oneamendez/crate-ios/main/Scripts/sign-ipa.sh
    chmod +x sign-ipa.sh
    xcrun devicectl list devices

Then sign and install in one step:

    BUNDLE_ID=com.yourname.crate ./sign-ipa.sh crate-unsigned.ipa --install <your device's identifier>

It says which profiles it used, and whether the memory entitlements went in.
It also leaves `crate-signed.ipa` beside the download, which you can install
any other way. `PROFILE`, `HELPER_PROFILE` and `IDENTITY` pick a profile or a
certificate when you have more than one.

## 4. Turn on JIT

Open crate and go to Settings. JIT has two methods:

- **Built-in StikJIT** (the default): Set Up JIT pairs the iPhone with crate
  and walks you through [LocalDevVPN](https://apps.apple.com/app/localdevvpn/id6755608044),
  which it needs. After that, "Turn on JIT when crate opens" turns it on each
  time you open crate.
- **[StikDebug](https://github.com/StikDebug/StikDebug)**, if you already use
  it: Turn On JIT opens StikDebug, which attaches and comes back.

JIT lasts until crate closes, so it's turned on again each time crate opens.

## 5. Install a VM

In the Install tab, pick a distribution and a memory size, then Install; crate
asks for the account to create in the VM. Without the memory entitlements, iOS
gives crate less memory, so pick a smaller size: Settings > Memory shows the
limit iOS gave it. Once the desktop is up, its own display settings change the
resolution; 1280 × 800 fits more on screen than the default.

## When something goes wrong

- **"no development profile"**: step 2 hasn't made one for that bundle ID,
  or it expired. Run the Xcode project again.
- **The install fails with a provisioning error**: the profile doesn't include
  your device. Run the Xcode project once with the device connected.
- **JIT won't turn on**: the profile has to be a development one, which allows
  a debugger to attach (get-task-allow); `sign-ipa.sh` warns when it doesn't.
- **Signed but it stopped opening**: the profile expired (7 days on a free
  account). Sign and install again; your VMs stay.

crate is developed and tested signed with both memory entitlements. Signing
without them, or with other re-signing tools, should work the same way as
long as the result keeps get-task-allow, but isn't tested yet.
