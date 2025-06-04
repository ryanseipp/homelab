{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.rs-homelab.server.defaultUsers;
in
{
  options = {
    rs-homelab.server.defaultUsers.enable = lib.mkEnableOption "setup default users";
  };

  config = lib.mkIf cfg.enable {
    nix.settings.trusted-users = [ "@wheel" ];
    security.sudo.execWheelOnly = true;
    programs.zsh.enable = true;
    programs.starship.enable = true;
    users.defaultUserShell = pkgs.zsh;

    users.mutableUsers = false;

    users.users.root = {
      hashedPassword = "$y$jET$xiH4z.9q5TNeig8cLyQ34.$SOneivdvYHcWn10lg1bNrti435xSJlbLLgr.iGy1nV9";
      openssh.authorizedKeys.keyFiles = [
        ./keys/rseipp_id_ed25519_sk.pub
        ./keys/rseipp_id_ed25519_sk2.pub
      ];
    };

    users.users.zorbik = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
      hashedPassword = "$y$jET$L5OyG4UiFeQQZrGNdRAnA.$ZT/tSZFLo.QT45VmnCnrJdOjkBbsIjcC4Za724PolU/";
      openssh.authorizedKeys.keyFiles = [
        ./keys/rseipp_id_ed25519_sk.pub
        ./keys/rseipp_id_ed25519_sk2.pub
      ];
    };

    environment.systemPackages = with pkgs; [
      bat
      eza
      fd
      ripgrep
    ];
  };
}
