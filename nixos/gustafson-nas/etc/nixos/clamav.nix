{ config, pkgs, ... }:

{
  imports = [ ./msmtp.nix ];

  environment.etc = {
    "clamav/clamav-scan-d.sh".source = ./clamav/clamav-scan-d.sh;
  };

  services = {
    clamav = {
      daemon.enable = true;
      updater.enable = true;
    };
  };

  systemd = {
    services = {
      clamav-scan-system = {
        path = with pkgs; [ clamav ];
        script = ''
          clamscan -r --cross-fs=no -i --move=/boot/INFECTED /boot/
          clamscan -r --cross-fs=no -i --move=/INFECTED /
        '';
        serviceConfig = {
          Type = "oneshot";
        };
      };
      clamav-scan-d = {
        path = with pkgs; [
          bash
          clamav
          hostname
          mount
          msmtp
          sharutils
          umount
          zfs
        ];
        script = "/etc/clamav/clamav-scan-d.sh";
        serviceConfig = {
          Type = "oneshot";
        };
      };
    };
    timers = {
      clamav-scan-system = {
        wantedBy = [ "timers.target" ];
        partOf = [ "clamav-scan-system.service" ];
        timerConfig = {
          OnCalendar = "weekly";
          Persistent = true;
          Unit = "clamav-scan-system.service";
        };
      };
      clamav-scan-d = {
        wantedBy = [ "timers.target" ];
        partOf = [ "clamav-scan-d.service" ];
        timerConfig = {
          OnCalendar = "daily";
          Persistent = true;
          Unit = "clamav-scan-d.service";
        };
      };
    };
  };
}
