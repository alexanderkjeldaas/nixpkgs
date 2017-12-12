{ stdenv
, fetchgit
, git
, python3
}:

with stdenv.lib;


stdenv.mkDerivation rec {

  name = "roc-smi";

  src = fetchgit {
    url = "https://github.com/RadeonOpenCompute/ROC-smi.git";
    rev = "25d3992d7463376866d0599f4eba9d440d007989";
    sha256 = "0k58pa862anvxl2j3grz0c566a42kb21l8xyrmmvjq9fs1hnw77y";
  };


  installPhase = ''
    mkdir -p $out/bin
    cp rocm-smi $out/bin
  '';

  buildInputs = [
    git
    python3
  ];

  enableParallelBuilding = true;

  meta = with stdenv.lib; {
    description = "ROC System Management Interface";
    homepage =  https://github.com/RadeonOpenCompute/ROC-smi ;
    license = licenses.mit;
    platforms = platforms.linux;
    maintainers = with maintainers; [ ak ];
  };
}
