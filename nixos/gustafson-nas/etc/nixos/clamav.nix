{ config, pkgs, ... }:

{
  imports = [ ./msmtp.nix ];

  environment.etc = {
    "clamav/clamav-scan-zfs.sh".source = ./clamav/clamav-scan-zfs.sh;
  };

  services = {
    clamav = {
      daemon.enable = true;
      updater.enable = true;
    };
  };

  systemd = {
    services = {
      clamav-scan-all = {
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
        script = ''
          clamscan -r --cross-fs=no -i --move=/boot/INFECTED /boot/
          /etc/clamav/clamav-scan-zfs.sh
        '';
        serviceConfig = {
          Type = "oneshot";
        };
      };
    };
    timers = {
      clamav-scan-all = {
        enable = true;
        wantedBy = [ "timers.target" ];
        partOf = [ "clamav-scan-all.service" ];
        timerConfig = {
          OnCalendar = "daily";
          Persistent = true;
          Unit = "clamav-scan-all.service";
        };
      };
    };
  };

  system.activationScripts = {
    freshclam.text = ''
      [ -d /var/lib/clamav ] || ${pkgs.systemd}/bin/systemctl start clamav-freshclam.service
    '';
  };
}
