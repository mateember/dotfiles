{
  config,
  lib,
  ...
}: {
  programs.git = {
    enable = true;
    settings = {
      credential.helper = lib.mkForce "gh";
    };
  };

  #programs.git-credential-oauth.enable = true;
  programs.gh.enable = true;
}
