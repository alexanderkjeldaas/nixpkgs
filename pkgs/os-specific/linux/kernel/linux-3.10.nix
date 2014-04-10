{ stdenv, fetchurl, kernelPatches ? [], ... } @ args:

let
  patches = kernelPatches ++
   [{ name = "remove-driver-compilation-dates";
      patch = ./linux-3-10-35-no-dates.patch;
    }];
in

import ./generic.nix (args // rec {
  version = "3.10.37";
  extraMeta.branch = "3.10";

  src = fetchurl {
    url = "mirror://kernel/linux/kernel/v3.x/linux-${version}.tar.xz";
    sha256 = "0dh52s9jdvgs75dai5zqlx52xahdrscp048yd96x699hcl3g99d7";
  };

  kernelPatches = patches;

  features.iwlwifi = true;
  features.efiBootStub = true;
  features.needsCifsUtils = true;
  features.canDisableNetfilterConntrackHelpers = true;
  features.netfilterRPFilter = true;
})
