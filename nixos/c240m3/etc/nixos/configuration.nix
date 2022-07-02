{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix

      ./common.nix
      ./host.nix
      ./users.nix

      #./backup-gateway-client.nix
      #./docker.nix
      #./dyndns.nix
      #./plex.nix
      ./vscode.nix
      ./zfs.nix
    ];
}
