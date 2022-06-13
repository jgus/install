{ config, ... }:

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
        # dataDir = "/var/lib/plex";
      };
  };
}
