{
  description = "FRP-TODO-LIST: a TODO list as a tiny projectional editor, in Haskell with Yampa and SDL2";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
        inherit (pkgs) lib;

        # GHC 9.14.1, named exactly so that a nixpkgs update cannot move the
        # app on to a later 9.14. The binary cache has the compiler but not
        # the libraries for it, so nix compiles those the first time.
        #
        # The Haddock of GHC 9.14.1 can hang when it documents a library in
        # parallel: in a full build it stalled, with every thread idle, on
        # old-locale and nanospec. The app needs no library documentation, so
        # the package set builds none.
        haskellPackages = pkgs.haskell.packages.ghc9141.override (old: {
          overrides = lib.composeExtensions (old.overrides or (_: _: { })) (
            _: super: {
              mkDerivation = args: super.mkDerivation (args // { doHaddock = false; });
            }
          );
        });

        # HLS for the dev shell. nixpkgs packages 2.13, which stops at GHC
        # 9.12; GHC 9.14 needs 2.15. It gets its own package set on top of the
        # app's, so the newer lsp, hie-bios and so on it needs stay out of the
        # app's build, and out of hdb's, which wants a hie-bios older than
        # 0.20, while it still uses the same GHC 9.14.1.
        hlsPackages = haskellPackages.override (old: {
          overrides = lib.composeExtensions (old.overrides or (_: _: { })) (
            self: super:
            let
              inherit (pkgs.haskell.lib.compose) overrideCabal addBuildDepends doJailbreak;
              # Point a nixpkgs package at a newer Hackage release, keeping
              # nixpkgs' tweaks to it, such as the HLS wrapper links.
              bump =
                version: sha256:
                overrideCabal {
                  inherit version sha256;
                  revision = null;
                  editedCabalFile = null;
                };
              # nixpkgs builds HLS and some of its dependencies against Cabal
              # 3.14, but on GHC 9.14 they need its boot Cabal, 3.16.
              useBootCabal =
                drv:
                drv.overrideScope (
                  _: _: {
                    inherit (self)
                      Cabal
                      Cabal-syntax
                      cabal-install-parsers
                      extensions
                      ghc-paths
                      ;
                  }
                );
            in
            {
              # Only the HLS executable is wanted from this set, so nothing in
              # it runs its tests.
              mkDerivation = args: super.mkDerivation (args // { doCheck = false; });

              hls-graph =
                bump "2.15.0.0" "80533597e0b0e8cc3202a135e820275d2faa7a1e048e0983f251696228df2b6e"
                  super.hls-graph;
              hls-plugin-api = useBootCabal (
                bump "2.15.0.0" "3e58cde686c87ccd4a88215cc2fb5a1589ad7ba405737fbb8a67f8e0d628a036"
                  super.hls-plugin-api
              );
              ghcide = useBootCabal (
                bump "2.15.0.0" "3ce5d8bb9d1e5e916fba7671b4c88853d7f460427349a819035a10e20eaab8c3" super.ghcide
              );
              hls-test-utils = addBuildDepends [ self.primitive ] (
                bump "2.15.0.0" "b2ba501898957ee959f7a631accc5d2b59fbc46c95f657fbcfcf63aebe07eed5"
                  super.hls-test-utils
              );
              haskell-language-server = lib.pipe super.haskell-language-server [
                (bump "2.15.0.0" "0ef0cd32616bdc3ff9524107b942aba9914b53bb7dcd7bf26c05a62831b3eabf")
                (overrideCabal (drv: {
                  # 2.15 turns off the hlint, stan and stylish-haskell plugins
                  # on GHC 9.14.
                  libraryHaskellDepends =
                    lib.filter (
                      d:
                      !lib.elem (d.pname or "") [
                        "stan"
                        "stylish-haskell"
                        "trial"
                      ]
                    ) drv.libraryHaskellDepends
                    ++ (with self; [
                      foldl
                      table-layout
                      unliftio-core
                    ]);
                  buildDepends = [ ];
                }))
                useBootCabal
              ];

              # Formatters, built with ghc-lib-parser 9.14 and Cabal 3.16.
              fourmolu = useBootCabal (
                overrideCabal {
                  version = "0.20.1.0";
                  sha256 = "345e420b6871852b6148caa26a23991f7646786377276716dd36ae5a6cd842c9";
                  revision = "1";
                  editedCabalFile = "02v4rnbpbi2bp24kl5ffq9nzz0xzn9f4ldgbx3lvvjg16jdsx6p0";
                  patches = [ ];
                } super.fourmolu
              );
              ormolu = useBootCabal (
                bump "0.8.2.0" "9ce1e8a1cefe21c7588b3d7ab3d26f353cf6a63cf68576eee203df144aec04f2" super.ormolu
              );
              ghc-lib-parser = self.ghc-lib-parser_9_14_1_20251220;
              ghc-lib-parser-ex = self.ghc-lib-parser-ex_9_14_2_0;

              # Dependencies HLS 2.15 needs newer than nixpkgs' defaults.
              lsp = self.lsp_2_8_0_0;
              lsp-types = self.lsp-types_2_4_0_0;
              lsp-test = self.lsp-test_0_18_0_0;
              hiedb = self.hiedb_0_8_0_0;
              hie-bios =
                addBuildDepends
                  (with self; [
                    async
                    filelock
                  ])
                  (bump "0.21.0" "2fa861aed7797ba3b6df5651cebcae449ed6058b750302ea94f9ae08b6220bcb" super.hie-bios);
              ghc-exactprint =
                bump "1.14.3.0" "e61a6ef3d23ae34fe7a5a32cbe9abbe15dc3a0a4ad43ab97f85d0d9da9ed7586"
                  super.ghc-exactprint;
              # 0.7 does not compile with containers 0.8.
              algebraic-graphs = self.algebraic-graphs_0_8;
            }
            # Upper bounds too strict for GHC 9.14, as in the allow-newer of
            # HLS's own cabal.project.
            // lib.genAttrs [
              "binary-instances"
              "cabal-install-parsers"
              "constraints-extras"
              "dependent-map"
              "ghc-trace-events"
              "hie-compat"
              "lucid"
              "lukko"
              "string-interpolate"
            ] (name: doJailbreak super.${name})
          );
        });

        # Only what cabal reads, so editing the README or this file does not
        # rebuild the app.
        src = lib.fileset.toSource {
          root = ./.;
          fileset = lib.fileset.unions [
            ./frp-todo.cabal
            ./README.md
            ./src
            ./app
            ./test
          ];
        };

        # The app brings its own fonts and graphics drivers rather than using
        # the host's, so it behaves the same whatever the host has installed.
        #
        # Fonts: SDL2_ttf draws with one font file and has no fallback, so the
        # font has to cover every script itself. Noto Sans CJK covers Latin,
        # Greek and Cyrillic as well as Chinese, Japanese and Korean. Only the
        # two weights the app uses are copied out of the 125 MiB package.
        fonts = pkgs.runCommand "frp-todo-fonts" { } ''
          install -Dm444 -t $out \
            ${pkgs.noto-fonts-cjk-sans-static}/share/fonts/opentype/noto-cjk/NotoSansCJK-Regular.ttc \
            ${pkgs.noto-fonts-cjk-sans-static}/share/fonts/opentype/noto-cjk/NotoSansCJK-Bold.ttc
        '';

        # Graphics: SDL draws through our Mesa instead of the host's
        # /run/opengl-driver, whose drivers may want newer libraries than the
        # ones the app has loaded. Mesa drives AMD and Intel GPUs and renders
        # in software on anything else.
        runtimeEnv = {
          FRP_TODO_FONTS = "${fonts}";
          __EGL_VENDOR_LIBRARY_FILENAMES = "${pkgs.mesa}/share/glvnd/egl_vendor.d/50_mesa.json";
          VK_DRIVER_FILES = "${pkgs.mesa}/share/vulkan/icd.d";
          VK_IMPLICIT_LAYER_PATH = "${pkgs.mesa}/share/vulkan/implicit_layer.d";
          GBM_BACKENDS_PATH = "${pkgs.mesa}/lib/gbm";
          LIBGL_DRIVERS_PATH = "${pkgs.mesa}/lib/dri";
        };

        # Libraries: a host's LD_LIBRARY_PATH would put its own builds of
        # libraries the app loads ahead of ours. A newer alsa-lib from it is
        # enough to keep SDL3 from loading at all.
        runtimeUnset = [ "LD_LIBRARY_PATH" ];

        # `nix build` also runs the test suite.
        frp-todo = pkgs.haskell.lib.compose.overrideCabal (old: {
          buildTools = (old.buildTools or [ ]) ++ [ pkgs.makeBinaryWrapper ];
          postFixup = (old.postFixup or "") + ''
            wrapProgram $out/bin/frp-todo ${
              lib.concatStringsSep " " (
                lib.mapAttrsToList (name: value: "--set ${name} ${lib.escapeShellArg value}") runtimeEnv
                ++ map (name: "--unset ${name}") runtimeUnset
              )
            }
          '';
        }) (haskellPackages.callCabal2nix "frp-todo" src { });

        # Just the program: without the library and its documentation the
        # closure no longer drags in GHC.
        app = pkgs.haskell.lib.compose.justStaticExecutables frp-todo;
      in
      {
        packages.default = app;

        apps.default = {
          type = "app";
          program = "${app}/bin/frp-todo";
        };

        devShells.default = haskellPackages.shellFor {
          # Every Haskell dependency of the package, prebuilt, so cabal never
          # has to reach Hackage.
          packages = _: [ frp-todo ];
          nativeBuildInputs = [
            hlsPackages.haskell-language-server
            # hdb, the Haskell debug adapter, for Zed's debugger. It loads the
            # project with the GHC on PATH, which has to be the one it was
            # built with: this shell's.
            haskellPackages.haskell-debugger
            pkgs.cabal-install
            pkgs.gnumake
            pkgs.nixfmt
          ];
          shellHook = lib.concatStrings (
            lib.mapAttrsToList (name: value: "export ${name}=${lib.escapeShellArg value}\n") runtimeEnv
            ++ map (name: "unset ${name}\n") runtimeUnset
          );
        };

        # Building the app runs its tests.
        checks.default = app;
      }
    );
}
