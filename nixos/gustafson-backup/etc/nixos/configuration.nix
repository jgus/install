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
    extraModulePackages = with config.boot.kernelPackages; [ zfs ];
    kernelModules = [ "zfs" ];
  };

  networking.hostName = "gustafson-backup";

  time.timeZone = "America/Los_Angeles";

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

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    parted
    zfs
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

    # plex = {
    #   enable = true;
    #   openFirewall = true;
    #   # dataDir = "/var/lib/plex";
    # };
    
    ### Don't forget smbpasswd -a <user>
    # samba = {
    #   enable = true;
    #   openFirewall = true;
    #   securityType = "user";
    #   extraConfig = ''
    #     workgroup = WORKGROUP
    #     server string = Gustafson-Backup
    #     netbios name = Gustafson-Backup
    #     security = user 
    #     #use sendfile = yes
    #     #max protocol = smb2
    #     # note: localhost is the ipv6 localhost ::1
    #     # hosts allow = 10. 172. 192.168. 127.0.0.1 localhost
    #     # hosts deny = 0.0.0.0/0
    #     guest account = nobody
    #     map to guest = bad user
    #   '';
    #   shares = {
    #     public = {
    #       path = "/mnt/Shares/Public";
    #       browseable = "yes";
    #       "read only" = "no";
    #       "guest ok" = "yes";
    #       "create mask" = "0644";
    #       "directory mask" = "0755";
    #       "force user" = "username";
    #       "force group" = "groupname";
    #     };
    #     private = {
    #       path = "/mnt/Shares/Private";
    #       browseable = "yes";
    #       "read only" = "no";
    #       "guest ok" = "no";
    #       "create mask" = "0644";
    #       "directory mask" = "0755";
    #       "force user" = "username";
    #       "force group" = "groupname";
    #     };
    #   };
    # };
  };

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;
  networking.firewall.allowPing = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "21.11"; # Did you read the comment?

}
