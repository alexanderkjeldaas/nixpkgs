{stdenv, fetchurl, autoconf, automake, trousers, openssl, zlib}:

stdenv.mkDerivation {
  name = "tboot-1.7.4";

  src = fetchurl {
    url = https://sourceforge.net/projects/tboot/files/tboot/tboot-1.7.4.tar.gz;
    sha256 = "0ix970w27nzgh2rcz0xwxwdp5rlw1n2705nyd9nlj44rspfni327";
  };

  buildInputs = [ trousers openssl zlib ];

  configurePhase = ''
    for a in lcptools utils tb_polgen; do
      substituteInPlace $a/Makefile --replace /usr/sbin /sbin
    done
    substituteInPlace docs/Makefile --replace /usr/share /share
  '';
  installFlags = "DESTDIR=$(out)";
}
