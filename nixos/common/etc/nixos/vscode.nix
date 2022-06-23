{ ... }:

{
  imports = [ (fetchTarball "https://github.com/msteen/nixos-vscode-server/tarball/master") ];

  services = {
    vscode-server.enable = true;
  };

  system.activationScripts = {
    vscode = {
      text = ''
        systemctl --user enable --now auto-fix-vscode-server.service
      '';
      deps = [];
    };
  };
}
