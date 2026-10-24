import QtQuick
import qs

// Material Symbols glyph. `icon` is the ligature name, e.g. "volume_up".
// Names: https://fonts.google.com/icons
Text {
    id: root

    property string icon: ""
    property bool filled: false
    // Inside the bar (an ancestor sets `barIcons: true`) icons use Theme.barIconSize.
    // Popups are separate windows, so their icons keep Theme.iconSize.
    property real size: {
        for (let p = root.parent; p; p = p.parent)
            if (p.barIcons === true) return Theme.barIconSize;
        return Theme.iconSize;
    }

    text: icon
    color: Theme.text
    font.family: Theme.iconFamily
    font.pixelSize: size
    font.variableAxes: ({ "FILL": root.filled ? 1 : 0, "opsz": Math.max(20, Math.min(48, root.size)) })
    renderType: Text.NativeRendering
    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter
}
