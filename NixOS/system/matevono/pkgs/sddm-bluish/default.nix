{
  stdenv,
  fetchFromGitHub,
}: {
  sddm-bluish = stdenv.mkDerivation rec {
    pname = "sddm-theme-bluish";
    version = "6d9c0fe0e54877971f9b56a788ebb2922103ceeb";
    dontBuild = true;
    installPhase = ''
      mkdir -p $out/share/sddm/themes
      cp -aR $src $out/share/sddm/themes/sddm-theme-bluish
    '';
    src =
      fetchFromGitHub
      {
        owner = "mateember";
        repo = "Bluish-Plasma-Themes";
        rev = "6d9c0fe0e54877971f9b56a788ebb2922103ceeb";
        hash = "sha256-B/fyuhKquKBxOl28lf/GHuWcKRH4lQ7X5eUBuNQREpg=";
      };
  };
}
