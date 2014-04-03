{ config, pkgs, ... }:

with pkgs.lib;

let
  luks = config.boot.initrd.luks;

  openCommand = { name, device, keyFile, keyFileSize, allowDiscards, yubikey, tpm, ... }: ''
    # Wait for luksRoot to appear, e.g. if on a usb drive.
    # XXX: copied and adapted from stage-1-init.sh - should be
    # available as a function.
    if ! test -e ${device}; then
        echo -n "waiting 10 seconds for device ${device} to appear..."
        for try in $(seq 10); do
            sleep 1
            if test -e ${device}; then break; fi
            echo -n .
        done
        echo "ok"
    fi

    ${optionalString (keyFile != null) ''
    if ! test -e ${keyFile}; then
        echo -n "waiting 10 seconds for key file ${keyFile} to appear..."
        for try in $(seq 10); do
            sleep 1
            if test -e ${keyFile}; then break; fi
            echo -n .
        done
        echo "ok"
    fi
    ''}

    open_normally() {
        cryptsetup luksOpen ${device} ${name} ${optionalString allowDiscards "--allow-discards"} \
          ${optionalString (keyFile != null) "--key-file=${keyFile} "} \
          ${optionalString (keyFileSize != null) "--keyfile-size=${toString keyFileSize} "}
    }

    ${optionalString (luks.tpmSupport) ''
    
    tpm_luks_open() {
        if [ ! -f ${tpm.storage.path} ]; then
            echo "Warning: Could not find sealed key file at ${tpm.storage.path}"
            return 1
        elif ! tpm_unsealdata -z ${tpm.storage.path} | cryptsetup luksOpen ${device} \
                   ${name} ${optionalString allowDiscards "--allow-discards"} --key-file=-; then
            echo "Warning: Could not unseal the LUKS key at ${tpm.storage.path}"
            return 1
        else
            return 0
        fi
    }

    # intersperse second argument between words of first argument
    intersperse() {
        # trim and then intersperse
        echo $1 | sed -e 's/^ *\(.*[^ ]\).*$/\1/g' -e "s/  */ $2 /g"
    }

    tpm_maybe_format() {
        local pcrs;
        if [ -f ${tpm.storage.path} ]; then
            echo "Error: sealed key file exists at ${tpm.storage.path}"
            return 1
        fi
        if cryptsetup isLuks ${device}; then
            echo "Error: device is already a LUKS device"
            echo "wipe the header before proceeding ${device}"
            return 1
        fi
        if ! touch ${tpm.storage.path}; then
            echo "Error: cannot write to sealed key file at ${tpm.storage.path}"
            return 1
        fi
        rm -f ${tpm.storage.path}
        pcrs=$(intersperse ${tpm.sealPcrs} '-p')
        if [ -z "$pcrs" ]; then
            echo "Error: Cannot seal to an empty list of PCRs!"
            return 1
        fi
        # Sealing and unsealing isn't terribly efficient, but we're only doing 
        # it once, and then we don't have to keep the key in this process
        dd if=/dev/random bs=1 count=32 | tpm_sealdata -z ${tpm.storage.path} ${tpm.sealPcrs}
        tpm_unsealdata -z -i ${tpm.storage.path} |
            cryptsetup luksFormat ${device} --use-random --batch-mode
    }

    # We have just created a LUKS partition, now install nixos on it.
    tpm_nixos_install() {
        local tmp_mnt
        tmp_mnt=/tmp-mnt-$RANDOM
        mkdir -p $tmp_mnt
        ( cd $tmp_mnt
          cp -arv / 
          # We're cheating and starting this a bit early so we can mount and populate.
          lvm vgchange -ay
          mount 
        
    }
            
    tpm_open() {
        local need_install=false
        mkdir -p ${tpm.storage.mountPoint}
        mount ${toString tpm.storage.device} ${tpm.storage.mountPoint}
        # We need tcsd in order to unseal. It should be later killed
        # and restarted in a proper environment.
	if ! tcsd; then
            echo "Error: Trusted Computing resource daemon (tcsd) could not be started"
            umount ${tpm.storage.mountPoint}
            return 1
        fi
    ${optionalString (tpm.autoInstall) ''
        if tpm_maybe_format; then
            need_install=true
        fi
    ''}
        if ! tpm_luks_open; then
            echo "Error: Could not open LUKS device ${device} ${name}"
            umount ${tpm.storage.mountPoint}
            return 1
        fi
        umount ${tpm.storage.mountPoint}
    ${optionalString (tpm.autoInstall) ''
        if $need_install; then
            tpm_nixos_install
        fi
    ''}

    
    }
    ''}

    ${optionalString (luks.yubikeySupport && (yubikey != null)) ''

    rbtohex() {
        ( od -An -vtx1 | tr -d ' \n' )
    }

    hextorb() {
        ( tr '[:lower:]' '[:upper:]' | sed -e 's/\([0-9A-F]\{2\}\)/\\\\\\x\1/gI' | xargs printf )
    }

    open_yubikey() {

        # Make all of these local to this function
        # to prevent their values being leaked
        local salt
        local iterations
        local k_user
        local challenge
        local response
        local k_luks
        local opened
        local new_salt
        local new_iterations
        local new_challenge
        local new_response
        local new_k_luks

        mkdir -p ${yubikey.storage.mountPoint}
        mount -t ${yubikey.storage.fsType} ${toString yubikey.storage.device} ${yubikey.storage.mountPoint}

        salt="$(cat ${yubikey.storage.mountPoint}${yubikey.storage.path} | sed -n 1p | tr -d '\n')"
        iterations="$(cat ${yubikey.storage.mountPoint}${yubikey.storage.path} | sed -n 2p | tr -d '\n')"
        challenge="$(echo -n $salt | openssl-wrap dgst -binary -sha512 | rbtohex)"
        response="$(ykchalresp -${toString yubikey.slot} -x $challenge 2>/dev/null)"

        for try in $(seq 3); do

            ${optionalString yubikey.twoFactor ''
            echo -n "Enter two-factor passphrase: "
            read -s k_user
            echo
            ''}

            if [ ! -z "$k_user" ]; then
                k_luks="$(echo -n $k_user | pbkdf2-sha512 ${toString yubikey.keyLength} $iterations $response | rbtohex)"
            else
                k_luks="$(echo | pbkdf2-sha512 ${toString yubikey.keyLength} $iterations $response | rbtohex)"
            fi

            echo -n "$k_luks" | hextorb | cryptsetup luksOpen ${device} ${name} ${optionalString allowDiscards "--allow-discards"} --key-file=-

            if [ $? == "0" ]; then
                opened=true
                break
            else
                opened=false
                echo "Authentication failed!"
            fi
        done

        if [ "$opened" == false ]; then
            umount ${yubikey.storage.mountPoint}
            echo "Maximum authentication errors reached"
            exit 1
        fi

        echo -n "Gathering entropy for new salt (please enter random keys to generate entropy if this blocks for long)..."
        for i in $(seq ${toString yubikey.saltLength}); do
            byte="$(dd if=/dev/random bs=1 count=1 2>/dev/null | rbtohex)";
            new_salt="$new_salt$byte";
            echo -n .
        done;
        echo "ok"

        new_iterations="$iterations"
        ${optionalString (yubikey.iterationStep > 0) ''
        new_iterations="$(($new_iterations + ${toString yubikey.iterationStep}))"
        ''}

        new_challenge="$(echo -n $new_salt | openssl-wrap dgst -binary -sha512 | rbtohex)"

        new_response="$(ykchalresp -${toString yubikey.slot} -x $new_challenge 2>/dev/null)"

        if [ ! -z "$k_user" ]; then
            new_k_luks="$(echo -n $k_user | pbkdf2-sha512 ${toString yubikey.keyLength} $new_iterations $new_response | rbtohex)"
        else
            new_k_luks="$(echo | pbkdf2-sha512 ${toString yubikey.keyLength} $new_iterations $new_response | rbtohex)"
        fi

        mkdir -p ${yubikey.ramfsMountPoint}
        # A ramfs is used here to ensure that the file used to update
        # the key slot with cryptsetup will never get swapped out.
        # Warning: Do NOT replace with tmpfs!
        mount -t ramfs none ${yubikey.ramfsMountPoint}

        echo -n "$new_k_luks" | hextorb > ${yubikey.ramfsMountPoint}/new_key
        echo -n "$k_luks" | hextorb | cryptsetup luksChangeKey ${device} --key-file=- ${yubikey.ramfsMountPoint}/new_key

        if [ $? == "0" ]; then
            echo -ne "$new_salt\n$new_iterations" > ${yubikey.storage.mountPoint}${yubikey.storage.path}
        else
            echo "Warning: Could not update LUKS key, current challenge persists!"
        fi

        rm -f ${yubikey.ramfsMountPoint}/new_key
        umount ${yubikey.ramfsMountPoint}
        rm -rf ${yubikey.ramfsMountPoint}

        umount ${yubikey.storage.mountPoint}
    }

    ${optionalString (yubikey.gracePeriod > 0) ''
    echo -n "Waiting ${toString yubikey.gracePeriod} seconds as grace..."
    for i in $(seq ${toString yubikey.gracePeriod}); do
        sleep 1
        echo -n .
    done
    echo "ok"
    ''}

    yubikey_missing=true
    ykinfo -v 1>/dev/null 2>&1
    if [ $? != "0" ]; then
        echo -n "waiting 10 seconds for yubikey to appear..."
        for try in $(seq 10); do
            sleep 1
            ykinfo -v 1>/dev/null 2>&1
            if [ $? == "0" ]; then
                yubikey_missing=false
                break
            fi
            echo -n .
        done
        echo "ok"
    else
        yubikey_missing=false
    fi

    if [ "$yubikey_missing" == true ]; then
        echo "no yubikey found, falling back to non-yubikey open procedure"
        open_normally
    else
        open_yubikey
    fi
    ''}

    # open luksRoot and scan for logical volumes
    ${optionalString (((!luks.yubikeySupport) || (yubikey == null)) && (!luks.tpmSupport)) ''
    open_normally
    ''}
    ${optionalString (luks.tpmSupport) ''
    tpm_open
    ''}
  '';

  isPreLVM = f: f.preLVM;
  preLVM = filter isPreLVM luks.devices;
  postLVM = filter (f: !(isPreLVM f)) luks.devices;

in
{

  options = {

    boot.initrd.luks.mitigateDMAAttacks = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Unless enabled, encryption keys can be easily recovered by an attacker with physical
        access to any machine with PCMCIA, ExpressCard, ThunderBolt or FireWire port.
        More information: http://en.wikipedia.org/wiki/DMA_attack

        This option blacklists FireWire drivers, but doesn't remove them. You can manually
        load the drivers if you need to use a FireWire device, but don't forget to unload them!
      '';
    };

    boot.initrd.luks.cryptoModules = mkOption {
      type = types.listOf types.string;
      default =
        [ "aes" "aes_generic" "blowfish" "twofish"
          "serpent" "cbc" "xts" "lrw" "sha1" "sha256" "sha512"
          (if pkgs.stdenv.system == "x86_64-linux" then "aes_x86_64" else "aes_i586")
        ];
      description = ''
        A list of cryptographic kernel modules needed to decrypt the root device(s).
        The default includes all common modules.
      '';
    };

    boot.initrd.luks.devices = mkOption {
      default = [ ];
      example = [ { name = "luksroot"; device = "/dev/sda3"; preLVM = true; } ];
      description = ''
        The list of devices that should be decrypted using LUKS before trying to mount the
        root partition. This works for both LVM-over-LUKS and LUKS-over-LVM setups.

        The devices are decrypted to the device mapper names defined.

        Make sure that initrd has the crypto modules needed for decryption.
      '';

      type = types.listOf types.optionSet;

      options = {

        name = mkOption {
          example = "luksroot";
          type = types.string;
          description = "Named to be used for the generated device in /dev/mapper.";
        };

        device = mkOption {
          example = "/dev/sda2";
          type = types.string;
          description = "Path of the underlying block device.";
        };

        keyFile = mkOption {
          default = null;
          example = "/dev/sdb1";
          type = types.nullOr types.string;
          description = ''
            The name of the file (can be a raw device or a partition) that
            should be used as the decryption key for the encrypted device. If
            not specified, you will be prompted for a passphrase instead.
          '';
        };

        keyFileSize = mkOption {
          default = null;
          example = 4096;
          type = types.nullOr types.int;
          description = ''
            The size of the key file. Use this if only the beginning of the
            key file should be used as a key (often the case if a raw device
            or partition is used as key file). If not specified, the whole
            <literal>keyFile</literal> will be used decryption, instead of just
            the first <literal>keyFileSize</literal> bytes.
          '';
        };

        preLVM = mkOption {
          default = true;
          type = types.bool;
          description = "Whether the luksOpen will be attempted before LVM scan or after it.";
        };

        allowDiscards = mkOption {
          default = false;
          type = types.bool;
          description = ''
            Whether to allow TRIM requests to the underlying device. This option
            has security implications, please read the LUKS documentation before
            activating in.
          '';
        };

        tpm = mkOption {
          default = null;
          type = types.nullOr types.optionSet;
          description = ''
            The options to protect this LUKS device using the Trusted Platform Module (TPM).
            If null (the default), use of a TPM will be disabled for this device.
          '';

          options = {
            autoInstall = mkOption {
              default = true;
              type = types.bool;
              description = "Do automatic installation on the device";
            };

            sealPcrs = mkOption {
              default = "17";
              type = types.string;
              description = "List of PCR values to bind the LUKS key to";
            };

            storage = mkOption {
              type = types.optionSet;
              description = "Options related to storing the sealed key (on unencrypted device)";

              options = {
                device = mkOption {
                  default = /dev/sda1;
                  type = types.path;
                  description = ''An unencrypted device that will temporarily be mounted in stage-1
                    in order to store the TPM-sealed key.  If autoInstall is enabled, the key will
                    be written to this device.  Otherwise it must exist under the given path.
                  '';
                };

                mountPoint = mkOption {
                  default = "/tpm-keys";
                  type = types.path;
                  description = ''Mount point for the device containing the TPM-sealed key'';
                };

                path = mkOption {
                  default = "/crypt-storage/tpm-luks-sealed-key";
                  type = types.string;
                  description = ''
                    Relative path to the TPM-sealed LUKS password file on the device that holds it.
                    A password file can be created for example like this:
                    $ dd if=/dev/random bs=1 count=32 | tpm_sealdata -z -p17 -o outputfile

                    However, if autoInstall.closure is set it will automatically be created
                    during the initial automatic install and it should not exist prior to the
                    auto-install.
                    '';
                };
              };
            };
          };
	};

        yubikey = mkOption {
          default = null;
          type = types.nullOr types.optionSet;
          description = ''
            The options to use for this LUKS device in Yubikey-PBA.
            If null (the default), Yubikey-PBA will be disabled for this device.
          '';

          options = {
            twoFactor = mkOption {
              default = true;
              type = types.bool;
              description = "Whether to use a passphrase and a Yubikey (true), or only a Yubikey (false)";
            };

            slot = mkOption {
              default = 2;
              type = types.int;
              description = "Which slot on the Yubikey to challenge";
            };

            saltLength = mkOption {
              default = 16;
              type = types.int;
              description = "Length of the new salt in byte (64 is the effective maximum)";
            };

            keyLength = mkOption {
              default = 64;
              type = types.int;
              description = "Length of the LUKS slot key derived with PBKDF2 in byte";
            };

            iterationStep = mkOption {
              default = 0;
              type = types.int;
              description = "How much the iteration count for PBKDF2 is increased at each successful authentication";
            };

            gracePeriod = mkOption {
              default = 2;
              type = types.int;
              description = "Time in seconds to wait before attempting to find the Yubikey";
            };

            ramfsMountPoint = mkOption {
              default = "/crypt-ramfs";
              type = types.string;
              description = "Path where the ramfs used to update the LUKS key will be mounted in stage-1";
            };

            storage = mkOption {
              type = types.optionSet;
              description = "Options related to the storing the salt";

              options = {
                device = mkOption {
                  default = /dev/sda1;
                  type = types.path;
                  description = ''
                    An unencrypted device that will temporarily be mounted in stage-1.
                    Must contain the current salt to create the challenge for this LUKS device.
                  '';
                };

                fsType = mkOption {
                  default = "vfat";
                  type = types.string;
                  description = "The filesystem of the unencrypted device";
                };

                mountPoint = mkOption {
                  default = "/crypt-storage";
                  type = types.string;
                  description = "Path where the unencrypted device will be mounted in stage-1";
                };

                path = mkOption {
                  default = "/crypt-storage/default";
                  type = types.string;
                  description = ''
                    Absolute path of the salt on the unencrypted device with
                    that device's root directory as "/".
                  '';
                };
              };
            };
          };
        };
      };
    };

    boot.initrd.luks.yubikeySupport = mkOption {
      default = false;
      type = types.bool;
      description = ''
            Enables support for authenticating with a Yubikey on LUKS devices.
            See the NixOS wiki for information on how to properly setup a LUKS device
            and a Yubikey to work with this feature.
          '';
    };

    boot.initrd.luks.tpmSupport = mkOption {
      default = false;
      type = types.bool;
      description = ''
            Enables support for authenticating with a Yubikey on LUKS devices.
            See the NixOS wiki for information on how to properly setup a LUKS device
            and a Yubikey to work with this feature.
          '';
    };
  };

  config = mkIf (luks.devices != []) {

    # actually, sbp2 driver is the one enabling the DMA attack, but this needs to be tested
    boot.blacklistedKernelModules = optionals luks.mitigateDMAAttacks
      ["firewire_ohci" "firewire_core" "firewire_sbp2"];

    # Some modules that may be needed for mounting anything ciphered
    boot.initrd.availableKernelModules = [ "dm_mod" "dm_crypt" "cryptd" ] ++ luks.cryptoModules;

    # copy the cryptsetup binary and it's dependencies
    boot.initrd.extraUtilsCommands = ''
      cp -pdv ${pkgs.cryptsetup}/sbin/cryptsetup $out/bin

      cp -pdv ${pkgs.libgcrypt}/lib/libgcrypt*.so.* $out/lib
      cp -pdv ${pkgs.libgpgerror}/lib/libgpg-error*.so.* $out/lib
      cp -pdv ${pkgs.cryptsetup}/lib/libcryptsetup*.so.* $out/lib
      cp -pdv ${pkgs.popt}/lib/libpopt*.so.* $out/lib

      ${optionalString luks.yubikeySupport ''
      cp -pdv ${pkgs.ykpers}/bin/ykchalresp $out/bin
      cp -pdv ${pkgs.ykpers}/bin/ykinfo $out/bin
      cp -pdv ${pkgs.openssl}/bin/openssl $out/bin

      cc -O3 -I${pkgs.openssl}/include -L${pkgs.openssl}/lib ${./pbkdf2-sha512.c} -o $out/bin/pbkdf2-sha512 -lcrypto
      strip -s $out/bin/pbkdf2-sha512

      cp -pdv ${pkgs.libusb1}/lib/libusb*.so.* $out/lib
      cp -pdv ${pkgs.ykpers}/lib/libykpers*.so.* $out/lib
      cp -pdv ${pkgs.libyubikey}/lib/libyubikey*.so.* $out/lib
      cp -pdv ${pkgs.openssl}/lib/libssl*.so.* $out/lib
      cp -pdv ${pkgs.openssl}/lib/libcrypto*.so.* $out/lib

      mkdir -p $out/etc/ssl
      cp -pdv ${pkgs.openssl}/etc/ssl/openssl.cnf $out/etc/ssl

      cat > $out/bin/openssl-wrap <<EOF
#!$out/bin/sh
EOF
      chmod +x $out/bin/openssl-wrap
      ''}
      
      ${optionalString luks.tpmSupport ''
      # tpm-tools
      cp -pdv ${pkgs.tpm-tools}/bin/tpm_{un,}sealdata $out/bin
      cp -pdv ${pkgs.tpm-tools}/lib/libtpm*.so.* $out/lib
      cp -pdv ${pkgs.trousers}/lib/libtspi*.so.* $out/lib
      # tcsd
      cp -pdv ${pkgs.trousers}/sbin/tcsd $out/bin
#      cp -pdv ${pkgs.glibc}/lib/libpthread*.so.* $out/lib
      cp -pdv ${pkgs.openssl}/lib/libssl*.so.* $out/lib
      cp -pdv ${pkgs.openssl}/lib/libcrypto*.so.* $out/lib
      # mkfs.ext4 in case of an install
#      cp -pdv ${pkgs.e2fsprogs}/sbin/mke2fs $out/sbin
#      ln -s mke2fs $out/sbin/mkfs.ext4
#      cp -pdv ${pkgs.utillinux}/lib/libblkid*.so* $out/lib
#      cp -pdv ${pkgs.utillinux}/lib/libuuid*.so* $out/lib
      ''}

    '';

    boot.initrd.extraUtilsCommandsTest = ''
      $out/bin/cryptsetup --version
      ${optionalString luks.yubikeySupport ''
        $out/bin/ykchalresp -V
        $out/bin/ykinfo -V
        cat > $out/bin/openssl-wrap <<EOF
#!$out/bin/sh
export OPENSSL_CONF=$out/etc/ssl/openssl.cnf
$out/bin/openssl "\$@"
EOF
        $out/bin/openssl-wrap version
      ''}
    '';

    boot.initrd.preLVMCommands = concatMapStrings openCommand preLVM;
    boot.initrd.postDeviceCommands = concatMapStrings openCommand postLVM;

    environment.systemPackages = [ pkgs.cryptsetup ];
  };
}
