{
  description = "A homelab for testing with Kubernetes";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    nix-kube-generators.url = "github:farcaller/nix-kube-generators";
    hardware.url = "github:NixOS/nixos-hardware";

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
      url = "github:nix-community/lanzaboote/v0.4.1";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };
  };

  outputs = {
    self,
    nixpkgs,
    disko,
    deploy-rs,
    flake-utils,
    lanzaboote,
    impermanence,
    ...
  } @ inputs: let
    inherit (self) outputs;
    lib = nixpkgs.lib;
  in
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {inherit system;};
    in {
      formatter = pkgs.alejandra;

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
          ++ [pkgs.deploy-rs];
      };
    })
    // {
      nixosModules.default = import ./nix/modules;

      nixosConfigurations = {
        kube-host-1 = lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            disko.nixosModules.disko
            lanzaboote.nixosModules.lanzaboote
            impermanence.nixosModules.impermanence
            self.nixosModules.default
            ./nix/hosts/kube-host-1
          ];
          specialArgs = {inherit inputs outputs;};
        };
      };

      deploy.nodes.kube-host-1 = {
        hostname = "10.0.0.175";
        user = "root";
        sshUser = "zorbik";
        sshOpts = ["-i" "~/.ssh/id_ed25519_sk.pub"];
        interactiveSudo = true;

        profiles.system = {
          path = deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.kube-host-1;
        };
      };

      checks = builtins.mapAttrs (system: deployLib: deployLib.deployChecks self.deploy) deploy-rs.lib;
    };
}
