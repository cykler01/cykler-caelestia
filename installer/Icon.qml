import QtQuick

// a Material Symbol. the variable font is a system dependency (install-deps.sh
// pulls ttf-material-symbols-variable), so no FontLoader here
Text {
    id: icon

    property string name
    property real size: Theme.dp(20)
    property real fill: 0
    property int weight: 400

    text: icon.name
    color: Theme.text
    font.family: "Material Symbols Rounded"
    font.pixelSize: icon.size
    font.variableAxes: ({
        "FILL": icon.fill.toFixed(1),
        "GRAD": Theme.isLight ? 0 : -25,
        "opsz": icon.size,
        "wght": icon.weight
    })
    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter
    renderType: Text.NativeRendering
}
