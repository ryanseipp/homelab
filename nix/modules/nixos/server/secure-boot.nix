{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.rs-homelab.server.secure-boot;
in
{
  options = {
    rs-homelab.server.secure-boot.enable = lib.mkEnableOption "Enables secure boot";
  };

  config = lib.mkIf cfg.enable {
    boot.lanzaboote = {
      enable = true;
      pkiBundle = "/var/lib/sbctl";
    };
    environment.persistence."/persist".directories = [ "/var/lib/sbctl" ];

    boot.loader.systemd-boot.enable = lib.mkForce false;
    boot.initrd.systemd.enable = true;
    boot.initrd.systemd.tpm2.enable = true;

    # secure /proc fs
    boot.kernel.sysctl = {
      "fs.protected_fifos" = 2;
      "fs.protected_regular" = 2;
      "fs.suid_dumpable" = false;
      "kernel.kptr_restrict" = 2;
      "kernel.sysrq" = false;
      "kernel.unprivileged_bpf_disabled" = true;
    };

    security.tpm2 = {
      enable = true;
      pkcs11.enable = true;
      tctiEnvironment.enable = true;
    };

    environment.shellAliases = {
      # Requires a device argument (/dev/nvme1n1p2)
      cryptenroll = "systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=0+2+7+15:sha256=0000000000000000000000000000000000000000000000000000000000000000 --wipe-slot=tpm2";
    };

    # CLI tools to debug with
    environment.systemPackages = with pkgs; [
      sbctl
      tpm2-tools
    ];
  };
}
