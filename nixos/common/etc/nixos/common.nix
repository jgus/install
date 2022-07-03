{ config, pkgs, ... }:

{
  boot = {
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;
    tmpOnTmpfs = true;
    loader.timeout = 1;
  };

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    keyMap = "us";
  };

  networking = {
    firewall.allowPing = true;

    # The global useDHCP flag is deprecated, therefore explicitly set to false here.
    # Per-interface useDHCP will be mandatory in the future, so this generated config
    # replicates the default behaviour.
    useDHCP = false;
    tempAddresses = "disabled";
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    parted
    git
  ];

  services = {
    ntp.enable = true;
    
    openssh = {
      enable = true;
      openFirewall = true;
    };
  };

  system = {
    # This value determines the NixOS release from which the default
    # settings for stateful data, like file locations and database versions
    # on your system were taken. It‘s perfectly fine and recommended to leave
    # this value at the release version of the first install of this system.
    # Before changing this value read the documentation for this option
    # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
    stateVersion = "22.05"; # Did you read the comment?

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

  system.activationScripts = {
    syncBoot.text = ''
      i=1
      while mountpoint -q /boot/''${i}
      do
          ${pkgs.rsync}/bin/rsync -arqx --delete /boot/ /boot/''${i}/
          ((i+=1))
      done
    '';
  };
}
