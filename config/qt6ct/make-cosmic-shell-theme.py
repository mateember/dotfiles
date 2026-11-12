#!/usr/bin/env python3
"""Generate one Qt colour theme for both qt6ct and KDE apps from the Quickshell palette.

KDE apps (Gwenview, Dolphin, Okular...) ignore qt6ct's palette and take their colours from
~/.config/kdeglobals, so both files have to be written from the same colours to look alike.

Writes:
  ~/.config/qt6ct/colors/CosmicShell.conf          qt6ct palette
  ~/.local/share/color-schemes/CosmicShell.colors  KDE colour scheme
  ~/.config/kdeglobals                             colour groups merged in, other keys kept
  ~/.config/Kvantum/CosmicShell/                   Kvantum widget theme (KvArcDark recoloured)
  ~/.config/Kvantum/kvantum.kvconfig               selects that theme
  ~/.config/qt6ct/qt6ct.conf                       style=kvantum + this colour scheme

Colours come from config/quickshell/Theme.qml (COSMIC Dark). Re-run after changing them.
"""
import configparser
import os

HOME = os.path.expanduser("~")
NAME = "CosmicShell"

# ---- palette, copied from config/quickshell/Theme.qml ----
bg = "#1b1b1b"            # Theme.bg (windows, toolbars)
primary = "#272727"       # Theme.primary (lists, text fields)
secondary = "#343434"     # Theme.secondary (buttons)
alt = "#2e2e2e"           # COSMIC component colour over bg (alternate rows)
hover = "#434343"         # COSMIC component hover over bg
pressed = "#585858"       # COSMIC component pressed over bg
dark = "#141414"
fg = "#eeeeee"            # Theme.fgOnBg
fg_strong = "#ffffff"     # Theme.fgOnPrimary
fg_dim = "#afafaf"        # Theme.textDim (white @ 0.65) over bg
fg_disabled = "#7a7a7a"
accent = "#ffad00"        # Theme.accent
accent_hover = "#e09e14"  # Theme.accentHover
accent_pressed = "#8a610b"  # Theme.accentPressed
on_accent = "#000000"     # Theme.fgOnAccent
destructive = "#ffa09a"
success = "#5edb8c"
warning = "#ffa37d"


def rgb(h):
    return ",".join(str(int(h[i:i + 2], 16)) for i in (1, 3, 5))


def argb(h):
    return "#ff" + h[1:]


# ---- qt6ct: QPalette roles in qt6ct's order ----
def qt_roles(disabled=False):
    text = fg_disabled if disabled else fg
    return [
        text,                                    # WindowText
        secondary,                               # Button
        pressed,                                 # Light
        hover,                                   # Midlight
        dark,                                    # Dark
        alt,                                     # Mid
        text,                                    # Text
        fg_strong,                               # BrightText
        text,                                    # ButtonText
        primary,                                 # Base
        bg,                                      # Window
        "#000000",                               # Shadow
        accent_pressed if disabled else accent,  # Highlight
        bg if disabled else on_accent,           # HighlightedText
        accent,                                  # Link
        accent_hover,                            # LinkVisited
        alt,                                     # AlternateBase
        "#000000",                               # NoRole
        primary,                                 # ToolTipBase
        fg,                                      # ToolTipText
        fg_disabled if disabled else fg_dim,     # PlaceholderText
    ]


def write_qt6ct():
    path = f"{HOME}/.config/qt6ct/colors/{NAME}.conf"
    os.makedirs(os.path.dirname(path), exist_ok=True)
    active = ", ".join(argb(c) for c in qt_roles())
    disabled = ", ".join(argb(c) for c in qt_roles(disabled=True))
    with open(path, "w") as f:
        f.write("[ColorScheme]\n")
        f.write(f"active_colors={active}\n")
        f.write(f"disabled_colors={disabled}\n")
        f.write(f"inactive_colors={active}\n")
    return path


