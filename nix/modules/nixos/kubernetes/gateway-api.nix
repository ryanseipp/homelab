{
  lib,
  config,
  pkgs,
  inputs,
  ...
}:
with lib;
let
  cfg = config.rs-homelab.kubernetes;
  kubelib = inputs.nix-kube-generators.lib { inherit pkgs; };

  experimentalCrdConfigs = tlsHash: [
    {
      name = "tlsroutes";
      hash = tlsHash;
    }
  ];

  mkExperimentalCrdUrl =
    version: crd:
    "https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/${version}/config/crd/experimental/gateway.networking.k8s.io_${crd}.yaml";

  crds =
    version: hash:
    pkgs.lib.pipe
      (pkgs.fetchurl {
        inherit hash;
        url = "https://github.com/kubernetes-sigs/gateway-api/releases/download/${version}/standard-install.yaml";
      })
      [
        builtins.readFile
        kubelib.fromYAML
      ];

  experimentalCrds =
    version: tlsHash:
    pkgs.lib.flatten (
      pkgs.lib.forEach (experimentalCrdConfigs tlsHash) (
        crd:
        pkgs.lib.pipe
          (pkgs.fetchurl {
            url = mkExperimentalCrdUrl version crd.name;
            hash = crd.hash;
          })
          [
            builtins.readFile
            kubelib.fromYAML
          ]
      )
    );

  allCrds =
    version: hash: tlsHash:
    (crds version hash) ++ (experimentalCrds version tlsHash);
  mkGatewayApiCrds =
    version: hash: tlsHash:
    pkgs.lib.foldr (
      manifest: accum: accum // { "${manifest.kind}-${manifest.metadata.name}" = manifest; }
    ) { } (allCrds version hash tlsHash);
in
{
  config = mkIf cfg.enable {
    services.kubernetes.addonManager = {
      enable = true;
      bootstrapAddons =
        mkGatewayApiCrds cfg.gatewayApi.version cfg.gatewayApi.hash
          cfg.gatewayApi.tlsRouteHash;
    };
  };
}
