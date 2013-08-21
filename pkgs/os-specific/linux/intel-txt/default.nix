{ stdenv }:

let version = "67";
stdenv.mkDerivation {
  name = "intel-txt-${version}"

  sourceRoot = ".";

  installPhase = ''
    ensureDir $out/boot
    cp -r 3rd_gen_i5_i7_67 "$out/boot/"
  '';

  meta = {
    homepage = http://software.intel.com/en-us/articles/intel-trusted-execution-technology;
    description = "Intel Trusted Execution Technology";
  };
}
