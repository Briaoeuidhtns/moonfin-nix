# Moonfin desktop Nix flake

Packages [Moonfin Core](https://github.com/Moonfin-Client/Moonfin-Core) **2.7.0**
for `x86_64-linux` and `aarch64-linux`. This repackages the official release
binaries; it does not build Flutter from source. Nixpkgs is pinned in `flake.lock`
and both release archives have fixed SHA-256 hashes.

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

Add this repository as an input to your configuration flake (use its eventual
Git URL instead of the local path when publishing it):

```nix
inputs.moonfin.url = "path:/home/brian/Projects/moonfin";
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

## Packaging and verification

`pkgs/moonfin-desktop.nix` retains Moonfin's application binary, Flutter engine,
plugins, PDF engine, assets, and desktop integration. Distribution-provided
libraries bundled upstream are replaced with Nixpkgs libraries, including mpv,
SQLite, GTK, and WebKitGTK. This avoids ABI conflicts with the desktop stack and
provides WebKit's required subprocess binaries.

```sh
nix flake check --all-systems --no-build
nix build .#moonfin-desktop
nix fmt -- flake.nix pkgs/moonfin-desktop.nix
```

Verified on x86_64 Linux: package build, graphical launch to the server-selection
screen, server discovery, and media_kit hardware-renderer initialization. ARM64
is evaluation-checked only. Authenticated playback has not been tested.

For a Moonfin update, change `version` and both archive hashes in the package.
Obtain hashes with `nix store prefetch-file <release-archive-url>`, then rebuild
and launch the client. Update the Nixpkgs pin separately with
`nix flake update nixpkgs`.

## Server scope

Moonfin's official server component is the
[Moonbase plugin](https://github.com/Moonfin-Client/Plugin) for Jellyfin or Emby,
not a separate server daemon. Server packaging and a NixOS module are deliberately
omitted for now; this flake does not modify or enable a media server.
