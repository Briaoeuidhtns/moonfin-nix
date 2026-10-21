{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  wrapGAppsHook3,
  alsa-lib,
  atk,
  cairo,
  fontconfig,
  gdk-pixbuf,
  glib,
  gtk3,
  harfbuzz,
  libarchive,
  libepoxy,
  libsecret,
  libsoup_3,
  librsvg,
  mpv-unwrapped,
  pango,
  sqlite,
  systemd,
  webkitgtk_4_1,
  zlib,
}:

let
  version = "2.7.0";
  sources = {
    x86_64-linux = {
      name = "Moonfin_Linux_v${version}.tar.gz";
      hash = "sha256-b6llMdnUqTyzBPfId1SI6LhNm9KzgwFNo3PY0eRdMuE=";
    };
    aarch64-linux = {
      name = "Moonfin_LinuxARM64_v${version}.tar.gz";
      hash = "sha256-33TtGDeOx0Cf3D4RTjWpw6Rx7p6O/VUrSLAH0kwnIiM=";
    };
  };
  source = sources.${stdenv.hostPlatform.system};
in
stdenv.mkDerivation {
  pname = "moonfin-desktop";
  inherit version;

  src = fetchurl {
    url = "https://github.com/Moonfin-Client/Moonfin-Core/releases/download/${version}/${source.name}";
    inherit (source) hash;
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
    wrapGAppsHook3
  ];

  # Only keep application-specific libraries. Bundled distribution libraries
  # conflict with nixpkgs WebKit/GTK and graphics drivers at runtime.
  buildInputs = [
    alsa-lib
    atk
    cairo
    fontconfig
    gdk-pixbuf
    glib
    gtk3
    harfbuzz
    libarchive
    libepoxy
    libsecret
    libsoup_3
    librsvg
    mpv-unwrapped
    pango
    sqlite
    stdenv.cc.cc.lib
    webkitgtk_4_1
    zlib
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/lib/moonfin/lib" "$out/bin" "$out/share"
    cp moonfin-bin "$out/lib/moonfin/"
    cp lib/*_plugin.so lib/libapp.so lib/libflutter_linux_gtk.so \
      lib/libpdfium.so "$out/lib/moonfin/lib/"
    cp -r data "$out/lib/moonfin/"
    cp -r share/. "$out/share/"

    # media_kit and SQLite look beside the application as well as using dlopen.
    ln -s ${lib.getLib mpv-unwrapped}/lib/libmpv.so "$out/lib/moonfin/lib/libmpv.so"
    ln -s ${lib.getLib sqlite}/lib/libsqlite3.so "$out/lib/moonfin/lib/libsqlite3.so"

    runHook postInstall
  '';

  # Resolve libraries loaded dynamically rather than recorded in ELF NEEDED.
  dontWrapGApps = true;
  preFixup = ''
    addAutoPatchelfSearchPath "$out/lib/moonfin/lib"
    makeWrapper "$out/lib/moonfin/moonfin-bin" "$out/bin/moonfin" \
      --prefix LD_LIBRARY_PATH : "$out/lib/moonfin/lib:${
        lib.makeLibraryPath [
          mpv-unwrapped
          sqlite
          systemd
        ]
      }" \
      "''${gappsWrapperArgs[@]}"
  '';

  meta = {
    description = "Moonfin Jellyfin and Emby desktop media client";
    homepage = "https://github.com/Moonfin-Client/Moonfin-Core";
    license = lib.licenses.gpl2Plus;
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    mainProgram = "moonfin";
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
