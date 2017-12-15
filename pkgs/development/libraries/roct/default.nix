{ stdenv, fetchgit, fetchurl, cmake, pkgconfig, boost, libunwind, libmemcached
, pcre, libevent, gd, curl, libxml2, icu, flex, bison, openssl, zlib, php
, expat, libcap, oniguruma, libdwarf, libmcrypt, tbb, gperftools, glog, libkrb5
, bzip2, openldap, readline, libelf, uwimap, binutils, cyrus_sasl, pam, libpng
, libxslt, freetype, gdb, git, perl, mariadb, gmp, libyaml, libedit
, libvpx, imagemagick, fribidi, gperf, which, ocamlPackages
, pciutils
}:

stdenv.mkDerivation rec {
  name    = "roct-${version}";
  version = "roc-1.6.x";

  # use git version since we need submodules
  src = fetchgit {
    url    = "https://github.com/RadeonOpenCompute/ROCT-Thunk-Interface.git";
    rev    = "25a9bc2825eaf1b7388085bdd95636b87b266b60";
    sha256 = "1s4hdygrjl17qnph5p64vckva8dchv1fpxbc3yib6kqckvvxj520";
    fetchSubmodules = true;
  };

  buildInputs =
    [ cmake pkgconfig libunwind
    ];

  patches = [
    ./001-fixes.patch
  ];

  enableParallelBuilding = true;
#  dontUseCmakeBuildDir = true;
  NIX_LDFLAGS = "-L${pciutils}/lib";

  # work around broken build system
  NIX_CFLAGS_COMPILE = "-I${pciutils}/include";

  # the cmake package does not handle absolute CMAKE_INSTALL_INCLUDEDIR correctly
  # (setting it to an absolute path causes include files to go to $out/$out/include,
  #  because the absolute path is interpreted with root at $out).
  cmakeFlags = "-DCMAKE_BUILD_TYPE=Release -DCMAKE_CFLAGS=-I${pciutils}/include";

  postInstall = ''
    mv $out/lib/libhsakmt.so $out/lib/libhsakmt.so.1
    ln -s libhsakmt.so.1 $out/lib/libhsakmt.so
  '';

  meta = {
    description = "HCC : An open source C++ compiler for heterogeneous devices";
    homepage    = "https://github.com/RadeonOpenCompute/hcc/wiki";
    license     = "NCSA";
    platforms   = [ "x86_64-linux" ];
    maintainers = [ stdenv.lib.maintainers.ak ];
  };
}
