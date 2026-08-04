{
  description = "Pipes terminal screensaver — unofficial Python rewrite of pipes.sh";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
          package = pkgs.callPackage ./nix/package.nix { };
        in
        {
          pipes = package;
          "pipes-sh-python" = package;
          default = package;
        }
      );

      apps = forAllSystems (system: rec {
        pipes = {
          type = "app";
          program = "${self.packages.${system}.pipes}/bin/pipes";
        };
        default = pipes;
      });

      checks = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
          package = self.packages.${system}.pipes;
          source = nixpkgs.lib.cleanSource ./.;
          closure = pkgs.closureInfo { rootPaths = [ package ]; };
        in
        {
          inherit package;

          source-tests = pkgs.runCommand "pipes-source-tests" { nativeBuildInputs = [ pkgs.python3 ]; } ''
            cp -r ${source} source
            chmod -R u+w source
            cd source
            python -m compileall -q pipes_sh.py tests
            python -m unittest discover -s tests -v
            python pipes_sh.py --self-test | grep -q '^pipes self-test: PASS$'
            python -O pipes_sh.py --self-test | grep -q '^pipes self-test: PASS$'
            touch "$out"
          '';

          cli-smoke = pkgs.runCommand "pipes-cli-smoke" { nativeBuildInputs = [ package ]; } ''
            pipes --help >/dev/null
            test "$(pipes --version)" = "pipes 3.0.0"
            pipes --self-test | grep -q '^pipes self-test: PASS$'
            grep -q '${pkgs.ncurses}/share/terminfo' ${package}/bin/pipes
            touch "$out"
          '';

          runtime-closure-policy = pkgs.runCommand "pipes-runtime-closure-policy" { } ''
            if grep -E '/[^/]*(setuptools|wheel|pytest|gcc-wrapper|binutils-wrapper)-' \
              ${closure}/store-paths; then
              echo "forbidden build or test dependency in Pipes runtime closure" >&2
              exit 1
            fi
            touch "$out"
          '';
        }
      );

      devShells = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              python3
              python3Packages.build
              python3Packages.installer
              python3Packages.setuptools
              python3Packages.wheel
              ruff
              nixfmt-rfc-style
              ncurses
              groff
            ];
          };
        }
      );
    };
}
