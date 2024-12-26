{
  lib,
  config,
  pkgs,
  ...
}: let
  cfg = config.rs-homelab.server.zfs;
in {
  options = {
    rs-homelab.server.zfs.enable = lib.mkEnableOption "Enables common zfs settings";
  };

  config = lib.mkIf cfg.enable {
    boot.initrd.systemd.enable = true;
    boot.initrd.systemd.services.rollback = {
      description = "Rollback root filesystem to a pristine state";
      wantedBy = ["initrd.target"];
      after = ["zfs-import-rpool.service"];
      before = ["sysroot.mount"];
      path = with pkgs; [zfs];
      unitConfig.DefaultDependencies = "no";
      serviceConfig.Type = "oneshot";
      script = ''
        zfs rollback -r rpool/local/root@blank && echo " >> >> Rollback Complete << <<"
      '';
    };

    services.zfs = {
      trim.enable = true;
      autoScrub.enable = true;
    };
  };
}
