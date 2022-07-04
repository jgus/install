{ config, pkgs, ... }:

{
  nixpkgs.config.allowUnfree = true;

  services = {
    plex = let
      master = import
          (builtins.fetchTarball https://github.com/nixos/nixpkgs/tarball/master)
          { config = config.nixpkgs.config; };
      in {
        enable = true;
        openFirewall = true;
        package = master.plex;
        dataDir = "/var/lib/plex";
      };
  };

  system.activationScripts = {
    plexSetup.text = ''
      BASE=rpool
      if ! ${pkgs.zfs}/bin/zfs list rpool/plex >/dev/null 2>&1
      then
        ${pkgs.zfs}/bin/zfs create rpool/plex -o mountpoint=/var/lib/plex -o autobackup:offsite1=true -o autobackup:snap-$(${pkgs.hostname}/bin/hostname)=true
        ${pkgs.zfs}/bin/zfs create rpool/plex/media -o mountpoint="/var/lib/plex/Plex Media Server/Media" -o autobackup:offsite1=false -o autobackup:snap-$(${pkgs.hostname}/bin/hostname)=false
        ${pkgs.zfs}/bin/zfs create rpool/plex/metadata -o mountpoint="/var/lib/plex/Plex Media Server/Metadata" -o autobackup:offsite1=false -o autobackup:snap-$(${pkgs.hostname}/bin/hostname)=false
        ${pkgs.zfs}/bin/zfs create d/transcode -o autobackup:offsite1=false -o autobackup:snap-$(${pkgs.hostname}/bin/hostname)=false
        chown -R plex:plex /var/lib/plex
      fi
    '';
  };

  fileSystems."/media" = {
      device = "//nas/Media";
      fsType = "cifs";
      options = let
        # this line prevents hanging on network split
        automount_opts = "x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s";

      in ["${automount_opts},credentials=/etc/nixos/plex-smb-secrets,uid=${toString(config.users.users.plex.uid)},gid=${toString(config.users.groups.plex.gid)}"];
  };
}
