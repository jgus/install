### Don't forget: systemctl --user enable --now auto-fix-vscode-server.service

{ ... }:

{
  imports = [ (fetchTarball "https://github.com/msteen/nixos-vscode-server/tarball/master") ];

  services = {
    vscode-server.enable = true;
  };
}
