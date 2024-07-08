final: prev: {
  linuxPackages = prev.linuxPackages.extend (lpself: lpsuper: {
    xone = lpsuper.xone.overrideAttrs (oldAttrs: rec {
      nativeBuildInputs = oldAttrs.nativeBuildInputs or [] ++ [final.gcc];

      makeFlags =
        oldAttrs.makeFlags
        or []
        ++ [
          "CC=${final.gcc}/bin/gcc"
        ];

      shellHook = ''
        export CC=${final.gcc}/bin/gcc
      '';
    });
  });
}
