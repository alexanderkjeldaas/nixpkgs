{ config, lib, pkgs, ... }:

with lib;

let

  cfg = config.boot.loader.grub;

  realGrub = if cfg.version == 1 then pkgs.grub else pkgs.grub2;

  grub =
    # Don't include GRUB if we're only generating a GRUB menu (e.g.,
    # in EC2 instances).
    if cfg.devices == ["nodev"]
    then null
    else realGrub;

  f = x: if x == null then "" else "" + x;

  grubConfig = pkgs.writeText "grub-config.xml" (builtins.toXML
    { splashImage = f config.boot.loader.grub.splashImage;
      grub = f grub;
      shell = "${pkgs.stdenv.shell}";
      fullVersion = (builtins.parseDrvName realGrub.name).version;
      inherit (cfg)
        version extraConfig extraPerEntryConfig extraEntries
        extraEntriesBeforeNixOS extraPrepareConfig configurationLimit copyKernels timeout
        default devices;
      tbootPath = (makeSearchPath "/" [ pkgs.tboot ]);
      trustedBootEnable = cfg.trustedBoot.enable;
      trustedBootAutoLcp = cfg.trustedBoot.autoLcp;
      trustedBootTbootParams = cfg.trustedBoot.tbootParams;
      trustedBootLcpPublicKey = cfg.trustedBoot.publicKey;
      trustedBootLcpPrivateKey = cfg.trustedBoot.privateKey;

      path = (makeSearchPath "bin" [
        pkgs.coreutils pkgs.gnused pkgs.gnugrep pkgs.findutils pkgs.diffutils pkgs.openssl
      ]) + ":" + (makeSearchPath "sbin" [
        pkgs.mdadm pkgs.tboot pkgs.tpm-tools
      ]);
    });

in

