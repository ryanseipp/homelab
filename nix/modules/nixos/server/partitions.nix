{
  lib,
  config,
  ...
}:
let
  cfg = config.rs-homelab;
in
{
  options = {
    rs-homelab.bootDrive = lib.mkOption {
      type = lib.types.str;
      default = "nvme1n1";
      example = "by-id/nvme-KINGSTON_OM3PGP41024P-A0_50026B7283642E53";
      description = "The boot drive of the system. It's best to use a disk ID as PCIe names can change.";
    };
  };

  config = {
    disko.devices = {
      disk = {
        main = {
          type = "disk";
          device = "/dev/disk/" + cfg.bootDrive;
          content = {
            type = "gpt";
            partitions = {
              ESP = {
                size = "1G";
                type = "EF00";
                content = {
                  type = "filesystem";
                  format = "vfat";
                  mountpoint = "/boot";
                  mountOptions = [ "umask=0077" ];
                };
              };
              root = {
                size = "100%";
                type = "8300";
                content = {
                  type = "luks";
                  name = "luks-rpool";
                  initrdUnlock = true;
                  passwordFile = "/tmp/disk-encryption.key";
                  content = {
                    type = "zfs";
                    pool = "rpool";
                  };
                  settings = {
                    allowDiscards = true;
                    crypttabExtraOpts = [
                      "tpm2-device=auto"
                      "tpm2-measure-pcr=yes"
                    ];
                  };
                };
              };
            };
          };
        };
      };

      zpool = {
        rpool = {
          type = "zpool";
          options = {
            ashift = "12";
            autotrim = "on";
          };
          rootFsOptions = {
            acltype = "posixacl";
            canmount = "off";
            dnodesize = "auto";
            normalization = "formD";
            relatime = "on";
            xattr = "sa";
            mountpoint = "none";
          };

          datasets = {
            local = {
              type = "zfs_fs";
              options.mountpoint = "none";
            };
            safe = {
              type = "zfs_fs";
              options.mountpoint = "none";
            };
            "local/root" = {
              type = "zfs_fs";
              mountpoint = "/";
              options."com.sun:auto-snapshot" = "false";
              postCreateHook = "zfs list -t snapshot -H -o name | grep -E '^rpool/local/root@blank$' || zfs snapshot rpool/local/root@blank";
            };
            "local/nix" = {
              type = "zfs_fs";
              mountpoint = "/nix";
              options."com.sun:auto-snapshot" = "false";
            };
            "safe/persist" = {
              type = "zfs_fs";
              mountpoint = "/persist";
              options."com.sun:auto-snapshot" = "true";
            };
            "safe/home" = {
              type = "zfs_fs";
              mountpoint = "/home";
              options."com.sun:auto-snapshot" = "true";
            };
          };
        };
      };
    };

    fileSystems."/persist".neededForBoot = true;

    fileSystems."/proc" = {
      device = "proc";
      fsType = "proc";
      options = [
        "defaults"
        "hidepid=2"
      ];
      neededForBoot = true;
    };
  };
}
