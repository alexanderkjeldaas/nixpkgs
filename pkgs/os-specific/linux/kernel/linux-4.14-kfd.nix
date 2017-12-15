{ stdenv, hostPlatform, fetchFromGitHub, perl, buildLinux, ... } @ args:

let
  ver = "4.14.0";
  rc="-rc7";
  revision = "rc7-roc";
in
import ./generic.nix (args // rec {
  version = "${ver}-${revision}";
  modDirVersion = "${ver}${rc}";
  extraMeta.branch = "4.14";

  src = fetchFromGitHub {
    owner = "RadeonOpenCompute";
    repo = "ROCK-Kernel-Driver";
    # url = "https://github.com/RadeonOpenCompute/ROCK-Kernel-Driver.git";
    rev = "fkxamd/drm-next-wip";
    sha256 = "1k4vlszlqmybd9w0qnj3pq4vl43azlpc61lwf6aw4c0ipxfj8fmz";
  };
} // (args.argsOverride or {}))