{

  ###### interface

  options = {

    boot.loader.grub = {

      enable = mkOption {
        default = !config.boot.isContainer;
        type = types.bool;
        description = ''
          Whether to enable the GNU GRUB boot loader.
        '';
      };

      version = mkOption {
        default = 2;
        example = 1;
        type = types.int;
        description = ''
          The version of GRUB to use: <literal>1</literal> for GRUB
          Legacy (versions 0.9x), or <literal>2</literal> (the
          default) for GRUB 2.
        '';
      };

      device = mkOption {
        default = "";
        example = "/dev/hda";
        type = types.str;
        description = ''
          The device on which the GRUB boot loader will be installed.
          The special value <literal>nodev</literal> means that a GRUB
          boot menu will be generated, but GRUB itself will not
          actually be installed.  To install GRUB on multiple devices,
          use <literal>boot.loader.grub.devices</literal>.
        '';
      };

      devices = mkOption {
        default = [];
        example = [ "/dev/hda" ];
        type = types.listOf types.str;
        description = ''
          The devices on which the boot loader, GRUB, will be
          installed. Can be used instead of <literal>device</literal> to
          install grub into multiple devices (e.g., if as softraid arrays holding /boot).
        '';
      };

      configurationName = mkOption {
        default = "";
        example = "Stable 2.6.21";
        type = types.str;
        description = ''
          GRUB entry name instead of default.
        '';
      };
      
      trustedBoot = {
        enable = mkOption {
      	  default = false;
      	  description = ''
      	    Whether GRUB should be setup using tboot and use trusted boot.
            See also "Intel® Trusted Execution Technology (Intel® TXT)
            Software Development Guide. Measured Launched Environment Developer’s Guide"
            http://www.intel.com/content/dam/www/public/us/en/documents/guides/intel-txt-software-development-guide.pdf
      	  '';
        };

        autoLcp = mkOption {
          default = true;
          description = ''
            Whether a Launch Control Policy should be automatically derived for the boot.
          '';
        };

        tbootParams = mkOption {
          default = "logging=serial,vga,memory vga_delay=1";
          description = ''
            Parameters given to tboot, the Intel TXT trusted boot.
          '';
        };

        lcpIncludePlatformPCRs = mkOption {
          default = false;
          description = ''
            Whether to include the platform environment PCONF in the LCP.
            The platform environment include PCR0..PCR7 of the TPM and
            such things as the BIOS, option ROMs, MBR, etc.  These can
            easily change when adding or removing hardware, or when 
            changing BIOS settings.  The dynamic root of trust measurement
            (DRTM) should mostly be isolated from this when using Intel TXT
            because the CPU enters an isolated state, but including these
            can give extra protection.

            WARNING: SEALing data to the PCONF environment can render the
            data unavailable if the platform environment changes.
          '';
        };

        privateKey = mkOption {
          default = "/etc/tboot/privkey.pem";
          description = ''
            Optional private key used to sign LCP.  You can create this key with
            the command:  "openssl genrsa -out privkey.pem 2048".

            The purpose of signed policies is to provide a mechanism that allows policy authors to
            update the list of permissible environments without having to update the TPM NV
            (note that if revocation is used that the TPM NV must be updated to increment the
            revocation counter). This allows updates to be simple file pushes rather than physical
            or remote platform touches. It also facilitates sealing against the policy, as sealed
            data does not have to be migrated when the policy is updated. The use of this mechanism
            places certain responsibilities on policy authors:

            The private signature key needs to be kept secure and under the control of the
            key owner at all times.

            The private signature key needs to be strong enough for the full lifetime of the
            policy [for the Platform Supplier we have estimated up to seven years]
          '';
        };

        publicKey = mkOption {
          default = "/etc/tboot/pubkey.pem";
          description = ''
            Optional public key used to verify a signed LCP.  If privateKey exists, the public key
            will be derived using the command: "openssl rsa -pubout -in privateKey.pem -out publicKey.pem".
          '';
        };

        sinit = mkOption {
          description = ''
            The SINIT ACM (authenticated code module) for your CPU.  The program nixos-scan-hardware
            should detect and give the correct setting.
          '';
        };

        racm = mkOption {
          description = ''
            The Revocation ACM (authenticated code module) for your CPU.  This SINIT updates the
            revocation list for SINIT versions that have security flaws.  This is updated in the CPU.

            The separate setting enableRACM must be set to enable this.

            WARNING: The CPU updates that RACM does are irreversible.
          '';
        };

        enableRACM = mkOption {
          default = false;
          description = ''
            Whether the RACM module should be run on boot.  WARNING: The CPU updates that RACM does are 
            irreversible.'';
        };
     };

      

      extraPrepareConfig = mkOption {
        default = "";
        type = types.lines;
        description = ''
          Additional bash commands to be run at the script that
          prepares the grub menu entries.
        '';
      };

      extraConfig = mkOption {
        default = "";
        example = "serial; terminal_output.serial";
        type = types.lines;
        description = ''
          Additional GRUB commands inserted in the configuration file
          just before the menu entries.
        '';
      };

      extraPerEntryConfig = mkOption {
        default = "";
        example = "root (hd0)";
        type = types.lines;
        description = ''
          Additional GRUB commands inserted in the configuration file
          at the start of each NixOS menu entry.
        '';
      };

      extraEntries = mkOption {
        default = "";
        type = types.lines;
        example = ''
          # GRUB 1 example (not GRUB 2 compatible)
          title Windows
            chainloader (hd0,1)+1

          # GRUB 2 example
          menuentry "Windows 7" {
            chainloader (hd0,4)+1
          }
        '';
        description = ''
          Any additional entries you want added to the GRUB boot menu.
        '';
      };

      extraEntriesBeforeNixOS = mkOption {
        default = false;
        type = types.bool;
        description = ''
          Whether extraEntries are included before the default option.
        '';
      };

      extraFiles = mkOption {
        default = {};
        example = literalExample ''
          { "memtest.bin" = "''${pkgs.memtest86plus}/memtest.bin"; }
        '';
        description = ''
          A set of files to be copied to <filename>/boot</filename>.
          Each attribute name denotes the destination file name in
          <filename>/boot</filename>, while the corresponding
          attribute value specifies the source file.
        '';
      };

      splashImage = mkOption {
        example = literalExample "./my-background.png";
        description = ''
          Background image used for GRUB.  It must be a 640x480,
          14-colour image in XPM format, optionally compressed with
          <command>gzip</command> or <command>bzip2</command>.  Set to
          <literal>null</literal> to run GRUB in text mode.
        '';
      };

      configurationLimit = mkOption {
        default = 100;
        example = 120;
        type = types.int;
        description = ''
          Maximum of configurations in boot menu. GRUB has problems when
          there are too many entries.
        '';
      };

      copyKernels = mkOption {
        default = false;
        type = types.bool;
        description = ''
          Whether the GRUB menu builder should copy kernels and initial
          ramdisks to /boot.  This is done automatically if /boot is
          on a different partition than /.
        '';
      };

      timeout = mkOption {
        default = 5;
        type = types.int;
        description = ''
          Timeout (in seconds) until GRUB boots the default menu item.
        '';
      };

      default = mkOption {
        default = 0;
        type = types.int;
        description = ''
          Index of the default menu item to be booted.
        '';
      };

    };

  };


  ###### implementation

  config = mkMerge [

    { boot.loader.grub.splashImage = mkDefault (
        if cfg.version == 1 then pkgs.fetchurl {
          url = http://www.gnome-look.org/CONTENT/content-files/36909-soft-tux.xpm.gz;
          sha256 = "14kqdx2lfqvh40h6fjjzqgff1mwk74dmbjvmqphi6azzra7z8d59";
        }
        # GRUB 1.97 doesn't support gzipped XPMs.
        else ./winkler-gnu-blue-640x480.png);
    }

    (mkIf cfg.enable {

      boot.loader.grub.devices = optional (cfg.device != "") cfg.device;

      system.build.installBootLoader =
        if cfg.devices == [] then
          throw "You must set the option ‘boot.loader.grub.device’ to make the system bootable."
        else
          "PERL5LIB=${makePerlPath [ pkgs.perlPackages.XMLLibXML pkgs.perlPackages.XMLSAX ]} " +
          "${pkgs.perl}/bin/perl ${./install-grub.pl} ${grubConfig}";

      system.build.grub = grub;

      # Common attribute for boot loaders so only one of them can be
      # set at once.
      system.boot.loader.id = "grub";

      environment.systemPackages = optional (grub != null) grub ++ optional cfg.trustedBoot.enable [ pkgs.tboot pkgs.tpm-tools ];

      boot.loader.grub.extraPrepareConfig =
        concatStrings (mapAttrsToList (n: v: ''
          ${pkgs.coreutils}/bin/cp -pf "${v}" "/boot/${n}"
        '') config.boot.loader.grub.extraFiles);

    })

  ];

}
