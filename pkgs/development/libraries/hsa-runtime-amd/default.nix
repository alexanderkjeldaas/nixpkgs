{ stdenv, fetchgit,
}:

stdenv.mkDerivation rec {
  name    = "hsa-runtime-amd-${version}";
  version = "master";

  # use git version since we need submodules
  src = fetchgit {
    url    = "https://github.com/HSAFoundation/HSA-Runtime-AMD.git";
    rev    = "0579a4f41cc21a76eff8f1050833ef1602290fcc";
    sha256 = "1dgm71bl8x3daa32nvjm099wyl1xzq32f1z4p3fzshl6vaxl5d48";
    fetchSubmodules = true;
  };


  phases = [ "unpackPhase" "installPhase"];


  installPhase = ''
     mkdir $out
     cp -a * $out
  '';


  meta = {
    description = "AMD Heterogeneous System Architecture HSA - HSA Runtime release for AMD Kaveri & Carrizo APUs";
    homepage    = "https://github.com/HSAFoundation/HSA-Runtime-AMD";
    license     = "AMD";
    platforms   = [ "x86_64-linux" ];
    maintainers = [ stdenv.lib.maintainers.ak ];
  };
}
