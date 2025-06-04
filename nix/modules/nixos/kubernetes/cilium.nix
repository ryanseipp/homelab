{
  lib,
  config,
  inputs,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.rs-homelab.kubernetes;
  kubelib = inputs.nix-kube-generators.lib { inherit pkgs; };

  ciliumChart = kubelib.downloadHelmChart {
    repo = "https://helm.cilium.io/";
    chart = "cilium";
    version = "1.17.2";
    chartHash = "sha256-l+9fEAb2wb9xAx/HCW/pXW5+MfzbgnSpWk7UOTkpK24=";
  };

  mkCiliumAddon =
    args:
    pipe args [
      (
        {
          apiServerHost,
          apiServerPort ? 6443,
        }:
        kubelib.fromHelm {
          name = "cilium";
          chart = ciliumChart;
          namespace = "kube-system";
          values = {
            k8sServiceHost = apiServerHost;
            k8sServicePort = builtins.toString apiServerPort;

            routingMode = "tunnel";
            tunnelProtocol = "vxlan";
            ipv4.enabled = true;
            ipv6.enabled = true;
            ipv4NativeRoutingCIDR = "10.0.0.1/16";
            ipv6NativeRoutingCIDR = "2601:547:e01:8c0::1/64";

            # enableIPv4BIGTCP = true;
            # enableIPv6BIGTCP = true;

            ipam.operator = {
              clusterPoolIPv4PodCIDRList = [ "192.168.0.0/16" ];
              clusterPoolIPv4MaskSize = 24;

              clusterPoolIPv6PodCIDRList = [ "fd00::/112" ];
              clusterPoolIPv6MaskSize = 120;
            };

            kubeProxyReplacement = true;

            bpf = {
              datapathMode = "netkit";
              masquerade = true;
            };

            bandwidthManager = {
              enabled = true;
              bbr = true;
            };

            dnsProxy.enableTransparentMode = false;

            gatewayAPI.enabled = true;

            hubble = {
              relay.enabled = true;
              ui.enabled = true;
            };

            hostFirewall = {
              enabled = true;
            };

            # set back to 2 when we have more nodes
            operator.replicas = 1;
          };
        }
      )
      (foldr (manifest: accum: accum // { "${manifest.kind}-${manifest.metadata.name}" = manifest; }) { })
    ];
in
{
  config = mkIf cfg.enable {
    rs-homelab.kubernetes.gatewayApi = {
      version = mkDefault "v1.2.0";
      hash = mkDefault "sha256-OO0FW7JdxYDANmiZwL7Zuekt/NHBgKVpEz85RgJs8QI=";
      tlsRouteHash = mkDefault "sha256-ifV3+a5VEtCo/aZXzZO0XjO29590q/FtJNH772GUtyw=";
    };

    services.kubernetes = {
      flannel.enable = mkForce false;

      addonManager = {
        enable = true;
        bootstrapAddons = mkCiliumAddon {
          apiServerHost = cfg.apiServerFQDN;
          apiServerPort = cfg.apiServerPort;
        };
      };
    };

    # vxlan overlay
    networking.firewall.allowedUDPPorts = [ 8472 ];
    # health checks
    networking.firewall.allowedTCPPorts = [
      4240
      4244
      4245
    ];
    networking.firewall.checkReversePath = false;
    networking.firewall.logReversePathDrops = true;
    networking.firewall.allowPing = true;

    # Load ipv6 modules for Cilium
    boot.kernelModules = [
      "ip6_tables"
      "ip6table_mangle"
      "ip6table_raw"
      "ip6table_filter"
    ];

    environment.systemPackages = with pkgs; [
      cilium-cli
      hubble
    ];
  };
}
