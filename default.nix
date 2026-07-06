{
  lib,
  stdenv,
  fetchFromGitHub,
  nodejs_22,
  python3,
  pnpm,
  pnpmConfigHook,
  fetchPnpmDeps,
  electron,
  rustPlatform,
  pkg-config,
  alsa-lib,
  rustc,
  cargo,
  libclang,
  ffmpeg,
  version ? "2.3.8",
}:

let
  src = fetchFromGitHub {
    owner = "Fantasy-XY808";
    repo = "Soto-Player-Community";
    rev = "Release_V_${version}";
    hash = "sha256-Y/D+cPPsY2DYqmidaM6WMDmznkawcIszsqd9XyW/QGI=";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit src;
    pname = "soto-player-community";
    version = "${version}";
    hash = "sha256-G/QD0eZtN4Ot1/nt/p4I/zbPdGWe06yKy7nOal0OlGM=";
    fetcherVersion = 3;
    pnpm = pnpm;
    pnpmInstallFlags = [ "--frozen-lockfile" ];
  };

  cargoDeps = rustPlatform.importCargoLock {
    lockFile = "${src}/Cargo.lock";
    outputHashes = {
      "ffmpeg_audio-0.1.0" = "sha256-mcFNN6opRtmofuEg2BsWpOiutFQ23DAe+TCXBL1MQfE=";
    };
  };
in
stdenv.mkDerivation {
  pname = "soto-player-community";
  inherit version src pnpmDeps;

  nativeBuildInputs = [
    nodejs_22
    python3
    pnpm
    pnpmConfigHook
    pkg-config
    rustc
    cargo
    libclang
    rustPlatform.cargoSetupHook
  ];

  buildInputs = [
    alsa-lib
    ffmpeg.dev
  ] ++ lib.optional (lib.versionAtLeast electron.version "41") electron.headers;

  cargoDeps = cargoDeps;

  ELECTRON_SKIP_BINARY_DOWNLOAD = "1";
  ELECTRON_OVERRIDE_DIST_PATH = "${electron}/bin";
  LIBCLANG_PATH = "${libclang.lib}/lib";
  BINDGEN_EXTRA_CLANG_ARGS = "-I${ffmpeg.dev}/include -I${stdenv.cc.libc.dev}/include";

  postPatch = ''
    # Skip electron-rebuild
    substituteInPlace package.json --replace-fail \
      '"postinstall": "electron-rebuild -f -w better-sqlite3"' \
      '"postinstall": "echo skip electron-rebuild"'

    # Patch ffmpeg_audio_sys build.rs to use system FFmpeg via pkg-config
    BUILD_RS=$(find "$NIX_BUILD_TOP" -path "*/ffmpeg_audio_sys-*/build.rs" -type f 2>/dev/null | head -1)
    if [ -n "$BUILD_RS" ]; then
      cat > "$BUILD_RS" << 'EOFRS'
fn main() {
    pkg_config::Config::new()
        .atleast_version("58.0").probe("libavutil").expect("libavutil not found");
    pkg_config::Config::new()
        .atleast_version("60.0").probe("libavformat").expect("libavformat not found");
    pkg_config::Config::new()
        .atleast_version("60.0").probe("libavcodec").expect("libavcodec not found");
    pkg_config::Config::new()
        .atleast_version("3.0").probe("libswresample").expect("libswresample not found");
    println!("cargo:rustc-link-lib=m");
    println!("cargo:rustc-link-lib=pthread");
    let bindings = bindgen::Builder::default()
        .header("wrapper.h")
        .parse_callbacks(Box::new(bindgen::CargoCallbacks::new()))
        .allowlist_function("av_.*").allowlist_function("avformat_.*")
        .allowlist_function("avcodec_.*").allowlist_function("avio_.*")
        .allowlist_function("swr_.*").allowlist_type("AV.*").allowlist_type("Swr.*")
        .allowlist_var("AV_.*").allowlist_var("AVERROR_.*").allowlist_var("AVFMT_.*")
        .allowlist_var("AVSEEK.*")
        .generate().expect("Unable to generate FFmpeg bindings");
    bindings.write_to_file(std::path::PathBuf::from(std::env::var("OUT_DIR").unwrap()).join("bindings.rs"))
        .expect("Couldn't write bindings");
}
EOFRS
      echo "[postPatch] Patched ffmpeg_audio_sys build.rs to use system FFmpeg"
    else
      echo "[postPatch] WARNING: ffmpeg_audio_sys build.rs not found at $NIX_BUILD_TOP"
    fi
  '';

  buildPhase = ''
    runHook preBuild

    # Build better-sqlite3 native module for Electron
    export HOME=$TMPDIR
    BSQLITE_DIR=$(find node_modules/.pnpm -path "*/better-sqlite3@*" -type d -name "better-sqlite3" 2>/dev/null | head -1)
    if [ -n "$BSQLITE_DIR" ]; then
      cd "$BSQLITE_DIR"
      npx node-gyp rebuild --nodedir="${electron.headers}" 2>&1 || echo "better-sqlite3 build failed"
      cd $NIX_BUILD_TOP/source
    fi

    # Build native Rust addons using system FFmpeg
    cd native/audio-engine
    npx napi build --release --no-const-enum 2>&1 || echo "audio-engine build failed, continuing"
    cd $NIX_BUILD_TOP/source

    cd native/media-ctrl
    npx napi build --release --no-const-enum 2>&1 || echo "media-ctrl build failed, continuing"
    cd $NIX_BUILD_TOP/source

    # Build main app
    pnpm build
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/soto-player
    cp -r out $out/lib/soto-player/
    cp package.json $out/lib/soto-player/
    tar cf - node_modules | tar xf - -C $out/lib/soto-player/

    # Copy native .node files
    for dir in audio-engine media-ctrl; do
      mkdir -p $out/lib/soto-player/native/$dir
      cp native/$dir/*.node $out/lib/soto-player/native/$dir/ 2>/dev/null || true
    done

    mkdir -p $out/bin
    cat > $out/bin/soto-player <<EOF
    #!${stdenv.shell}
    cd $out/lib/soto-player && exec ${electron}/bin/electron . "\$@"
    EOF
    chmod +x $out/bin/soto-player

    mkdir -p $out/share/applications
    mkdir -p $out/share/icons/hicolor/256x256/apps
    cp $out/lib/soto-player/out/renderer/icons/favicon-256x256.png $out/share/icons/hicolor/256x256/apps/soto-player.png
    cat > $out/share/applications/soto-player.desktop <<EOF
    [Desktop Entry]
    Type=Application
    Name=Soto Player-Community
    Comment=水芸音乐播放器
    Exec=$out/bin/soto-player
    Icon=soto-player
    Categories=Audio;Music;Player;
    Terminal=false
    EOF

    runHook postInstall
  '';

  meta = with lib; {
    description = "Soto Player-Community / 水芸音乐播放器";
    homepage = "https://github.com/Fantasy-XY808/Soto-Player-Community";
    license = licenses.agpl3Only;
    platforms = platforms.linux;
  };
}