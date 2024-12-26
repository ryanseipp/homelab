{inputs, ...}: {
  imports = [
    inputs.hardware.nixosModules.common-cpu-intel

    ./hardware-configuration.nix
  ];

  rs-homelab = {
    bootDrive = "by-id/nvme-KINGSTON_OM3PGP41024P-A0_50026B7283642E53";
    server.enable = true;
  };

  networking = {
    hostId = "d114d530";
    hostName = "kube-host-1";
  };

  boot.loader.efi.canTouchEfiVariables = true;

  system.stateVersion = "24.11";
}
