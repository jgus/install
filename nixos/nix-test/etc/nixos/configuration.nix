{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Use the systemd-boot EFI boot loader.
  boot = {
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;
    extraModulePackages = with config.boot.kernelPackages; [
      zfs
    ];
    kernelModules = [
      "zfs"
    ];
  };

  networking.hostName = "nix-test";

  time.timeZone = "America/Denver";

  # The global useDHCP flag is deprecated, therefore explicitly set to false here.
  # Per-interface useDHCP will be mandatory in the future, so this generated config
  # replicates the default behaviour.
  networking.useDHCP = false;
  networking.interfaces.eth0.useDHCP = true;

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
    
    ### Don't forget smbpasswd -a <user>
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
  };

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;
  networking.firewall.allowPing = true;
  networking.firewall.allowedTCPPorts = [
    445
    139
    5357 # wsdd
  ];
  networking.firewall.allowedUDPPorts = [
    137
    138
    3702 # wsdd
  ];

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
