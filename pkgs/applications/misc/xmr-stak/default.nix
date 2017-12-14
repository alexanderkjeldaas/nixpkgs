{ stdenv, lib, fetchFromGitHub, cmake, libuv, libmicrohttpd, openssl
, opencl-headers, ocl-icd, hwloc, cudatoolkit
, devDonationLevel ? "0.0"
, cudaSupport ? false
, openclSupport ? false
, amdSupport ? false
, amdgpu-pro, proot
, rocm-opencl-runtime
, makeWrapper
}:

stdenv.mkDerivation rec {
  name = "xmr-stak-${version}";
  version = "2.1.0";

  src = fetchFromGitHub {
    owner = "fireice-uk";
    repo = "xmr-stak";
    rev = "v${version}";
    sha256 = "0ijhimsd03v1psj7pyj70z4rrgfvphpf69y7g72p06010xq1agp8";
  };

  NIX_CFLAGS_COMPILE = "-O3";

  cmakeFlags = lib.optional (!cudaSupport) "-DCUDA_ENABLE=OFF"
    ++ lib.optional (!openclSupport) "-DOpenCL_ENABLE=OFF";
    ++ lib.optional amdSupport " -DOpenCL_LIBRARY=${rocm-opencl-runtime}/lib -DOpenCL_INCLUDE_DIR=${rocm-opencl-runtime}/include/opencl2.2";

  nativeBuildInputs = [ cmake rocm-opencl-runtime ];
  buildInputs = [ libmicrohttpd openssl hwloc makeWrapper ]
    ++ lib.optional cudaSupport cudatoolkit
    ++ lib.optionals openclSupport [ opencl-headers ocl-icd ]
    ++ lib.optional amdSupport rocm-opencl-runtime;


  postPatch = ''
    substituteInPlace xmrstak/donate-level.hpp \
      --replace 'fDevDonationLevel = 2.0' 'fDevDonationLevel = ${devDonationLevel}'
  '';

  meta = with lib; {
    description = "Unified All-in-one Monero miner";
    homepage = "https://github.com/fireice-uk/xmr-stak";
    license = licenses.gpl3Plus;
    maintainers = with maintainers; [ fpletz ];
  };

  postInstall = ''

    mv $out/bin/xmr-stak $out/bin/xmr-stak.bin
      
    makeWrapper $out/bin/xmr-stak.bin $out/bin/xmr-stak --set LD_LIBRARY_PATH $out/bin:${rocm-opencl-runtime}/lib --set LD_PRELOAD libOpenCL.so.1.2
  '';
  #postInstall =
  #    ''
  #    echo '#!/bin/sh' >> $out/bin/xmr-stak.sh
  #    echo 'export PROOT_NO_SECCOMP=1' >> $out/bin/xmr-stak.sh
  #    echo "${proot}/bin/proot -r / -b ${amdgpu-pro}/etc/OpenCL:/etc/OpenCL -b ${libdrm}/share/libdrm:/opt/amdgpu-pro/share/libdrm -b ${amdgpu-pro}/etc/amd:/etc/amd $out/bin/xmr-stak" >> $out/bin/xmr-stak.sh
  #    chmod 755 $out/bin/xmr-stak.sh
  #  '';
}
