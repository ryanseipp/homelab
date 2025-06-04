{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:
let
  # Some kernel versions won't be compatible with ZFS
  zfsCompatibleKernelPackages = lib.filterAttrs (
    name: kernelPackages:
    (builtins.match "linux_[0-9]+_[0-9]+" name) != null
    && (builtins.tryEval kernelPackages).success
    && (!kernelPackages.${config.boot.zfs.package.kernelModuleAttribute}.meta.broken)
  ) pkgs.linuxKernel.packages;

  desiredKernelPackage = "linux_6_12";

  # Select the desired kernel version from the list. If it isn't supported, we'll get an error when the configuration is
  # built.
  selectedKernelPackage = lib.attrByPath [ desiredKernelPackage ] null zfsCompatibleKernelPackages;
in
{
  imports = [
    ./server
    ./kubernetes
  ];

  boot.kernelPackages = selectedKernelPackage;

  environment.persistence."/persist" = {
    enable = true;
    directories = [
      "/var/log"
      "/var/lib/nixos"
      "/var/lib/systemd/coredump"
    ];
  };

  nix = {
    channel.enable = false;
    nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
    settings.experimental-features = [
      "nix-command"
      "flakes"
    ];

    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
      persistent = false;
    };

    optimise = {
      automatic = true;
      dates = [ "weekly" ];
    };
  };
}
