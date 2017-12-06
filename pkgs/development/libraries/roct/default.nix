{ stdenv, fetchgit, fetchurl, cmake, pkgconfig, boost, libunwind, libmemcached
, pcre, libevent, gd, curl, libxml2, icu, flex, bison, openssl, zlib, php
, expat, libcap, oniguruma, libdwarf, libmcrypt, tbb, gperftools, glog, libkrb5
, bzip2, openldap, readline, libelf, uwimap, binutils, cyrus_sasl, pam, libpng
, libxslt, freetype, gdb, git, perl, mariadb, gmp, libyaml, libedit
, libvpx, imagemagick, fribidi, gperf, which, ocamlPackages
, linux_4_11_kfd
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

#  patches = [
#    ./flexible-array-members-gcc6.patch
#    (fetchurl {
#      url = https://github.com/facebook/hhvm/commit/b506902af2b7c53de6d6c92491c2086472292004.patch;
#      sha256 = "1br7diczqks6b1xjrdsac599fc62m9l17gcx7dvkc0qj54lq7ys4";
#    })
#  ];

  enableParallelBuilding = true;
#  dontUseCmakeBuildDir = true;
#  NIX_LDFLAGS = "-lpam -L${pam}/lib";

  # work around broken build system
  NIX_CFLAGS_COMPILE = "-I${linux_4_11_kfd.src}/drivers";

  # the cmake package does not handle absolute CMAKE_INSTALL_INCLUDEDIR correctly
  # (setting it to an absolute path causes include files to go to $out/$out/include,
  #  because the absolute path is interpreted with root at $out).
  cmakeFlags = "-DCMAKE_BUILD_TYPE=Release";

#  prePatch = ''
#    substituteInPlace ./configure \
#      --replace "/usr/bin/env bash" ${stdenv.shell}
#    substituteInPlace ./third-party/ocaml/CMakeLists.txt \
#      --replace "/bin/bash" ${stdenv.shell}
#    perl -pi -e 's/([ \t(])(isnan|isinf)\(/$1std::$2(/g' \
#      hphp/runtime/base/*.cpp \
#      hphp/runtime/ext/std/*.cpp \
#      hphp/runtime/ext_zend_compat/php-src/main/*.cpp \
#      hphp/runtime/ext_zend_compat/php-src/main/*.h
#    patchShebangs .
#  '';

  meta = {
    description = "HCC : An open source C++ compiler for heterogeneous devices";
    homepage    = "https://github.com/RadeonOpenCompute/hcc/wiki";
    license     = "NCSA";
    platforms   = [ "x86_64-linux" ];
    maintainers = [ stdenv.lib.maintainers.ak ];
  };
}
