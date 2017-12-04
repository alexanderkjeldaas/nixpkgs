{ stdenv, fetchgit, cmake, pkgconfig, amdgpu-pro, libmicrohttpd, openssl, hwloc, proot, libdrm }:
stdenv.mkDerivation rec {
  name = "xmr-stak";
  buildInputs = [ openssl libmicrohttpd amdgpu-pro hwloc ];
  src = fetchgit {
    url = "https://github.com/fireice-uk/xmr-stak.git";
    rev = "79154f76defa627255891888f4dd62453194fc2c";
    sha256 = "06sli7najynbih147sblcwhkd36f2wzccr6f38sz5g500dl267k0";
  };
  MICROHTTPD_ROOT=libmicrohttpd;
  cmakeFlags = [
    "-DCUDA_ENABLE=OFF"
#    "-DOpenCL_LIBRARY=${amdgpu-pro}/lib"
#    "-DOpenCL_INCLUDE_DIR=${amdgpu-pro}/include"
#    "-DMTHD_INCLUDE_DIR=${libmicrohttpd}/include"
#    "-DOPENSSL_CRYPTO_LIBRARY=${openssl}/lib"
#    "-DOPENSSL_CRYPTO_LIBRARY=${openssl}/include"
  ];
  #NIX_LDFLAGS = "-lm -lpthread";
  nativeBuildInputs = [ cmake pkgconfig ];
  postInstall =
      ''
      echo '#!/bin/sh' >> $out/bin/xmr-stak.sh
      echo 'export PROOT_NO_SECCOMP=1' >> $out/bin/xmr-stak.sh
      echo "${proot}/bin/proot -r / -b ${amdgpu-pro}/etc/OpenCL:/etc/OpenCL -b ${libdrm}/share/libdrm:/opt/amdgpu-pro/share/libdrm -b ${amdgpu-pro}/etc/amd:/etc/amd $out/bin/xmr-stak" >> $out/bin/xmr-stak.sh
      chmod 755 $out/bin/xmr-stak.sh
    '';
}
