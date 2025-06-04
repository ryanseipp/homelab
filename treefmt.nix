{ ... }:
{
  projectRootFile = "flake.nix";
  settings.global.excludes = [
    ".envrc"
    "LICENSE"
    "*.pub"
  ];

  programs = {
    nixfmt.enable = true;

    prettier = {
      enable = true;
      settings.proseWrap = "always";
    };
  };
}
