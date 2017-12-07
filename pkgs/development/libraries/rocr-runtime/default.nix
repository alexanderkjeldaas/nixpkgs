{ stdenv, fetchgit, libelf, roct, cmake, pkgconfig, python
}:

stdenv.mkDerivation rec {
  name    = "rocr-runtime-${version}";
  version = "master";

  # use git version since we need submodules
  src = fetchgit {
    url    = "https://github.com/RadeonOpenCompute/ROCR-Runtime.git";
    rev    = "7284822462ba776c89bc15a42bf70860f3ce2544";
    sha256 = "1z6qvrnj0dvrsmbgl3kwy2ldz009ymq7vm93w6djn8xd6rld4gxq";
    fetchSubmodules = true;
  };


#  phases = [ "unpackPhase" "installPhase"];


  buildInputs =
    [ cmake pkgconfig roct libelf python
    ];

  prePatch = "cd src;";


  enableParallelBuilding = true;
  # the cmake package does not handle absolute CMAKE_INSTALL_INCLUDEDIR correctly
  # (setting it to an absolute path causes include files to go to $out/$out/include,
  #  because the absolute path is interpreted with root at $out).
  cmakeFlags = "-DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_FLAGS=-I${roct}/include:${libelf}/include";


  meta = {
    description = "ROC Runtime source code based on the HSA Runtime but modified to support AMD/ATI discrete GPUs.";
    homepage    = "https://github.com/RadeonOpenCompute/ROCR-Runtime";
    license     = "AMD";
    platforms   = [ "x86_64-linux" ];
    maintainers = [ stdenv.lib.maintainers.ak ];
  };
}
