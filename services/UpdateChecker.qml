pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia
import Caelestia.Config
import Caelestia.I18n
import qs.utils

// Polls GitHub for new commits on the fork this shell is built from and
// toasts once when a commit lands that wasn't there on the previous check
Singleton {
    id: root

    readonly property string repo: "cykler01/cykler-caelestia"
    readonly property string branch: "main"

    // Title of the "new commit" toast; the toast list recognises it to open the Updates page when it is clicked
    readonly property string toastTitle: Tr.tr("Update available")

    property string lastSeenSha
    property bool loaded: false
    property bool checkPending: false

    function check(): void {
        if (checkPending)
            return;

        checkPending = true;

        const url = `https://api.github.com/repos/${repo}/commits/${branch}`;
        const headers = {
            "User-Agent": `caelestia-shell/${CUtils.version} (+https://github.com/${repo})`,
            "Accept": "application/vnd.github+json"
        };

        Requests.get(url, text => {
            checkPending = false;

            let json;
            try {
                json = JSON.parse(text);
            } catch (error) {
                console.warn(lc, `Unable to parse GitHub response: ${error}`);
                return;
            }

            const sha = json.sha;
            if (!sha)
                return;

            if (root.loaded && root.lastSeenSha && sha !== root.lastSeenSha && GlobalConfig.utilities.toasts.repoUpdateAvailable) {
                const summary = json.commit?.message?.split("\n")[0] ?? "";
                const what = summary ? Tr.tr("New commit on %1: %2").arg(root.repo).arg(summary) : Tr.tr("New commit on %1").arg(root.repo);
                Toaster.toast(root.toastTitle, `${what}\n${Tr.tr("Click to open Settings > Updates")}`, "update", Toast.Info, 10000);
            }

            root.lastSeenSha = sha;
            shaSaveTimer.restart();
        }, error => {
            checkPending = false;
            console.warn(lc, `GitHub check failed: ${error}`);
        }, headers);
    }

    Timer {
        interval: 30 * 60 * 1000 // 30 minutes
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.check()
    }

    Timer {
        id: shaSaveTimer

        interval: 1000
        onTriggered: {
            if (root.loaded)
                shaStorage.setText(root.lastSeenSha);
        }
    }

    FileView {
        id: shaStorage

        printErrors: false
        path: `${Paths.cache}/update-checker-sha.txt`
        onLoaded: {
            root.lastSeenSha = text().trim();
            root.loaded = true;
        }
        onLoadFailed: err => {
            root.loaded = true;
            if (err === FileViewError.FileNotFound)
                Qt.callLater(() => setText(""));
            else
                console.warn(lc, `Unable to load cached commit sha: ${err}`);
        }
    }

    LoggingCategory {
        id: lc

        name: "caelestia.qml.services.updatechecker"
        defaultLogLevel: LoggingCategory.Info
    }
}
