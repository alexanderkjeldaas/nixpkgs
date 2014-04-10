{ stdenv, fetchurl, kernelPatches ? [], ... } @ args:

let
  patches = kernelPatches ++
   [{ name = "remove-driver-compilation-dates";
      patch = ./linux-3-10-35-no-dates.patch;
    }];
in

import ./generic.nix (args // rec {
  version = "3.10.36";
  extraMeta.branch = "3.10";

  src = fetchurl {
    url = "mirror://kernel/linux/kernel/v3.x/linux-${version}.tar.xz";
    sha256 = "1bx94v829qvv5r9h6cj5ddyj5n6qddy8bppnl8minjnqsv5l0vnr";
  };

  kernelPatches = patches;

  features.iwlwifi = true;
  features.efiBootStub = true;
  features.needsCifsUtils = true;
  features.canDisableNetfilterConntrackHelpers = true;
  features.netfilterRPFilter = true;
})
