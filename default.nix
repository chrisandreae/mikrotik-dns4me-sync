{ stdenv, lib, fetchgit, fetchpatch, makeWrapper, bundlerEnv, defaultGemConfig, ruby_2_7, openssl_1_0_2 }:
let
  ruby = ruby_2_7.override {
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
  };

  installPhase = ''
    mkdir -p $out/bin
    install -m 0755 ./dns4me.rb $out/bin/mikrotik-dns4me-sync

    wrapProgram $out/bin/mikrotik-dns4me-sync \
      --prefix PATH : ${lib.makeBinPath [gems.wrappedRuby]}
  '';
}
