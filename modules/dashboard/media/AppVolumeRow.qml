pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.utils

// NOTE(fork): one app's row in a list of app volumes: the stream's name and current level over a
// slider that sets that stream's own volume. Shared by the media tab's drawer and the utilities
// card, so both list the same streams the same way.
ColumnLayout {
    id: root

    required property PwNode modelData

    spacing: Tokens.spacing.extraSmall

    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.small

        MaterialIcon {
            text: Icons.getVolumeIcon(root.modelData?.audio?.volume ?? 0, root.modelData?.audio?.muted ?? false)
            color: Colours.palette.m3onSurfaceVariant
            fontStyle: Tokens.font.icon.small
        }

        StyledText {
            Layout.fillWidth: true
            text: Audio.getStreamName(root.modelData)
            font: Tokens.font.body.small
            elide: Text.ElideRight
        }

        StyledText {
            text: Strings.percentOne(root.modelData?.audio?.volume ?? 0)
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
        }
    }

    CustomMouseArea {
        function onWheel(event: WheelEvent): void {
            const step = GlobalConfig.services.audioIncrement;
            const volume = Audio.getStreamVolume(root.modelData);
            Audio.setStreamVolume(root.modelData, volume + (event.angleDelta.y > 0 ? step : -step));
        }

        Layout.fillWidth: true
        implicitHeight: Tokens.padding.medium * 2

        StyledSlider {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            implicitHeight: parent.implicitHeight
            radius: Tokens.rounding.small
            value: root.modelData?.audio?.volume ?? 0
            onInteraction: v => Audio.setStreamVolume(root.modelData, v)
        }
    }
}
