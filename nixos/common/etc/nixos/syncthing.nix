{ pkgs, ... }:

{
  systemd = {
    services = {
      syncthing = {
        enable = true;
        description = "Syncthing";
        wantedBy = [ "multi-user.target" ];
        path = [ pkgs.docker ];
        script = ''
          /bin/sh -c "docker run --rm --name syncthing \
          -p 8384:8384 \
          -p 22000:22000 \
          -p 21027:21027/udp \
          -e PUID=$(id -u josh) \
          -e PGID=$(id -g josh) \
          -e TZ=$(timedatectl show -p Timezone --value) \
          -e UMASK_SET=002 \
          -v /var/lib/syncthing/config:/config \
          lscr.io/linuxserver/syncthing"
          '';
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
}
