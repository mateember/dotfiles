{config, ...}: {
  programs.git = {
    enable = true;
    userName = "...";
    userEmail = "...";
  };
  #programs.git-credential-oauth.enable = true;
  programs.gh.enable = true;
}
