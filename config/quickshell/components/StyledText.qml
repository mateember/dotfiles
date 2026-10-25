import QtQuick
import qs

// Text in the shell's UI font.
// font.styleName is derived from font.weight because the system font set has many Fira Sans
// variants (Book, Two, Four, Eight, Hair, ...): matching by weight alone picked Light for
// "Normal" and a medium face for "Bold". Matching by style name picks the right face.
Text {
    color: Theme.text
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    verticalAlignment: Text.AlignVCenter
    renderType: Text.NativeRendering

    // Set imperatively (a binding on font.styleName that reads font.weight is a binding loop).
    function syncStyle() {
        const w = font.weight;
        const style = w >= Font.ExtraBold ? "ExtraBold" : w >= Font.Bold ? "Bold" : w >= Font.DemiBold ? "SemiBold"
                    : w >= Font.Medium ? "Medium" : w <= Font.Light ? "Light" : "Regular";
        if (font.styleName !== style) font.styleName = style;
    }
    onFontChanged: syncStyle()
    Component.onCompleted: syncStyle()
}
