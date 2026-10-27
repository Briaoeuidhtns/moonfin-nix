{
  lib,
  flutter,
  fetchFromGitHub,
  autoPatchelfHook,
  copyDesktopItems,
  makeDesktopItem,
  python3,
  alsa-lib,
  gtk3,
  libarchive,
  libepoxy,
  libsecret,
  libsoup_3,
  librsvg,
  mpv-unwrapped,
  sqlite,
  systemd,
  webkitgtk_4_1,
  cores,
}:
let
  testCores = cores.override {
    coreIds = [
      "fceumm"
      "ppsspp"
    ];
  };
in
flutter.buildFlutterApplication {
  pname = "moonfin-desktop";
  version = "2.7.0";

  src = fetchFromGitHub {
    owner = "Moonfin-Client";
    repo = "Moonfin-Core";
    tag = "2.7.0";
    hash = "sha256-fbc3ZKe/6/3Wik+GzEvpkYGxkOEdHIC84O4BcU7Ho+A=";
  };

  pubspecLock = lib.importJSON ./pubspec.lock.json;
  gitHashes = lib.importJSON ./git-hashes.json;
  patches = [ ../patches/nix-libretro-cores.patch ];
  postPatch = ''
    cp ${../checks/discovery_test.dart} test/nix_core_discovery_test.dart
  '';

  nativeBuildInputs = [
    autoPatchelfHook
    copyDesktopItems
    python3
  ];
  buildInputs = [
    alsa-lib
    gtk3
    libarchive
    libepoxy
    libsecret
    libsoup_3
    librsvg
    mpv-unwrapped
    sqlite
    webkitgtk_4_1
  ];
  extraWrapProgramArgs = ''
    --prefix LD_LIBRARY_PATH : ${
      lib.makeLibraryPath [
        mpv-unwrapped
        sqlite
        systemd
      ]
    } \
    --set MOONFIN_LIBRETRO_MANIFEST ${cores}/share/moonfin/cores.json
  '';

  doCheck = true;
  checkPhase = ''
    runHook preCheck
    python - ${testCores}/share/moonfin/cores.json "$TMPDIR/test-cores.json" <<'PY'
    import json
    import pathlib
    import sys
    available = json.loads(pathlib.Path(sys.argv[1]).read_text())["cores"]
    fixture = {"cores": {
        "fceumm": available["fceumm"],
        "ppsspp": available["ppsspp"],
        "snes9x": {"path": "/no-such-core/snes9x_libretro.so"},
    }}
    pathlib.Path(sys.argv[2]).write_text(json.dumps(fixture))
    PY
    MOONFIN_LIBRETRO_MANIFEST="$TMPDIR/test-cores.json" \
      flutter test --no-pub test/nix_core_discovery_test.dart
    runHook postCheck
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "org.moonfin.linux";
      desktopName = "Moonfin";
      exec = "moonfin %U";
      icon = "org.moonfin.linux";
      comment = "Jellyfin & Emby media client";
      categories = [
        "AudioVideo"
        "Video"
      ];
      mimeTypes = [ "x-scheme-handler/moonfin" ];
      startupWMClass = "org.moonfin.linux";
    })
  ];
  postInstall = ''
    install -Dm644 assets/icons/app_icon.png \
      "$out/share/icons/hicolor/512x512/apps/org.moonfin.linux.png"
  '';

  passthru = { inherit cores; };
  meta = {
    description = "Moonfin Jellyfin and Emby desktop media client with native libretro cores";
    homepage = "https://github.com/Moonfin-Client/Moonfin-Core";
    license = lib.licenses.gpl2Plus;
    platforms = [ "x86_64-linux" ];
    mainProgram = "moonfin";
  };
}
