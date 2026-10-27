{
  lib,
  stdenvNoCC,
  libretro,
  coreIds ? [
    "fceumm"
    "snes9x"
    "gambatte"
    "mgba"
    "genesis_plus_gx"
    "pcsx_rearmed"
    "fbneo"
    "mupen64plus_next"
    "ppsspp"
    "melonds"
    "mednafen_pce_fast"
    "stella"
    "prosystem"
    "handy"
    "mednafen_wswan"
    "mednafen_ngp"
    "mednafen_vb"
  ],
}:
let
  # Moonfin's IDs are the actual libretro filenames, not always nixpkgs
  # attribute names (the Beetle cores and Mupen64Plus-Next in particular).
  cores = {
    fceumm = libretro.fceumm;
    snes9x = libretro.snes9x;
    gambatte = libretro.gambatte;
    mgba = libretro.mgba;
    genesis_plus_gx = libretro.genesis-plus-gx;
    pcsx_rearmed = libretro.pcsx-rearmed;
    fbneo = libretro.fbneo;
    mupen64plus_next = libretro.mupen64plus;
    ppsspp = libretro.ppsspp;
    # JIT code lives in a separate executable allocation, not on the stack.
    # Missing assembly metadata otherwise makes glibc reject dlopen.
    melonds = libretro.melonds.overrideAttrs (old: {
      patches = (old.patches or [ ]) ++ [ ../patches/melonds-noexec-stack.patch ];
    });
    mednafen_pce_fast = libretro.beetle-pce-fast;
    stella = libretro.stella;
    prosystem = libretro.prosystem;
    handy = libretro.handy;
    mednafen_wswan = libretro.beetle-wswan;
    mednafen_ngp = libretro.beetle-ngp;
    mednafen_vb = libretro.beetle-vb;
  };

  selected = lib.genAttrs coreIds (id: cores.${id});
  corePath =
    core: "${core}${core.libretroCore}/${lib.replaceStrings [ "-" ] [ "_" ] core.core}_libretro.so";
  systemDirectory = "${placeholder "out"}/share/libretro/system";
  manifest = builtins.toJSON {
    cores = lib.mapAttrs (
      id: core:
      { path = corePath core; } // lib.optionalAttrs (id == "ppsspp") { inherit systemDirectory; }
    ) selected;
  };
in
assert lib.assertMsg (lib.all (
  id: builtins.hasAttr id cores
) coreIds) "moonfin-cores: unknown core ID in coreIds";
stdenvNoCC.mkDerivation {
  pname = "moonfin-cores";
  version = "2.7.0";
  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/share/moonfin"
    cat > "$out/share/moonfin/cores.json" <<'EOF'
    ${manifest}
    EOF

    ${lib.concatMapStringsSep "\n" (id: ''test -f "${corePath selected.${id}}"'') coreIds}
    ${lib.optionalString (builtins.hasAttr "ppsspp" selected) ''
      # PPSSPP's libretro core expects assets under system/PPSSPP. These are
      # from the same pinned source as the native core, not downloaded at run time.
      mkdir -p "$out/share/libretro/system/PPSSPP"
      cp -R ${libretro.ppsspp.src}/assets/. "$out/share/libretro/system/PPSSPP/"
      test -f "$out/share/libretro/system/PPSSPP/compat.ini"
    ''}
    runHook postInstall
  '';

  passthru = { inherit coreIds; };
  meta = {
    description = "Native libretro cores and PPSSPP assets for Moonfin";
    platforms = [ "x86_64-linux" ];
    license = lib.unique (map (id: selected.${id}.meta.license) coreIds);
  };
}
