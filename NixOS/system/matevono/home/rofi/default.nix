{config, ...}: {
  xdg.configFile."rofi/colors.rasi".source = ./colors.rasi;
  xdg.configFile."rofi/launcher.rasi".source = ./launcher.rasi;
  xdg.configFile."rofi/powermenu.rasi".source = ./powermenu.rasi;
  xdg.configFile."rofi/powermenu.sh".source = ./powermenu.sh;
}
