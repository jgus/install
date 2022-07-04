{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix

      ./common.nix
      ./interfaces.nix
      ./host.nix
      ./users.nix

      #./nvidia.nix

      ./docker.nix
      ./plex.nix
      ./vscode.nix
      ./zfs.nix
    ];
}
