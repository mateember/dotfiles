{config, ...}: {
  xdg.configFile."waybar/config.jsonc".source = ./config.jsonc;
  xdg.configFile."waybar/modules.jsonc".source = ./modules.jsonc;
  xdg.configFile."waybar/style.css".source = ./style.css;
  xdg.configFile."waybar/config-sway.jsonc".source = ./config-sway.jsonc;
  xdg.configFile."waybar/style-sway.css".source = ./style-sway.css;
}
