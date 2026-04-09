{
  description = "Development and Building environment for BS1";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    nixpkgs-legacy.url = "github:nixos/nixpkgs?ref=nixos-23.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, nixpkgs-legacy, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        pkgs-legacy = nixpkgs-legacy.legacyPackages.${system};

        isDarwin = pkgs.stdenv.isDarwin;

        custom-bochs = pkgs.stdenv.mkDerivation rec {
          pname = "bochs";
          version = "2.7";

          src = pkgs.fetchurl {
            url = "https://downloads.sourceforge.net/project/bochs/bochs/${version}/bochs-${version}.tar.gz";
            sha256 = "sha256-oBCrG/3HKsWgjS4kEs1HHA/r1mrx2TSbwNeWh53lsXo=";
          };

          # libsdl2-env and libreadline-dev
          buildInputs = with pkgs; [ SDL2 readline ];
          nativeBuildInputs = with pkgs; [ pkg-config ];

          NIX_CFLAGS_COMPILE = "-I${pkgs.SDL2.dev}/include/SDL2";

          # bochs configure varible
          configureFlags = [
            "--with-sdl2"
            "--enable-x86-debugger"
            "--enable-readline"
            "--enable-all-optimizations"
            "--enable-gdb-stub"
          ];
        };

        # Wrapper Scripts
        sys-grub = if isDarwin then pkgs.pkgsCross.gnu32.grub2 else pkgs.grub2;

        grub-wrapper = pkgs.writeShellScriptBin "grub-mkrescue" ''
          NEW_ARGS=()
          for arg in "$@"; do
            if [ "$arg" = "/usr/lib/grub/i386-pc" ]; then
              NEW_ARGS+=("${sys-grub}/lib/grub/i386-pc")
            else
              NEW_ARGS+=("$arg")
            fi
          done
          exec ${sys-grub}/bin/grub-mkrescue "''${NEW_ARGS[@]}"
        '';

        bochs-wrapper = pkgs.writeShellScriptBin "bochs" ''
          export BXSHARE="${custom-bochs}/share/bochs"
          if [ -f bochsrc.txt ]; then
            sed -e "s|/usr/local/share/bochs|$BXSHARE|g" \
                -e "s|/usr/share/bochs|$BXSHARE|g" \
                -e "s|/usr/share/vgabios|$BXSHARE|g" \
                -e "s|/usr/share/seavgabios|$BXSHARE|g" \
                bochsrc.txt > .bochsrc-nix.txt
            echo "Nix Wrapper: Redirecting BIOS paths to $BXSHARE"
            exec ${custom-bochs}/bin/bochs -f .bochsrc-nix.txt "$@"
          else
            exec ${custom-bochs}/bin/bochs "$@"
          fi
        '';

        # MAC Cross Compiler Spoofer
        mac-gcc = pkgs.writeShellScriptBin "gcc" ''exec ${pkgs.pkgsCross.gnu32.buildPackages.gcc12}/bin/i686-unknown-linux-gnu-gcc "$@"'';
        mac-gpp = pkgs.writeShellScriptBin "g++" ''exec ${pkgs.pkgsCross.gnu32.buildPackages.gcc12}/bin/i686-unknown-linux-gnu-g++ "$@"'';
        mac-ld  = pkgs.writeShellScriptBin "ld"  ''exec ${pkgs.pkgsCross.gnu32.buildPackages.binutils}/bin/i686-unknown-linux-gnu-ld "$@"'';

        # Input Groups
        linux-chain = [ pkgs-legacy.gcc_multi ];
        mac-chain = [ mac-gcc mac-gpp mac-ld ];

        compile-chain = with pkgs; (if isDarwin then mac-chain else linux-chain) ++ [
          # Clang Compiler
          pkgs-legacy.clang_14
          pkgs-legacy.lld_14

          # Assembly & Build Tools
          nasm
          gnumake
          xorriso

          # Tools for ISO generation
          mtools
          grub-wrapper
          bochs-wrapper
        ];

        libs = with pkgs; [ readline SDL2 ];
        debug-programs = with pkgs; [ gdb ddd perl ];
        utils = with pkgs; [ git vim ];

        costubs-package = pkgs.stdenv.mkDerivation {
          pname = "CoStuBs";
          version = "1.0-dev";
          src = ./.;

          nativeBuildInputs = compile-chain;

          buildPhase = ''
            echo "Building CoStuBs"
            make -C bin clean bootdisk
          '';

          installPhase = ''
            mkdir -p $out
            cp bin/costubs.iso $out/
          '';
        };

        all-packages = compile-chain ++ libs ++ debug-programs ++ utils;
      in
      {
        packages.bochs = custom-bochs;

        # --- `nix build` Target ---
        packages.default = costubs-package;

        # --- `nix run` Target ---
        apps.default = {
          type = "app";
          program = "${pkgs.writeShellScriptBin "run-costubs" ''
            export PATH=${pkgs.lib.makeBinPath all-packages}:$PATH

            echo "Nix Run: Automatically building OS in the Nix sandbox..."
            WORK_DIR=$(mktemp -d)
            trap 'rm -rf "$WORK_DIR"' EXIT

            echo "Nix Run: Setting up ephemeral environment in $WORK_DIR"
            cp bin/bochsrc.txt "$WORK_DIR/"
            cp ${costubs-package}/costubs.iso "$WORK_DIR/"

            echo "Nix Run: Startig Bochs..."
            cd $WORK_DIR
            bochs -q
          ''}/bin/run-costubs";
        };

        # --- `nix develop` Target ---
        devShells.default = pkgs.mkShell {
          packages = [ ] ++ all-packages;

          shellHook = ''
            echo "BS1 Development Environment Loaded!"
            ${if isDarwin
              then ''echo "Architecture: Mac (ARM/Intel) -> Using i686 Cross-Compiler Spoofing"''
              else ''echo "Archutecture: Linux -> Using Native GCC Multi"''
            }

            # --- Automatic Gitignore Setup ---
            if ! grep -q "^result$" .gitignore 2>/dev/null; then
              echo "result" >> .gitignore
              echo "result-*" >> .gitignore # Catches result-bin, result-lib, etc.
              echo "Nix Hook: Automatically added 'result' symlinks to .gitignore"
            fi
          '';
        };
      }
    );
}
