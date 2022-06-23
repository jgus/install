{ pkgs, ... }:

{
  boot = {
    supportedFilesystems = [
      "zfs"
    ];
    zfs = {
      devNodes = "/dev/disk/by-path";
      extraPools = [ "rpool" ];
    };
  };

  environment.systemPackages = with pkgs; [
    zfs
    zfs-autobackup
  ];

  services.zfs.autoScrub.enable = true;

  systemd = {
    services = {
      zfs-auto-snapshot = {
        path = with pkgs; [ hostname zfs zfs-autobackup ];
        script = "zfs-autobackup --keep-source 10,1h2d,1d2w,1w2m,1m1y snap-$(hostname)";
        serviceConfig = {
          Type = "oneshot";
        };
      };
    };
    timers = {
     zfs-auto-snapshot = {
        wantedBy = [ "timers.target" ];
        partOf = [ "zfs-auto-snapshot.service" ];
        timerConfig = {
          OnCalendar = "hourly";
          Persistent = true;
          Unit = "zfs-auto-snapshot.service";
        };
      };
    };
  };
}
