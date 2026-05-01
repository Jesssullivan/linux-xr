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
            security_dir="${self}/xr/security"

            test -f "$series_file"
            test -f "$security_dir/cve-2026-31431-algif-aead.patch"

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
            bash -n "${self}/xr/scripts/check-cve-2026-31431-live.sh"
            bash -n "${self}/xr/scripts/check-security-config.sh"
            bash -n "${self}/xr/scripts/check-kernel-carry.sh"
            mkdir -p "$out"
          '';

          security-config = pkgs.runCommand "linux-xr-security-config-check" {
            nativeBuildInputs = with pkgs; [ bash coreutils gnugrep ];
          } ''
            set -euo pipefail
            bash "${self}/xr/scripts/check-security-config.sh" "${self}/xr/config/base.config"
            mkdir -p "$out"
          '';

          patch-application = pkgs.runCommand "linux-xr-patch-application-check" {
            nativeBuildInputs = with pkgs; [ bash patch ];
          } ''
            set -euo pipefail
            if [ -e "${self}/drivers/gpu/drm/drm_edid.c" ]; then
              patch --batch -d "${self}" -p1 --dry-run < "${self}/xr/patches/0007-vesa-dsc-bpp.patch"
              patch --batch -d "${self}" -p1 --dry-run < "${self}/xr/patches/bigscreen-beyond-edid.patch"
            else
              echo "kernel source paths absent; skipping patch application in sparse checkout"
            fi
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
              exec bash "$repo_root/xr/scripts/generate-cadence-report.sh" "$@"
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
