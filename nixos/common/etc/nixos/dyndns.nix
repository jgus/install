{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    dyndnsc
  ];

  systemd = {
    services = {
      update-ddns = {
        path = [ pkgs.dyndnsc ];
        script = "dyndnsc --config /root/.secrets/dyndnsc.conf";
        serviceConfig = {
          Type = "oneshot";
        };
      };
    };
    timers = {
      update-ddns = {
        wantedBy = [ "timers.target" ];
        partOf = [ "update-ddns.service" ];
        timerConfig = {
          OnCalendar = "hourly";
          Persistent = true;
          Unit = "update-ddns.service";
        };
      };
    };
  };
}
