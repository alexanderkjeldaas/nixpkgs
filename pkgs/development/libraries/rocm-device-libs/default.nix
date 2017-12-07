{ stdenv, fetchgit, cmake, pkgconfig
, python, zlib, ncurses
}:


stdenv.mkDerivation rec {
  name    = "rocm-device-libs-${version}";
  version = "roc-1.6.x";

  llvm = stdenv.mkDerivation rec {
    name = "roct-llvm";
    
    src = fetchgit {
      url    = "https://github.com/RadeonOpenCompute/llvm.git";
      rev    = "0816ab310423f59b9a7ba050a7f6748541ea17ec"; # "amd-common";
      sha256 = "1p85nqcfl0839z6xy226sldxfl02indq5fjq59461g2j08pjwf9h";
      fetchSubmodules = true;
    };

    lld = fetchgit {
      url    = "https://github.com/RadeonOpenCompute/lld.git";
      rev    = "0b421068c2eb848a62fd2f241291c9098333aeeb";  # "amd-common";
      sha256 = "108akwp1d1z16rcrfpvqa3k0366shrj262mn0j16x10aqgfsansy";
      fetchSubmodules = true;
    };
  
    clang = fetchgit {
      url    = "https://github.com/RadeonOpenCompute/clang.git";
      rev    = "5b6ff13096fa9cd51c53af347c2dcadc849bbbaf"; #"amd-common";
      sha256 = "0ziz05am6xmjdz6qa7sgd4wikr5wzr1psr9040r9k88hdvvakmcc";
      fetchSubmodules = true;
    };

    prePatch = ''
      chmod 777 tools
      cp -r ${lld}  tools/lld
      cp -r ${clang}  tools/clang
      chmod 777 -R .
    '';

    parallelBuild = true;

    buildInputs = [ cmake pkgconfig python zlib ncurses ];


    enableParallelBuilding = true;
    cmakeFlags = "-DCMAKE_BUILD_TYPE=Release -DLLVM_TARGETS_TO_BUILD='AMDGPU;X86'";
  };


  src = fetchgit {
    url    = "https://github.com/RadeonOpenCompute/ROCm-Device-Libs.git";
    rev    = "e9543f3311e12abc0f1dd82896d5cda41c95c7aa";
    sha256 = "0vqlf8xh9bnb5nbwak4yj0x42kgdhbk00ra8045xb6sdfi3psq7h";
    fetchSubmodules = true;
  };



  buildInputs =
    [ cmake pkgconfig python
    ];


  enableParallelBuilding = true;
#  dontUseCmakeBuildDir = true;
#  NIX_LDFLAGS = "-L${pciutils}/lib";

  # work around broken build system
#  NIX_CFLAGS_COMPILE = "-I${pciutils}/include";

  # the cmake package does not handle absolute CMAKE_INSTALL_INCLUDEDIR correctly
  # (setting it to an absolute path causes include files to go to $out/$out/include,
  #  because the absolute path is interpreted with root at $out).
  cmakeFlags = "-DCMAKE_BUILD_TYPE=Release -DLLVM_DIR=${llvm}";
  CC= "${llvm}/bin/clang";

  meta = {
    description = "HCC : An open source C++ compiler for heterogeneous devices";
    homepage    = "https://github.com/RadeonOpenCompute/hcc/wiki";
    license     = "NCSA";
    platforms   = [ "x86_64-linux" ];
    maintainers = [ stdenv.lib.maintainers.ak ];
  };
}
