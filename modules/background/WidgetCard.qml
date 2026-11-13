pragma ComponentBehavior: Bound

import "../../utils/widgetgrid.js" as WidgetGrid
import QtQuick

// The root of every desktop widget. Each widget lives in widgets/ as its own file with this as its
// root and reads `variant` to decide which of its styles to draw.
//
// A widget's body must not reach outside its own file, which is what lets the same card render in
// both of the places that want it:
//
//   on the desktop  DesktopWidgets.qml sets `gridHost` to itself, and the card looks up its own grid
//                   cell and drag state and sizes and positions itself from them
//   in the picker   WidgetPreview.qml leaves `gridHost` null and sets `variant` and a width, and the
//                   card lays itself out at its natural height with no grid, blur or shadow
//
// Before this split the cards were inline components of DesktopWidgets.qml reading its `root`
// directly, so nothing could draw one anywhere else - which is why the Add-widget list could only
// offer names and never a preview of what you were adding.
DesktopCard {
    id: root

    // The DesktopWidgets instance this card is placed on, or null while being previewed. Everything
    // grid-shaped is read through it, so a preview simply has none of it
    property var gridHost: null

    // Filled in from the model by the Repeater on the desktop; a preview sets them itself
    required property string widgetId
    required property int entryIndex

    readonly property bool preview: !gridHost

    // The cell this card occupies. Null while previewing, which is what every geometry binding below
    // keys off
    readonly property var slot: gridHost ? gridHost.slotFor(entryIndex) : null

    // Which style to draw, from the catalog (utils/WidgetCatalog.qml). On the desktop it is the
    // entry's `type`; a preview assigns it directly, replacing this binding
    property string variant: slot?.type ?? ""

    readonly property bool held: gridHost ? gridHost.heldIndex === entryIndex : false

    // A card that needs the keyboard says so here rather than writing to the shell: the desktop
    // passes it up to the background surface, and a preview ignores it
    signal keyboardWanted(bool wanted)

    // What the card blurs to see through itself: the desktop's wallpaper when placed, and nothing in a
    // preview, which is what turns the blur off there (see DesktopCard.qml)
    wallpaper: gridHost?.wallpaper ?? null

    // Holding a card is how rearranging is reached without going through the settings. Only on a
    // desktop with nothing over it, and never while already rearranging - the drag handles own the
    // press then (see DesktopWidgets.qml)
    holdEnabled: gridHost?.holdToRearrange ?? false
    onLongPressed: {
        if (gridHost?.screenState)
            gridHost.screenState.widgetEdit = true;
    }

    z: held ? 4 : 0

    // Geometry is applied through Bindings rather than plain bindings so that a preview, which has no
    // slot to read, is left with whatever size it was given instead of a binding loop on itself
    Binding {
        target: root
        property: "x"
        when: !root.preview
        value: root.held ? root.gridHost.pointer.x - root.gridHost.grab.x : root.slot.col * WidgetGrid.unit
        restoreMode: Binding.RestoreNone
    }

    Binding {
        target: root
        property: "y"
        when: !root.preview
        value: root.held ? root.gridHost.pointer.y - root.gridHost.grab.y : root.slot.row * WidgetGrid.unit
        restoreMode: Binding.RestoreNone
    }

    Binding {
        target: root
        property: "width"
        when: !root.preview
        value: root.slot.w * WidgetGrid.unit - WidgetGrid.gap
        restoreMode: Binding.RestoreNone
    }

    // Rounded up to the next square: a card whose content needs a little more than its footprint takes
    // a whole extra cell rather than a sliver, which is what keeps the desktop tiling evenly
    Binding {
        target: root
        property: "height"
        when: !root.preview
        value: Math.max(root.slot.h, Math.ceil((root.implicitHeight + WidgetGrid.gap) / WidgetGrid.unit)) * WidgetGrid.unit - WidgetGrid.gap
        restoreMode: Binding.RestoreNone
    }
}
