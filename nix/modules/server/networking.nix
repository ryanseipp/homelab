{
  lib,
  config,
  pkgs,
  ...
}: let
  cfg = config.rs-homelab.server.networking;
  cloudflareNameservers = ["2606:4700:4700::1111" "2606:4700:4700::1001" "1.1.1.1" "1.0.0.1"];
in {
  options = {
    rs-homelab.server.networking.enable = lib.mkEnableOption "Enables common networking settings";
  };

  config = lib.mkIf cfg.enable {
    boot.kernel.sysctl = {
      "net.core.bpf_jit_harden" = 2;

      "net.ipv4.conf.all.accept_redirects" = false;
      "net.ipv4.conf.default.accept_redirects" = false;

      "net.ipv6.conf.all.accept_redirects" = false;
      "net.ipv6.conf.default.accept_redirects" = false;

      "net.ipv4.conf.all.log_martians" = true;
      "net.ipv4.conf.default.log_martians" = true;

      "net.ipv4.conf.all.rp_filter" = true;
      "net.ipv4.conf.all.send_redirects" = false;
    };

    # Disable unused network protocols
    boot.blacklistedKernelModules = [
      "dccp"
      "sctp"
      "rds"
      "tipc"
    ];

    networking = {
      firewall.enable = true;
      nftables.enable = true;
      nameservers = cloudflareNameservers;
    };

    # CLI tools to debug with
    environment.systemPackages = with pkgs; [
      dig
      ethtool
      iputils
      traceroute
    ];
  };
}
