{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.rs-homelab.kubernetes;
in
{
  imports = [
    ./cilium.nix
    ./containerd.nix
    ./gateway-api.nix
  ];

  options.rs-homelab.kubernetes = {
    enable = mkEnableOption "sets up default kubernetes config";

    apiServerIPv4 = mkOption {
      type = types.str;
      description = "The IP of the Kubernetes API Server";
      example = "10.0.1.2";
    };

    apiServerIPv6 = mkOption {
      type = types.str;
      description = "The IP of the Kubernetes API Server";
      example = "2001:db8::1";
    };

    apiServerHostname = mkOption {
      type = types.str;
      description = "The hostname of the Kubernetes API Server";
      example = "k8s-api";
    };

    apiServerDomain = mkOption {
      type = types.str;
      description = "The FQDN of the Kubernetes API Server";
      example = "home.ryanseipp.com";
    };

    apiServerPort = mkOption {
      type = types.int;
      default = 6443;
      description = "The port of the Kubernetes API Server";
      example = 6443;
    };

    apiServerFQDN = mkOption {
      type = types.str;
      default = "${cfg.apiServerHostname}.${cfg.apiServerDomain}";
    };

    systemNode = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Make this host a system node. System nodes run pods in the kube-system
        namespace, as well as other system-critical pods.
      '';
    };

    userNode = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Make this host a user node. User nodes run user applications and
        other services that are not absolutely critical to the operation of
        the cluster, or should be physically isolated from critical pods.
      '';
    };

    gatewayApi = {
      version = mkOption {
        type = types.str;
        description = "Version of Gateway API CRDs to install";
      };
      hash = mkOption {
        type = types.str;
        default = lib.fakeHash;
        description = "Hash of the Gateway API CRDs";
      };
      tlsRouteHash = mkOption {
        type = types.str;
        default = lib.fakeHash;
        description = "Hash of the TlsRoute Gateway API CRD.";
      };
    };
  };

  config = mkIf cfg.enable {
    networking.hosts = {
      "${cfg.apiServerIPv4}" = [
        cfg.apiServerFQDN
        cfg.apiServerHostname
      ];
      "${cfg.apiServerIPv6}" = [
        cfg.apiServerFQDN
        cfg.apiServerHostname
      ];
    };

    services.kubernetes = {
      roles = [
        (optionalString cfg.systemNode "master")
        (optionalString cfg.userNode "node")
      ];
      masterAddress = cfg.apiServerFQDN;
      apiserverAddress = "https://${cfg.apiServerFQDN}:${toString cfg.apiServerPort}";

      clusterCidr = "192.168.0.0/16,fd00::0/112";

      easyCerts = true;

      apiserver = {
        enable = true;
        securePort = cfg.apiServerPort;
        advertiseAddress = cfg.apiServerIPv4;
        serviceClusterIpRange = "10.10.0.0/16,fd00::1:0/112";
        allowPrivileged = true;
      };

      controllerManager = {
        allocateNodeCIDRs = false;
        # extraOpts = "--use-service-account-credentials=false";
      };

      kubelet = {
        enable = true;
        taints."node.cilium.io/agent-not-ready" = {
          value = "";
          effect = "NoSchedule";
        };
      };

      proxy = {
        enable = false;
      };

      scheduler = {
        enable = true;
      };

      addons.dns = {
        enable = true;
      };

      # Can't figure out how to merge existing definition with overrides for ipFamilies
      addonManager.addons.coredns-svc = lib.mkAfter {
        spec = {
          clusterIP = config.services.kubernetes.addons.dns.clusterIp;
          clusterIPs = [
            config.services.kubernetes.addons.dns.clusterIp
            "fd00::1:ffff"
          ];
          ipFamilies = [
            "IPv4"
            "IPv6"
          ];
          ipFamilyPolicy = "PreferDualStack";
          ports = [
            {
              name = "dns";
              port = 53;
              targetPort = "dns";
              protocol = "UDP";
            }
            {
              name = "dns-tcp";
              port = 53;
              targetPort = "dns-tcp";
              protocol = "TCP";
            }
          ];
          selector = {
            k8s-app = "kube-dns";
          };
        };
      };
    };

    environment.etc."cni/net.d".enable = false;

    networking.firewall.allowedTCPPorts = [
      2379 # etcd access
      2380 # etcd access
      6443 # apiserver
      8888 # cfssl
      53
    ];
    networking.firewall.allowedUDPPorts = [ 53 ];

    boot.kernel.sysctl = {
      "net.ipv4.conf.all.forwarding" = true;
      "net.ipv4.conf.default.forwarding" = true;

      "net.ipv6.conf.all.forwarding" = true;
      "net.ipv6.conf.default.forwarding" = true;

      "net.ipv4.conf.all.rp_filter" = false;
      "net.ipv4.conf.*.rp_filter" = false;
    };

    environment.persistence."/persist".directories = [ "/var/lib/kubernetes/secrets" ];

    # CLI tools to debug with
    environment.systemPackages = with pkgs; [
      argocd
      helm
      kubectl
      kubernetes
      k9s
      openssl
    ];
  };
}
