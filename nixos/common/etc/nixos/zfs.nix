{ pkgs, ... }:

{
  boot = {
    supportedFilesystems = [
      "zfs"
    ];
    zfs = {
      devNodes = "/dev/disk/by-path";
      #extraPools = [ "d" ];
    };
  };

  environment.systemPackages = with pkgs; [
    zfs
  ];

  services.zfs.autoScrub.enable = true;
}
