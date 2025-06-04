{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.rs-homelab.server;
in
{
  imports = [
    ./hardening.nix
    ./networking.nix
    ./partitions.nix
    ./secure-boot.nix
    ./ssh.nix
    ./users.nix
    ./zfs.nix
  ];

  options = {
    rs-homelab.server.enable = lib.mkEnableOption "sets up default server configuration";
  };

  config = lib.mkIf cfg.enable {
    rs-homelab.server.defaultUsers.enable = lib.mkDefault true;
    rs-homelab.server.secure-boot.enable = lib.mkDefault true;
    rs-homelab.server.hardening.enable = lib.mkDefault true;
    rs-homelab.server.networking.enable = lib.mkDefault true;
    rs-homelab.server.ssh.enable = lib.mkDefault true;
    rs-homelab.server.zfs.enable = lib.mkDefault true;

    powerManagement.powertop.enable = true;

    services.getty.greetingLine = ''
      <<< Welcome to ${config.system.nixos.distroName} ${config.system.nixos.label} (\m) - \l >>>

      UNAUTHORIZED ACCESS TO THIS DEVICE IS PROHIBITED

       You must have explicit, authorized permission to access or configure this
       device. Unauthorized attempts and actions to access or use this system may
       result in civil and/or criminal penalties.

       All activities performed on this device are logged and monitored.
    '';

    environment.systemPackages = with pkgs; [
      lynis
      powertop
      btop
    ];
  };
}
