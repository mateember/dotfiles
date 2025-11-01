{config, ...}: {
  programs.git = {
    enable = true;
    settings = {
      credential.helper = "gh";
      user.name = "...";
      user.email = "...";
    };
  };

  #programs.git-credential-oauth.enable = true;
  programs.gh.enable = true;
}
