{ pkgs, ... }:

{
  imports = [ (fetchTarball "https://github.com/msteen/nixos-vscode-server/tarball/master") ];

  services = {
    vscode-server.enable = true;
  };

  system.activationScripts = {
    vscode = {
      text = ''
        ${pkgs.systemd}/bin/systemctl --user enable --now auto-fix-vscode-server.service 2>/dev/null
      '';
      deps = [];
    };
  };
}
