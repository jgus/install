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
      shares = {
        Files = {
          path = "/d/Files";
          browseable = "yes";
          "valid users" = "gustafson";
          "read only" = "no";
        };
        Files-Snapshots = {
          path = "/d/Files/.zfs/snapshot";
          browseable = "yes";
          "valid users" = "gustafson";
        };
        Music = {
          path = "/d/Music";
          browseable = "yes";
          "valid users" = "gustafson";
          "read only" = "no";
        };
        Music-Snapshots = {
          path = "/d/Music/.zfs/snapshot";
          browseable = "yes";
          "valid users" = "gustafson";
        };
        Movies = {
          path = "/d/Movies";
          browseable = "yes";
          "valid users" = "gustafson";
          "read only" = "no";
        };
        Tv = {
          path = "/d/Tv";
          browseable = "yes";
          "valid users" = "gustafson";
          "read only" = "no";
        };
      };
    };
  };
}
