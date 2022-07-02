{ ... }:

{
  time.timeZone = "America/Denver";

  networking = {
    hostName = "c240-m3";
    hostId = "04b22318"; # head -c4 /dev/urandom | od -A none -t x4
  };
}
