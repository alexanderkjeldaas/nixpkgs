{ stdenv, fetchgit, libelf, roct, cmake, pkgconfig, python
, fetchRepoProject, git
, rocr-runtime
, cacert
, mesa
, x11
}:

stdenv.mkDerivation rec {
  name    = "rocm-opencl-runtime-${version}";
  version = "master";

  # use git version since we need submodules
  src = fetchRepoProject {
    name = "ROCm-OpenCL-Runtime";
#    url    = "https://github.com/RadeonOpenCompute/ROCm-OpenCL-Runtime.git";
#    rev    = "roc-1.7.x"; #5c209b3df0d7ebeedcf803471ab22f36b49b1cee";
    rev    = "master"; #5c209b3df0d7ebeedcf803471ab22f36b49b1cee";
    manifest    = "https://github.com/RadeonOpenCompute/ROCm-OpenCL-Runtime.git";
    manifestName = "opencl.xml";
#    manifest = "opencl.xml";
#    manifest = "https://raw.githubusercontent.com/RadeonOpenCompute/ROCm-OpenCL-Runtime/roc-1.6.x/opencl.xml/"
    sha256 = "1j0cqsqm9lyi4lyljddridp8x6iarhcj3zydfdlzlf9qvinvbda9";
  };

#  phases = [ "unpackPhase" "installPhase"];


  buildInputs =
    [ cmake pkgconfig roct libelf python git mesa x11 rocr-runtime
    ];

  patches = [ ./01-find-hsakmt-library.patch ];

  prePatch = "cd opencl;";
  GIT_SSL_CAINFO="/etc/ssl/certs/ca-certificates.crt";
  SSL_CERT_FILE="/etc/ssl/certs/ca-certificates.crt";


  enableParallelBuilding = true;
  # the cmake package does not handle absolute CMAKE_INSTALL_INCLUDEDIR correctly
  # (setting it to an absolute path causes include files to go to $out/$out/include,
  #  because the absolute path is interpreted with root at $out).
  ROCR_LIBRARY="-lhsa-runtime64";
  HSAKMT_LIBRARY="-lhsakmt";
  #cmakeFlags = "-DCMAKE_BUILD_TYPE=Release -DROCR_INCLUDE_DIR=${rocr-runtime}/include/hsa -DROCR_LIBRARY=${rocr-runtime}/lib"; # -DCMAKE_CXX_FLAGS=-I${roct}/include:${libelf}/include";
  cmakeFlags = "-DCMAKE_BUILD_TYPE=Release -DROCR_INCLUDE_DIR=${rocr-runtime}/include/hsa"; # -DCMAKE_CXX_FLAGS=-I${roct}/include:${libelf}/include";


  meta = {
    description = "ROCm OpenCL™ Compatible Runtime.";
    homepage    = "https://github.com/RadeonOpenCompute/ROCm-OpenCL-Runtime";
    license     = "AMD";
    platforms   = [ "x86_64-linux" ];
    maintainers = [ stdenv.lib.maintainers.ak ];
  };
}
