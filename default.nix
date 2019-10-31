{ stdenv, lib, fetchgit, fetchpatch, makeWrapper, bundlerEnv, defaultGemConfig, ruby_2_6, openssl_1_0_2 }:
let
  ruby = ruby_2_6.override {
    # The mtik gem uses SSL without certificates in a way that modern OpenSSL
    # doesn't like.
    openssl = openssl_1_0_2;
  };
in
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
            url = "https://github.com/astounding/mtik/compare/103aa140dff0917256245b1d4dd878990bd2fcda..1181245d409ae9cac946b01c83ef90b293008ae4.diff";
            sha256 = "134jiks2bivcw1jpra6klz0ziip78rfizcv1nhid4x3fl193qizi";
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
