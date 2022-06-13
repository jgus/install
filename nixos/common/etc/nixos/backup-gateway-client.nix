{ pkgs, ... }:

{
  systemd = {
    services = {
      backup-gateway = {
        enable = true;
        description = "Backup Gateway Connection";
        wantedBy = [ "multi-user.target" ];
        path = [ pkgs.openssh ];
        script = "ssh -i /root/.ssh/id_rsa-backup -N -R 22023:localhost:22 -p 22022 user@jarvis.gustafson.me";
        unitConfig = {
          StartLimitIntervalSec = 0;
        };
        serviceConfig = {
          Restart = "always";
          RestartSec = 10;
        };
      };
    };
  };
}
