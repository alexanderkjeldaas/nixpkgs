{ stdenv, fetchgit, libelf, roct, cmake, pkgconfig, python
, fetchRepoProject
}:

stdenv.mkDerivation rec {
  name    = "rocm-opencl-runtime-${version}";
  version = "master";

  # use git version since we need submodules
  src = fetchRepoProject {
    name = "ROCm-OpenCL-Runtime";
#    url    = "https://github.com/RadeonOpenCompute/ROCm-OpenCL-Runtime.git";
    rev    = "5c209b3df0d7ebeedcf803471ab22f36b49b1cee";
    manifest    = "https://github.com/RadeonOpenCompute/ROCm-OpenCL-Runtime.git";
    manifestName = "opencl.xml";
#    manifest = "opencl.xml";
#    manifest = "https://raw.githubusercontent.com/RadeonOpenCompute/ROCm-OpenCL-Runtime/roc-1.6.x/opencl.xml/"
    sha256 = "1y1y3asx92nnzz9pcp46gwf3a3iq9xs80x812aaraxv9mg1nil4p";
  };

#  phases = [ "unpackPhase" "installPhase"];


  buildInputs =
    [ cmake pkgconfig roct libelf python
    ];

#  prePatch = "cd src;";


  enableParallelBuilding = true;
  # the cmake package does not handle absolute CMAKE_INSTALL_INCLUDEDIR correctly
  # (setting it to an absolute path causes include files to go to $out/$out/include,
  #  because the absolute path is interpreted with root at $out).
  cmakeFlags = "-DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_FLAGS=-I${roct}/include:${libelf}/include";


  meta = {
    description = "ROCm OpenCL™ Compatible Runtime.";
    homepage    = "https://github.com/RadeonOpenCompute/ROCm-OpenCL-Runtime";
    license     = "AMD";
    platforms   = [ "x86_64-linux" ];
    maintainers = [ stdenv.lib.maintainers.ak ];
  };
}
