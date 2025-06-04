{ inputs, ... }:
{
  imports = [
    inputs.hardware.nixosModules.common-cpu-intel

    ./hardware-configuration.nix
  ];

  rs-homelab = {
    bootDrive = "by-id/nvme-KINGSTON_OM3PGP41024P-A0_50026B7283642E53";
    server.enable = true;
    kubernetes = {
      enable = false;
      apiServerIPv4 = "10.0.0.10";
      apiServerHostname = "kube-api";
      apiServerDomain = "home.ryanseipp.local";
    };
  };

  networking = {
    hostId = "d114d530";

    hostName = "kube-host-1";
    domain = "home.ryanseipp.local";

    useNetworkd = true;

    interfaces.enp87s0 = {
      ipv4.addresses = [
        {
          address = "10.0.0.10";
          prefixLength = 16;
        }
      ];
    };

    defaultGateway = {
      address = "10.0.0.1";
      interface = "enp87s0";
    };
  };

  boot.loader.efi.canTouchEfiVariables = true;

  system.stateVersion = "24.11";
}
