{
  stdenv,
  fetchFromGitHub,
}: {
  sddm-sugarcandy = stdenv.mkDerivation rec {
    pname = "sddm-theme-sugarcandy";
    version = "8d7fe15d9df";
    dontBuild = true;
    installPhase = ''
      mkdir -p $out/share/sddm/themes
      cp -aR $src/sddm $out/share/sddm/themes/sddm-theme-sugarcandy
    '';
    src =
      fetchFromGitHub
      {
        owner = "EliverLara";
        repo = "Andromeda-KDE";
        rev = "8d7fe15d9df526367abfb8ed71e0f0bbaeb32344";
        sha256 = "013n7y1vyz7y86kdg7cx3j3jz27bb3799rr7q3bs4zx10gd12y4p";
      };
  };
}
