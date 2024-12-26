{
  lib,
  config,
  ...
}: let
  cfg = config.rs-homelab.server.hardening;
in {
  options = {
    rs-homelab.server.hardening.enable = lib.mkEnableOption "turn on systemd hardening";
  };

  config = lib.mkIf cfg.enable {
    services.dbus.implementation = "broker";

    systemd.services.systemd-rfkill = {
      serviceConfig = {
        ProtectSystem = "strict";
        ProtectHome = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        ProtectClock = true;
        ProtectProc = "invisible";
        ProcSubset = "pid";
        PrivateTmp = true;
        MemoryDenyWriteExecute = true;
        NoNewPrivileges = true;
        LockPersonality = true;
        RestrictRealtime = true;
        SystemCallArchitectures = "native";
        UMask = "0077";
        IPAddressDeny = "any";
      };
    };

    systemd.services.systemd-journald = {
      serviceConfig = {
        UMask = 0077;
        PrivateNetwork = true;
        ProtectHostname = true;
        ProtectKernelModules = true;
      };
    };
  };
}
