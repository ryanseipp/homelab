{
  description = "A homelab for testing with Kubernetes";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-utils.url = "github:numtide/flake-utils";
    nix-kube-generators.url = "github:farcaller/nix-kube-generators";
    hardware.url = "github:NixOS/nixos-hardware";

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # wipe drive on boot
    impermanence.url = "github:nix-community/impermanence";

    # deploy to remote NixOS machines
    deploy-rs = {
      url = "github:serokell/deploy-rs";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.utils.follows = "flake-utils";
    };

    # disk partitioning
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # secure-boot
    lanzaboote = {
      url = "github:nix-community/lanzaboote";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } (
      { withSystem, ... }:
      {
        imports = [ inputs.treefmt-nix.flakeModule ];
        systems = [
          "x86_64-linux"
          "aarch64-linux"
          "x86_64-darwin"
          "aarch64-darwin"
        ];
        flake = {
          nixosModules.ryanseipp = import ./nix/modules/nixos;

          nixosConfigurations = {
            kube-host-1 = withSystem "x86_64-linux" (
              { config, inputs', ... }:
              inputs.nixpkgs.lib.nixosSystem {
                modules = [
                  inputs.self.nixosModules.ryanseipp
                  inputs.disko.nixosModules.disko
                  inputs.lanzaboote.nixosModules.lanzaboote
                  inputs.impermanence.nixosModules.impermanence
                  ./nix/hosts/kube-host-1
                ];
                specialArgs = {
                  inherit inputs inputs';
                  packages = config.packages;
                };
              }
            );
          };

          deploy.nodes.kube-host-1 = {
            hostname = "kube-host-1";
            user = "root";
            sshUser = "zorbik";
            sshOpts = [
              "-i"
              "~/.ssh/rseipp_id_ed25519_sk"
            ];
            interactiveSudo = true;

            profiles.system = {
              path = inputs.deploy-rs.lib.x86_64-linux.activate.nixos inputs.self.nixosConfigurations.kube-host-1;
            };
          };
        };
        perSystem =
          { pkgs, system, ... }:
          {
            devShells.default = pkgs.mkShell {
              packages =
                (with pkgs; [
                  argocd
                  cilium-cli
                  dig
                  ethtool
                  iputils
                  kubernetes-helm
                  kubectl
                  kubernetes
                  k9s
                  nixos-anywhere
                  sbctl
                  traceroute
                ])
                ++ [ pkgs.deploy-rs ];
            };

            checks = inputs.deploy-rs.lib.${system}.deployChecks inputs.self.deploy;
          };
      }
    );
}
