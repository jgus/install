{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix

      # For VS Code
      (fetchTarball "https://github.com/msteen/nixos-vscode-server/tarball/master")
    ];

  # Use the systemd-boot EFI boot loader.
  boot = {
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;
    supportedFilesystems = [
      "zfs"
    ];
    zfs = {
      devNodes = "/dev/disk/by-path";
      #extraPools = [ "d" ];
    };
  };

  time.timeZone = "America/Denver";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    keyMap = "us";
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  # users.users.jane = {
  #   isNormalUser = true;
  #   extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
  # };
  users.users.tester = {
    isNormalUser = true;
  };

  networking = {
    hostName = "nix-test";
    hostId = "61e46f30"; # head -c4 /dev/urandom | od -A none -t x4
    
    firewall = {
      allowPing = true;
      allowedTCPPorts = [
        445
        139
        5357 # wsdd
      ];
      allowedUDPPorts = [
        137
        138
        3702 # wsdd
      ];
    };

    # The global useDHCP flag is deprecated, therefore explicitly set to false here.
    # Per-interface useDHCP will be mandatory in the future, so this generated config
    # replicates the default behaviour.
    useDHCP = false;
    interfaces.eth0.useDHCP = true;
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    parted
    zfs
    git
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  nixpkgs.config.allowUnfree = true;

  services = {
    ntp.enable = true;
    
    openssh = {
      enable = true;
      openFirewall = true;
    };

    # plex = let
    #   master = import
    #       (builtins.fetchTarball https://github.com/nixos/nixpkgs/tarball/master)
    #       { config = config.nixpkgs.config; };
    #   in {
    #     enable = true;
    #     openFirewall = true;
    #     package = master.plex;
    #     # dataDir = "/var/lib/plex";
    #   };
    
    ### Don't forget: smbpasswd -a <user>
    samba-wsdd.enable = true;
    samba = {
      enable = true;
      openFirewall = true;
      securityType = "user";
      extraConfig = ''
        server role = standalone server
        wins support = yes
        workgroup = WORKGROUP
        server string = Nix-Test
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

    ### Don't forget: systemctl --user enable --now auto-fix-vscode-server.service
    vscode-server.enable = true;
  };

  systemd = {
    services = {
      backup-gateway = {
        enable = true;
        description = "Backup Gateway Connection";
        wantedBy = [ "multi-user.target" ];
        script = "/run/current-system/sw/bin/ssh -i /root/.ssh/id_rsa-backup -N -R 22023:localhost:22 -p 22022 user@jarvis.gustafson.me";
        unitConfig = {
          StartLimitIntervalSec = 0;
        };
        serviceConfig = {
          Restart = "always";
          RestartSec = 10;
        };
      };
    };
  };

  system = {
    # This value determines the NixOS release from which the default
    # settings for stateful data, like file locations and database versions
    # on your system were taken. It‘s perfectly fine and recommended to leave
    # this value at the release version of the first install of this system.
    # Before changing this value read the documentation for this option
    # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
    stateVersion = "21.11"; # Did you read the comment?

    autoUpgrade = {
      enable = true;
      allowReboot = true;
    };
  };

  nix.gc = {
    automatic = true;
    persistent = true;
    options = "--delete-older-than 30d";
  };
}
