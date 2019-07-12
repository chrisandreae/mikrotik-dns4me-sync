{ stdenv, lib, fetchgit, fetchpatch, makeWrapper, bundlerEnv, defaultGemConfig, ruby }:

stdenv.mkDerivation rec {
  name = "mikrotik-dns4me-sync";
  version = "0.1.0";

  nativeBuildInputs = [makeWrapper];

  src = ./.;

  gems = bundlerEnv {
    name = "mikrotik-dns4me-sync-deps";
    inherit ruby;
    gemdir = ./.;

    gemConfig = defaultGemConfig // {
      # 4.0.3 is ancient: apply patches from github to bring it up to date,
      # without letting Bundler know it's a git dependency.
      mtik = attrs: {
        dontBuild = false;
        patches = (attrs.patches or []) ++ [
          (fetchpatch {
            url = "https://github.com/astounding/mtik/compare/103aa140dff0917256245b1d4dd878990bd2fcda..92f6f7d341c4576b4f41c58db3378689343d4736.diff";
            sha256 = "0x6zkv6lwfhvnk9kkmjd66n677q2chms18zjql6w7jw1z71w8z7p";
          })
        ];
      };
    };
  };

  installPhase = ''
    mkdir -p $out/bin
    install -m 0755 ./dns4me.rb $out/bin/mikrotik-dns4me-sync

    wrapProgram $out/bin/mikrotik-dns4me-sync \
      --prefix PATH : ${lib.makeBinPath [gems.wrappedRuby]}
  '';
}
