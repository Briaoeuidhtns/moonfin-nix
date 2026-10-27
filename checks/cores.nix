{ pkgs, moonfin }:
pkgs.runCommandCC "moonfin-native-cores-check"
  {
    nativeBuildInputs = [ pkgs.python3 ];
  }
  ''
    cc -std=gnu11 -O2 -pthread \
      -I${moonfin.src}/native/libretro_host \
      ${moonfin.src}/native/libretro_host/libretro_host.c \
      ${./core-smoke.c} -ldl -lm -o core-smoke

    python - ${moonfin.cores}/share/moonfin/cores.json <<'PY'
    import json
    import pathlib
    import subprocess
    import sys

    cores = json.loads(pathlib.Path(sys.argv[1]).read_text())["cores"]
    # Separate processes prevent identically named retro_* symbols from leaking
    # across cores, and exercise each core's own Nix runtime closure.
    for name, core in cores.items():
        subprocess.run([
            sys.executable, "-c",
            "import ctypes,sys; c=ctypes.CDLL(sys.argv[1]); "
            "assert c.retro_api_version()==1, 'Unsupported libretro ABI'",
            core["path"],
        ], check=True)
        print(f"Loaded native core: {name}", flush=True)

    subprocess.run(["./core-smoke", cores["fceumm"]["path"]], check=True)
    PY
    touch "$out"
  ''
