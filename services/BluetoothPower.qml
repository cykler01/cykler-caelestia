pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Caelestia.State

// Keeps the Bluetooth adapter in the power state the user last set. BlueZ does not remember it -
// the adapter comes back on when bluetoothd starts - and the toggles only ever wrote to the
// adapter, so it turned on again after every shell restart and reboot. The last state is kept in
// the shell's persistent state and pushed back to the adapter as soon as it shows up.
Singleton {
    id: root

    readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter

    // Set while the saved state is being written to the adapter, so that the change it causes is
    // not saved straight back as if the user had toggled it
    property bool restoring: false

    function applySaved(): void {
        const adapter = root.adapter;
        if (!adapter)
            return;

        // Nothing has been saved yet: remember the state the adapter is in now rather than
        // forcing a default on the first run
        if (!PersistentState.bluetoothStateKnown) {
            PersistentState.bluetoothStateKnown = true;
            PersistentState.bluetoothEnabled = adapter.enabled;
            return;
        }

        if (adapter.enabled === PersistentState.bluetoothEnabled)
            return;

        root.restoring = true;
        adapter.enabled = PersistentState.bluetoothEnabled;
        root.restoring = false;
    }

    onAdapterChanged: applySaved()

    Component.onCompleted: applySaved()

    Connections {
        function onEnabledChanged(): void {
            if (!root.adapter || root.restoring)
                return;

            PersistentState.bluetoothEnabled = root.adapter.enabled;
            PersistentState.bluetoothStateKnown = true;
        }

        target: root.adapter
    }
}
