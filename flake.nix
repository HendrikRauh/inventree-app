{
  description = "InvenTree App Development Environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs-flutter.url = "github:NixOS/nixpkgs/b9c03fbbaf84d85bb28eee530c7e9edc4021ca1b";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      nixpkgs-flutter,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
            android_sdk.accept_license = true;
          };
          overlays = [
            (final: prev: {
              flutter-pkg = import (self.inputs.nixpkgs-flutter) { inherit system; };
            })
          ];
        };

        androidSdk =
          (pkgs.androidenv.composeAndroidPackages {
            platformVersions = [
              "35"
              "34"
            ];
            buildToolsVersions = [
              "35.0.0"
              "34.0.0"
            ];
            includeNDK = true;
            ndkVersions = [ "26.1.10909125" ];
            cmakeVersions = [ "3.22.1" ];
          }).androidsdk;

        linuxOptionals = with pkgs; [
          gtk3
          glib
          pcre
          libepoxy
          libxkbcommon
          dbus
          at-spi2-core
          file
        ];

        fvmScript = ''
          case "$1" in
            use)
              echo "✓ Using Flutter from Nix ($(flutter --version | head -n1))"
              exit 0
              ;;
            flutter)
              shift
              exec flutter "$@"
              ;;
            dart)
              shift
              exec dart "$@"
              ;;
            *)
              echo "fvm wrapper: command '$1' not implemented (using Nix-managed Flutter)" >&2
              exit 1
              ;;
          esac
        '';
        fvm-wrapper = pkgs.writeShellScriptBin "fvm" fvmScript;
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs =
            with pkgs;
            [
              flutter-pkg.flutter
              fvm-wrapper
              jdk17
              android-tools
              gradle
              python3
              python3Packages.invoke
              jq
              git
              curl
              unzip
              which
            ]
            ++ lib.optionals stdenv.isLinux linuxOptionals;

          shellHook = ''
            export ANDROID_HOME="${androidSdk}/libexec/android-sdk"
            export ANDROID_SDK_ROOT="$ANDROID_HOME"
            export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/tools/bin:$PATH"
            export JAVA_HOME="${pkgs.jdk17}"
            export GRADLE_OPTS="-Dorg.gradle.project.android.aapt2FromMavenOverride=$ANDROID_HOME/build-tools/35.0.0/aapt2"
          '';

          LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath (with pkgs; linuxOptionals);
        };
      }
    );
}
