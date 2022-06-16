{ ... }:

{
  time.timeZone = "America/Los_Angeles";

  networking = {
    hostName = "gustafson-nas";
    hostId = "98c0a40d"; # head -c4 /dev/urandom | od -A none -t x4
  };
}