# ---- KDE colour scheme ----
def kde_group(background, alternate, foreground=fg, inactive=fg_dim):
    return {
        "BackgroundNormal": rgb(background),
        "BackgroundAlternate": rgb(alternate),
        "ForegroundNormal": rgb(foreground),
        "ForegroundInactive": rgb(inactive),
        "ForegroundActive": rgb(accent),
        "ForegroundLink": rgb(accent),
        "ForegroundVisited": rgb(accent_hover),
        "ForegroundNegative": rgb(destructive),
        "ForegroundNeutral": rgb(warning),
        "ForegroundPositive": rgb(success),
        "DecorationFocus": rgb(accent),
        "DecorationHover": rgb(accent),
    }


def kde_sections():
    window = kde_group(bg, primary)
    s = {
        "Colors:Window": window,
        "Colors:View": kde_group(primary, alt),
        "Colors:Button": kde_group(secondary, hover),
        "Colors:Selection": kde_group(accent, accent_pressed, on_accent, bg),
        "Colors:Tooltip": kde_group(primary, alt),
        "Colors:Header": window,
        "Colors:Header][Inactive": window,
        "Colors:Complementary": window,
        # Disabled text: fade towards the background (lands near fg_disabled, like qt6ct).
        "ColorEffects:Disabled": {
            "ColorEffect": "0", "ContrastEffect": "1", "ContrastAmount": "0.55",
            "IntensityEffect": "0", "ChangeSelectionColor": "false",
        },
        # Unfocused windows keep the same colours, like qt6ct's inactive palette.
        "ColorEffects:Inactive": {"Enable": "false", "ChangeSelectionColor": "false"},
        "WM": {
            "activeBackground": rgb(bg), "activeForeground": rgb(fg), "activeBlend": rgb(accent),
            "inactiveBackground": rgb(bg), "inactiveForeground": rgb(fg_dim),
            "inactiveBlend": rgb(fg_dim),
        },
    }
    return s


def new_config():
    c = configparser.RawConfigParser(interpolation=None, strict=False)
    c.optionxform = str  # KDE keys are case-sensitive
    return c


def write_kde_scheme():
    path = f"{HOME}/.local/share/color-schemes/{NAME}.colors"
    os.makedirs(os.path.dirname(path), exist_ok=True)
    c = new_config()
    c["General"] = {"Name": "Cosmic Shell", "ColorScheme": NAME}
    for name, keys in kde_sections().items():
        c[name] = keys
    with open(path, "w") as f:
        c.write(f, space_around_delimiters=False)
    return path


def write_kdeglobals():
    path = f"{HOME}/.config/kdeglobals"
    c = new_config()
    c.read(path)
    for name, keys in kde_sections().items():
        if c.has_section(name):
            c.remove_section(name)
        c[name] = keys
    if not c.has_section("General"):
        c["General"] = {}
    c["General"]["ColorScheme"] = NAME
    # Outside Plasma, KDE apps colour their windows from the scheme named in [UiSettings]
    # and fall back to Breeze Light without it (only their list views used the groups above).
    if not c.has_section("UiSettings"):
        c["UiSettings"] = {}
    c["UiSettings"]["ColorScheme"] = NAME
    # KDE apps also take their widget style from here rather than from qt6ct.
    if not c.has_section("KDE"):
        c["KDE"] = {}
    c["KDE"]["widgetStyle"] = "kvantum"
    with open(path, "w") as f:
        c.write(f, space_around_delimiters=False)
    os.chmod(path, 0o600)
    return path


# ---- Kvantum: KvArcDark (ships with Kvantum) recoloured to the palette above ----
KV_BASE = "/run/current-system/sw/share/Kvantum/KvArcDark/KvArcDark"
ARC_ACCENT = "#5294e2"

# Arc's blue-grey surfaces, by luma, mapped onto the shell's neutral greys.
LUMA_MAP = [(0, 0), (17, 10), (36, 20), (47, 24), (59, 27), (68, 39), (73, 52),
            (82, 67), (100, 88), (130, 130), (255, 255)]


def hex_rgb(h):
    return [int(h[i:i + 2], 16) for i in (1, 3, 5)]


def rgb_hex(r, g, b):
    return "#%02x%02x%02x" % tuple(max(0, min(255, round(v))) for v in (r, g, b))


def mix(a, b, t):
    a, b = hex_rgb(a), hex_rgb(b)
    return rgb_hex(*[x + (y - x) * t for x, y in zip(a, b)])


