{ stdenv, lib, fetchFromGitHub, cmake, libuv, libmicrohttpd, openssl
, opencl-headers, ocl-icd, hwloc, cudatoolkit
, devDonationLevel ? "0.0"
, cudaSupport ? false
, openclSupport ? false
, amdgpu-pro, proot }:
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

  nativeBuildInputs = [ cmake ];
  buildInputs = [ libmicrohttpd openssl hwloc ]
    ++ lib.optional cudaSupport cudatoolkit
    ++ lib.optionals openclSupport [ opencl-headers ocl-icd ];

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
  #postInstall =
  #    ''
  #    echo '#!/bin/sh' >> $out/bin/xmr-stak.sh
  #    echo 'export PROOT_NO_SECCOMP=1' >> $out/bin/xmr-stak.sh
  #    echo "${proot}/bin/proot -r / -b ${amdgpu-pro}/etc/OpenCL:/etc/OpenCL -b ${libdrm}/share/libdrm:/opt/amdgpu-pro/share/libdrm -b ${amdgpu-pro}/etc/amd:/etc/amd $out/bin/xmr-stak" >> $out/bin/xmr-stak.sh
  #    chmod 755 $out/bin/xmr-stak.sh
  #  '';
}
