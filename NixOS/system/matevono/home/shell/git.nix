{config, ...}: {
  programs.git = {
    enable = true;
    userName = "...";
    userEmail = "...";
    extraConfig = {
      credential.helper = "gh";
    };
  };
  
  #programs.git-credential-oauth.enable = true;
  programs.gh.enable = true;
}