def map_luma(y):
    for (x0, y0), (x1, y1) in zip(LUMA_MAP, LUMA_MAP[1:]):
        if y <= x1:
            return y0 + (y1 - y0) * (y - x0) / (x1 - x0)
    return 255


def recolor(h):
    import colorsys
    r, g, b = hex_rgb(h)
    hue, light, sat = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
    if sat > 0.35 and 190 <= hue * 360 <= 240:      # Arc's blue accent family
        ref = colorsys.rgb_to_hls(*[v / 255 for v in hex_rgb(ARC_ACCENT)])[1]
        if light >= ref:
            return mix(accent, "#ffffff", (light - ref) / (1 - ref) * 0.6)
        return mix(accent_pressed, accent, light / ref)
    if sat > 0.35:                                    # other hues (red/purple marks) stay
        return h
    y = map_luma(0.299 * r + 0.587 * g + 0.114 * b)
    return rgb_hex(y, y, y)


def write_kvantum():
    import re
    d = f"{HOME}/.config/Kvantum/{NAME}"
    os.makedirs(d, exist_ok=True)

    svg = open(KV_BASE + ".svg").read()
    svg = re.sub(r"#[0-9a-fA-F]{6}\b", lambda m: recolor(m.group(0).lower()), svg)
    with open(f"{d}/{NAME}.svg", "w") as f:
        f.write(svg)

    general = {
        "window.color": bg, "base.color": primary, "alt.base.color": alt,
        "button.color": secondary, "light.color": pressed, "mid.light.color": hover,
        "dark.color": dark, "mid.color": alt, "highlight.color": accent,
        "inactive.highlight.color": accent, "text.color": fg, "window.text.color": fg,
        "button.text.color": fg, "disabled.text.color": fg_disabled,
        "tooltip.text.color": fg, "highlight.text.color": on_accent,
        "link.color": accent, "link.visited.color": accent_hover,
        "progress.indicator.text.color": on_accent,
    }
    text = {"#ffffffc8": fg, "#ffffff96": fg_dim, "#ffffff78": fg_disabled,
            "#ffffff73": fg_disabled, "#ffffffb4": fg, "#ffffffd2": fg_strong,
            "#000000b4": fg, "#787878": fg_dim, "#5796e8": accent}
    out, section = [], None
    for line in open(KV_BASE + ".kvconfig").read().splitlines():
        if line.startswith("["):
            section = line
        key, sep, val = line.partition("=")
        if section == "[GeneralColors]" and key in general:
            line = f"{key}={general[key]}"
        elif section == "[%General]" and key in ("author", "comment"):
            line = f"{key}=" + ("generated by make-cosmic-shell-theme.py from KvArcDark"
                                if key == "comment" else "Tsu Jan (KvArcDark)")
        elif sep and key.startswith("text.") and key.endswith(".color"):
            line = f"{key}={text.get(val.lower(), recolor(val) if val.startswith('#') and len(val) == 7 else val)}"
        out.append(line)
    with open(f"{d}/{NAME}.kvconfig", "w") as f:
        f.write("\n".join(out) + "\n")

    with open(f"{HOME}/.config/Kvantum/kvantum.kvconfig", "w") as f:
        f.write(f"[General]\ntheme={NAME}\n")
    return d


def point_qt6ct():
    """Set style, colour scheme and custom palette in qt6ct.conf, leaving other lines alone."""
    import re
    path = f"{HOME}/.config/qt6ct/qt6ct.conf"
    want = {"style": "kvantum", "custom_palette": "true",
            "color_scheme_path": f"{HOME}/.config/qt6ct/colors/{NAME}.conf"}
    try:
        s = open(path).read()
    except FileNotFoundError:
        s = "[Appearance]\n"
    for k, v in want.items():
        if re.search(rf"^{k}=", s, re.M):
            s = re.sub(rf"^{k}=.*$", f"{k}={v}", s, flags=re.M)
        else:
            s = s.replace("[Appearance]\n", f"[Appearance]\n{k}={v}\n", 1)
    with open(path, "w") as f:
        f.write(s)
    return path


if __name__ == "__main__":
    for p in (write_qt6ct(), write_kde_scheme(), write_kdeglobals(), write_kvantum(),
              point_qt6ct()):
        print("wrote", p)
