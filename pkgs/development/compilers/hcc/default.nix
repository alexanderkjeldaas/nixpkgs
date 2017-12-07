{ stdenv, fetchgit, fetchurl, cmake, pkgconfig, boost, libunwind, libmemcached
, roct, hsa-runtime-amd, rocm-device-libs
, rocr-runtime
, python
}:

stdenv.mkDerivation rec {
  name    = "hcc-${version}";
  version = "2017-12-06";

  # use git version since we need submodules
  src = fetchgit {
    url    = "https://github.com/RadeonOpenCompute/hcc.git";
    rev    = "5ce213aca190c51368048f88622aaa27cf5a0d62";
    sha256 = "04zwyk1zxgkflndj60ligiyxx1hxj50mzi7h7j6spavidx24lq8d";
    fetchSubmodules = true;
  };

  buildInputs =
    [ cmake pkgconfig libunwind roct hsa-runtime-amd rocm-device-libs
      python
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

#  NIX_CFLAGS_COMIPLE = "-I${linux_4_11_kfd.source}/drivers";
  # work around broken build system
  NIX_CFLAGS_COMPILE = "-I${roct}/include:${libunwind.src}/include:${rocr-runtime}/include";

  # the cmake package does not handle absolute CMAKE_INSTALL_INCLUDEDIR correctly
  # (setting it to an absolute path causes include files to go to $out/$out/include,
  #  because the absolute path is interpreted with root at $out).
  cmakeFlags = "-DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_FLAGS=-I${roct}/include:${libunwind.src}/include:${rocr-runtime}/include -DHSA_HEADER_DIR=${rocr-runtime}/include -DHSA_LIBRARY_DIR=${rocr-runtime}/lib";

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
