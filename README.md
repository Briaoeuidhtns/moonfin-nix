# Moonfin desktop Nix flake

Builds [Moonfin Core](https://github.com/Moonfin-Client/Moonfin-Core) **2.7.0**
from source for **`x86_64-linux`**, with native Nixpkgs libretro cores.
Nixpkgs, Flutter, application sources, and Dart dependencies are pinned.
ARM is intentionally unsupported.

## Run or install

Requires Nix with `nix-command` and `flakes` enabled and a graphical Linux session.

```sh
nix run .
# Or build without launching:
nix build .#moonfin-desktop
./result/bin/moonfin
# Install into your user profile, including the desktop launcher and icon:
nix profile add .#moonfin-desktop
```

The default package is also available as `packages.<system>.moonfin-desktop`.
Connect to an existing Jellyfin or Emby server from the app. A working graphics
driver and audio service are required for playback; secure credential storage
uses your desktop's Secret Service provider.

### NixOS / Home Manager

Add this repository as an input to your configuration flake. Keep its own
Nixpkgs pin to retain the tested Flutter toolchain and native core versions:

```nix
inputs.moonfin.url = "github:Briaoeuidhtns/moonfin-nix";
```

In a NixOS module receiving `inputs` via `specialArgs`:

```nix
{ inputs, pkgs, ... }:
{
  environment.systemPackages = [
    inputs.moonfin.packages.${pkgs.stdenv.hostPlatform.system}.moonfin-desktop
  ];
}
```

For Home Manager, pass `inputs` through `extraSpecialArgs` and use the same
package in `home.packages` instead.

## Native emulation

Moonfin loads the cores from immutable Nix store paths, not nightly buildbot
downloads. The package includes all 17 cores in Moonfin's native catalog:

| Systems | Core |
| --- | --- |
| NES | FCEUmm |
| SNES | Snes9x |
| Game Boy / Game Boy Color | Gambatte |
| Game Boy Advance | mGBA |
| Sega 8/16-bit systems | Genesis Plus GX |
| PlayStation | PCSX ReARMed |
| Arcade | FinalBurn Neo |
| Nintendo 64 | Mupen64Plus-Next |
| PSP | PPSSPP |
| Nintendo DS | melonDS |
| PC Engine | Beetle PCE Fast |
| Atari 2600 | Stella |
| Atari 7800 | ProSystem |
| Atari Lynx | Handy |
| WonderSwan | Beetle WonderSwan |
| Neo Geo Pocket | Beetle NeoPop |
| Virtual Boy | Beetle VB |

In **Settings → Playback → Emulator Cores**, packaged cores are marked
**Managed by Nix**. Install/remove switches are disabled; core options remain
editable. Rebuild the package to update cores. Old downloaded cores and stored
installation flags are ignored, without deleting existing user files.

PPSSPP's required support assets are included in its read-only system directory.
ROMs and proprietary BIOS files are **not** included. Other cores use Moonfin's
normal writable `games/system` application-support directory; saves retain
Moonfin's normal storage and server-sync behavior.

`moonfin-cores` is also available separately. Its manifest is
`share/moonfin/cores.json`; the desktop wrapper sets
`MOONFIN_LIBRETRO_MANIFEST` to that file. It is authoritative: a missing or
excluded core is unavailable, with no fallback download.

The bundle includes cores with restrictive/noncommercial licenses
(FinalBurn Neo, Genesis Plus GX, and Snes9x). The flake narrowly permits those
Nixpkgs packages; it does not enable unfree packages globally. Check each core's
license before redistribution or commercial use.

## Packaging and verification

`pkgs/moonfin-desktop.nix` builds the Linux Flutter application with Nixpkgs'
offline dependency machinery. `pkgs/pubspec.lock.json` mirrors upstream's Dart
lockfile; `pkgs/git-hashes.json` pins its Git dependencies.
GTK, mpv, SQLite, WebKitGTK, and native core dependencies come from Nixpkgs.
`patches/nix-libretro-cores.patch` integrates manifest discovery, core settings,
and native game loading. A small melonDS assembly patch fixes missing
non-executable-stack metadata that otherwise prevents loading with current glibc.

```sh
nix build .#moonfin-desktop
nix flake check
nix fmt -- flake.nix pkgs/moonfin-desktop.nix pkgs/moonfin-cores.nix checks/cores.nix
```

The desktop build runs regression tests for manifest precedence over stale
downloads/preferences, immutable core management, and packaged PSP assets.
The flake check loads all 17 native libraries and runs an original NES program
through Moonfin's libretro host, verifying the expected blue video frame rather
than just checking that the library opens.

Graphical smoke verification on x86_64 Linux: production startup and server
discovery; the actual managed-core screen; and NES video rendered through
Moonfin's native Flutter game bridge using a temporary isolated entry point.
Other systems have been library-load tested, not gameplay-tested.
Authenticated media/game launch and server-backed core-option saving have not
been exercised.

For a Moonfin update, change the source version/tag/hash, regenerate
`pkgs/pubspec.lock.json` from that release's `pubspec.lock`, and update
`pkgs/git-hashes.json` when its Git dependencies change. Rebase the discovery
patch, then build, run checks, and launch the client.
Update the Nixpkgs/core pin separately with `nix flake update nixpkgs`.

## Server scope

Moonfin's official server component is the
[Moonbase plugin](https://github.com/Moonfin-Client/Plugin) for Jellyfin or Emby,
not a separate server daemon. Server packaging and a NixOS module are deliberately
omitted for now; this flake does not modify or enable a media server.
