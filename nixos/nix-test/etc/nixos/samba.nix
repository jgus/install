### Don't forget: smbpasswd -a <user>

{ ... }:

{
  networking = {
    firewall = {
      allowedTCPPorts = [
        5357 # wsdd
      ];
      allowedUDPPorts = [
        3702 # wsdd
      ];
    };
  };

  services = {
    samba-wsdd.enable = true;
    samba = {
      enable = true;
      enableNmbd = false;
      openFirewall = true;
      securityType = "user";
      extraConfig = ''
        server role = standalone server
        wins support = yes
        workgroup = WORKGROUP
        server string = Gustafson-NAS
      '';
      # shares = {
      #   public = {
      #     path = "/mnt/Shares/Public";
      #     browseable = "yes";
      #     "guest ok" = "yes";
      #     "valid users" = "tester";
      #   };
      #   private = {
      #     path = "/mnt/Shares/Private";
      #     browseable = "yes";
      #     "guest ok" = "no";
      #     "valid users" = "tester";
      #   };
      # };
    };
  };
}
