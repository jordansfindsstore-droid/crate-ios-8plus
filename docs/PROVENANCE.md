# Where crate's code comes from

Everything the app ships besides its own code, where each piece comes from, and
how it gets into `Frameworks/`. Nothing there is committed: the scripts in
`Scripts/` fetch or build it, pinned to a version and checked against a SHA-256
or a commit. The frameworks are published as a checksum-pinned release;
`fetch-frameworks.sh` defaults to the upstream crate-ios release, and can be
pointed at this fork's release with `FRAMEWORKS_REPOSITORY`. The build scripts
make the same files from source. crate's own code is MPL-2.0
([LICENSE](../LICENSE)); each piece below keeps its own license, and
[THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md) has every license's text,
down to the Rust libraries.

| Piece | Version | License | From | How |
| --- | --- | --- | --- | --- |
| [crate](https://github.com/oneamendez/crate) | v0.1.1 | MPL-2.0 | its release, attested | `fetch-crate.sh`, or `build-crate.sh` from a checkout |
| [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) | 1.18.0 | MIT | Swift package | Xcode |
| [libslirp](https://gitlab.freedesktop.org/slirp/libslirp) | 4.9.7 | BSD-3-Clause | its release's source | `build-slirp.sh` |
| [GLib](https://gitlab.gnome.org/GNOME/glib) | 2.90.1 | LGPL-2.1-or-later | its release's source | `build-slirp.sh`, unmodified, a dynamic framework |
| [libffi](https://github.com/libffi/libffi) | 3.5.2 | MIT | GLib's meson subproject | linked into GLib |
| [PCRE2](https://github.com/PCRE2Project/pcre2) | 10.46 | BSD-3-Clause | GLib's meson subproject | linked into GLib |
| [proxy-libintl](https://github.com/frida/proxy-libintl) | 0.5 | LGPL-2.0-or-later | GLib's meson subproject | linked into GLib |
| [MoltenVK](https://github.com/KhronosGroup/MoltenVK) | 1.4.2 | Apache-2.0 | its release tag's source | `build-moltenvk.sh` |
| [ANGLE](https://chromium.googlesource.com/angle/angle) | 9addc29 | BSD-3-Clause | its source | `build-angle.sh`, one patch |
| [libepoxy](https://github.com/anholt/libepoxy) | 1.5.10 | MIT | its release's source | `build-virgl.sh`, one patch |
| [virglrenderer](https://gitlab.freedesktop.org/virgl/virglrenderer) | 1.3.0 | MIT | its release's source | `build-virgl.sh`, three patches |

MoltenVK's build fetches its own dependencies at the revisions its release
names; SPIRV-Cross, SPIRV-Tools, SPIRV-Headers, cereal and the Vulkan headers
end up in MoltenVK.framework (Apache-2.0, MIT and BSD-3-Clause). ANGLE's gclient
checkout does the same for what ANGLE links: Abseil, astc-encoder, LLVM's libc,
SPIRV-Tools, SPIRV-Headers, the Vulkan headers, Vulkan Memory Allocator and zlib
(Apache-2.0, MIT and Zlib). crate's Rust libraries are listed in
[THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md).

GLib is LGPL: it stays its own framework, unmodified, so it can be replaced,
and its source is its release's tarball, which `build-slirp.sh` downloads and
checks. Everything else is permissive or MPL-2.0, so the app as a whole can be
MPL-2.0.

## Not in the app

These are installed separately; none is built into or redistributed with
crate:

- [SideStore](https://github.com/SideStore/SideStore) (AGPL-3.0), used to
  install crate and enable JIT on iOS 16; its iOS 16 source path is documented
  in [IOS16_PORT.md](IOS16_PORT.md).
- [iloader](https://github.com/nab138/iloader) (MIT), an optional Windows
  installer for SideStore. Its README lists iTunes as the Windows USB device
  service; neither tool is bundled.
- [LocalDevVPN](https://apps.apple.com/app/localdevvpn/id6755608044), which
  SideStore documents as part of its remote-debug integration. Use it only as
  a separately installed personal-use app. This project does not bundle,
  modify, or redistribute it.
- Apple's macOS, Xcode, signing service, and iTunes for Windows are external,
  closed-source build or installation requirements; this project does not
  bundle or redistribute them.
- The guest images, from
  [arm64-desktop-images](https://github.com/oneamendez/arm64-desktop-images):
  downloaded when installing a VM, never part of the app. Each distribution
  is under its own licenses.

## The patches

In `Scripts/patches/`, each with a header saying what it changes and why:

- `angle-vulkan.patch`: ANGLE's Vulkan backend inside an iOS app, on MoltenVK.
  Written for aTerm, the app crate succeeds, and carried over unchanged.
- `libepoxy-ios-angle.patch`: libepoxy's EGL support on an iPhone, opening
  ANGLE's frameworks.
- `virglrenderer-angle-integer-attribs.patch`: integer vertex attributes
  declared as integers on ANGLE, which Vulkan holds to their declared type.
  Without it every glyph and image Chrome draws on the GPU samples the wrong
  place.
- `virglrenderer-border-clamp.patch`: clamp to the edge where ANGLE on MoltenVK
  has no border clamp, rather than a call ANGLE refuses.
- `virglrenderer-cursor-rows.patch`: the cursor's rows top first, as crate shows
  them; upstream turns every cursor upside down.

## The 3D stack

The guest's Mesa draws through virtio-gpu; crate hands those commands to
virglrenderer, which turns them into OpenGL ES calls (through libepoxy) on ANGLE,
which runs on Vulkan, which is MoltenVK, on Metal. Guest images need nothing of
their own for it: Mesa's virgl driver and the kernel's virtio-gpu driver, both
standard in Debian and Arch.

aTerm had the same stack, but only ANGLE was its own build from upstream: it
took virglrenderer, libepoxy and MoltenVK prebuilt from another project, with
that project's changes to virglrenderer. None of that is used here. Each piece
is built from its upstream release. virglrenderer's three patches above are
crate's own, each found by comparing upstream's behaviour with that build's on
the same guest, never from its source. The sample-count override aTerm had to
patch around isn't in upstream. virglrenderer is built with its
`check-gl-errors` option off, so a GL call ANGLE refuses costs that call rather
than the guest's whole GL context.
