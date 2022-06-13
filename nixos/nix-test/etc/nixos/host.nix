{ ... }:

{
  time.timeZone = "America/Denver";

  networking = {
    hostName = "nix-test";
    hostId = "61e46f30"; # head -c4 /dev/urandom | od -A none -t x4
  };
}
