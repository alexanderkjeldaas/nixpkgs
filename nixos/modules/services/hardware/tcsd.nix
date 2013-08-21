# tcsd daemon.

{ config, pkgs, ... }:

with pkgs.lib;
let

  cfg = config.services.tcsd;

  tcsdConf = pkgs.writeText "tcsd.conf" ''
    port = 30003
    num_threads = 10
    system_ps_file = ${cfg.stateDir}/system.data
    #firmware_log_file = /proc/tpm/firmware_events
    #kernel_log_file = /proc/tcg/measurement_events
    firmware_pcrs = 0,1,2,3,4,5,6,7
    kernel_pcrs = 10,11
    platform_cred = ${cfg.platformCred}
    conformance_cred = ${cfg.conformanceCred}
    endorsement_cred = ${cfg.endorsementCred}
    #remote_ops = create_key,random
    host_platform_class = server_12
    all_platform_classes = pc_11,pc_12,mobile_12
  '';

in
{

  ###### interface

  options = {

    services.tcsd = {

      enable = mkOption {
        default = false;
        description = ''
          Whether to enable tcsd, a Trusted Computing management service
          that provides TCG Software Stack (TSS).  The tcsd daemon is
          the only portal to the Trusted Platform Module (TPM), a hardware
          chip on the motherboard.
        '';
      };

      user = mkOption {
        default = "tss";
        description = "User account under which tcsd runs.";
      };

      group = mkOption {
        default = "tss";
        description = "Group account under which tcsd runs.";
      };

      stateDir = mkOption {
	default = "/var/lib/tpm";
	description = ''
          The location of the system persistent storage file.
          The system persistent storage file holds keys and data across
          restarts of the TCSD and system reboots. 
	'';
      };

      platformCred = mkOption {
        default = "${cfg.stateDir}/platform.cert";
        description = ''
	  Path to the platform credential for your TPM. Your TPM
          manufacturer may have provided you with a set of credentials
          (certificates) that should be used when creating identities
          using your TPM. When a user of your TPM makes an identity,
          this credential will be encrypted as part of that process.
          See the 1.1b TPM Main specification section 9.3 for information
          on this process. '';
      };

      conformanceCred = mkOption {
        default = "${cfg.stateDir}/conformance.cert";
        description = ''
          Path to the conformance credential for your TPM.
          See also the platformCred option'';
      };

      endorsementCred = mkOption {
        default = "${cfg.stateDir}/endorsement.cert";
        description = ''
          Path to the endorsement credential for your TPM.
          See also the platformCred option'';
      };
    };

  };

  ###### implementation

  config = mkIf cfg.enable {

    environment.systemPackages = [ pkgs.trousers ];

#    system.activationScripts.tcsd =
#      ''
#        chown ${cfg.user}:${cfg.group} ${tcsdConf}
#      '';

    systemd.services.tcsd = {
      description = "TCSD";
      after = [ "basic.target" ];
      wantedBy = [ "multi-user.target" ];
      path = [ pkgs.trousers ];
      preStart =
        ''
        mkdir -m 0700 -p ${cfg.stateDir}
        chown -R ${cfg.user}:${cfg.group} ${cfg.stateDir}
        '';
      serviceConfig.ExecStart = "${pkgs.trousers}/sbin/tcsd -c ${tcsdConf}";
    };

    users.extraUsers = optionalAttrs (cfg.user == "tss") (singleton
      { name = "tss";
        group = "tss";
        uid = config.ids.uids.nginx;
      });

    users.extraGroups = optionalAttrs (cfg.group == "tss") (singleton
      { name = "tss";
        gid = config.ids.gids.nginx;
      });
  };
}
