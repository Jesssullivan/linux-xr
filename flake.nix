{
  description = "Thin Nix surface for linux-xr developer tooling and CI";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
  };

  outputs = { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];

      forAllSystems = f:
        builtins.listToAttrs (map (system: {
          name = system;
          value = f system;
        }) systems);
    in
    {
      devShells = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          default = pkgs.mkShell {
            packages =
              (with pkgs; [
                bashInteractive
                ccache
                coreutils
                curl
                cpio
                diffutils
                findutils
                gawk
                git
                gnugrep
                gnused
                gnutar
                gzip
                jq
                patch
                ripgrep
                xz
              ])
              ++ pkgs.lib.optionals pkgs.stdenv.isLinux [
                pkgs.rpm
              ];

            shellHook = ''
              echo "linux-xr dev shell"
              echo "  - nix flake check          # validate thin flake outputs"
              echo "  - ./xr/scripts/build-rpm.sh # canonical Linux/RPM build path"
            '';
          };
        });

      checks = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          patch-series = pkgs.runCommand "linux-xr-patch-series-check" {
            nativeBuildInputs = with pkgs; [ bash coreutils gnugrep ];
          } ''
            set -euo pipefail
            patch_dir="${self}/xr/patches"
            series_file="$patch_dir/series"

            test -f "$series_file"

            while IFS= read -r patch; do
              case "$patch" in
                ""|\#*)
                  continue
                  ;;
              esac

              test -f "$patch_dir/$patch"
            done < "$series_file"

            mkdir -p "$out"
          '';

          shell-syntax = pkgs.runCommand "linux-xr-shell-syntax-check" {
            nativeBuildInputs = with pkgs; [ bash coreutils ];
          } ''
            set -euo pipefail
            bash -n "${self}/xr/scripts/build-rpm.sh"
            bash -n "${self}/xr/scripts/generate-cadence-report.sh"
            mkdir -p "$out"
          '';
        });

      apps = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
          cadenceReport = pkgs.writeShellApplication {
            name = "linux-xr-cadence-report";
            runtimeInputs = with pkgs; [ bash git coreutils gnugrep gnused ];
            text = ''
              set -euo pipefail
              repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
              exec "$repo_root/xr/scripts/generate-cadence-report.sh" "$@"
            '';
          };
        in
        {
          cadence-report = {
            type = "app";
            program = "${cadenceReport}/bin/linux-xr-cadence-report";
          };
        });

      formatter = forAllSystems (system:
        (import nixpkgs { inherit system; }).nixfmt-rfc-style);
    };
}
