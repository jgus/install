{ pkgs, ... }:

let
  gateway_port = "22023";
in {
  systemd = {
    services = {
      backup-gateway = {
        enable = true;
        description = "Backup Gateway Connection";
        wantedBy = [ "multi-user.target" ];
        path = [ pkgs.openssh ];
        script = "ssh -o StrictHostKeyChecking=no -i /root/.ssh/id_rsa-backup -N -R ${gateway_port}:localhost:22 -p 22022 user@landing.gustafson.me";
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
