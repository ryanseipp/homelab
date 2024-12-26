{
  lib,
  config,
  ...
}: let
  cfg = config.rs-homelab.server.ssh;
in {
  options = {
    rs-homelab.server.ssh.enable = lib.mkEnableOption "Enables openssh server";
  };

  config = lib.mkIf cfg.enable {
    services.openssh = {
      enable = true;
      allowSFTP = false;
      ports = [22];
      openFirewall = false;

      banner = ''
        UNAUTHORIZED ACCESS TO THIS DEVICE IS PROHIBITED

         You must have explicit, authorized permission to access or configure this
         device. Unauthorized attempts and actions to access or use this system may
         result in civil and/or criminal penalties.

         All activities performed on this device are logged and monitored.
      '';

      # https://infosec.mozilla.org/guidelines/openssh#modern-openssh-67
      settings = {
        LogLevel = "VERBOSE";
        PermitRootLogin = "no";
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = true;

        KexAlgorithms = [
          "curve25519-sha256@libssh.org"
          "ecdh-sha2-nistp521"
          "ecdh-sha2-nistp384"
          "ecdh-sha2-nistp256"
          "diffie-hellman-group-exchange-sha256"
        ];
        Ciphers = [
          "chacha20-poly1305@openssh.com"
          "aes256-gcm@openssh.com"
          "aes128-gcm@openssh.com"
          "aes256-ctr"
          "aes192-ctr"
          "aes128-ctr"
        ];
        Macs = [
          "hmac-sha2-512-etm@openssh.com"
          "hmac-sha2-256-etm@openssh.com"
          "umac-128-etm@openssh.com"
          "hmac-sha2-512"
          "hmac-sha2-256"
          "umac-128@openssh.com"
        ];
      };

      hostKeys = [
        {
          path = "/etc/ssh/ssh_host_ed25519_key";
          type = "ed25519";
        }
        {
          path = "/etc/ssh/ssh_host_rsa_key";
          type = "rsa";
          bits = "4096";
        }
      ];

      extraConfig = ''
        ClientAliveCountMax 0
        ClientAliveInterval 300

        AllowTcpForwarding no
        AllowAgentForwarding no
        MaxAuthTries 3
        MaxSessions 2
        TCPKeepAlive no
      '';
    };

    environment.persistence."/persist".files = [
      "/etc/ssh/ssh_host_ed25519_key"
      "/etc/ssh/ssh_host_ed25519_key.pub"
      "/etc/ssh/ssh_host_rsa_key"
      "/etc/ssh/ssh_host_rsa_key.pub"
    ];

    services.fail2ban = {
      enable = true;
      maxretry = 10;
      bantime-increment.enable = true;
    };

    networking.firewall =
      lib.mkIf (!config.networking.nftables.enable) {
        extraCommands = ''
          iptables -A INPUT -s 10.0.0.0/24 -m state --state NEW -p tcp -dport 22 -j ACCEPT
          ip6tables -A INPUT -s 2601:547:e01:8c0::/64 -m tcp -p tcp -dport 22 -j ACCEPT
        '';
      }
      // lib.mkIf config.networking.nftables.enable {
        extraInputRules = ''
          ip saddr 10.0.0.0/24 tcp dport 22 accept comment "SSH local access"
          ip6 saddr 2601:547:e01:8c0::/64 tcp dport 22 accept comment "SSH local access"
        '';
      };

    # CLI tools to debug with
    environment.systemPackages = [
      config.services.openssh.package
    ];
  };
}
