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
    // NOTE(fork): the checkout this build came from. Its HEAD says what the shell already has, which
    // is not the same question as what it last saw on GitHub.
    readonly property string repoPath: ShellUpdater.repoPath

    // Title of the "new commit" toast; the toast list recognises it to open the Updates page when it is clicked
    readonly property string toastTitle: Tr.tr("Update available")

    property string lastSeenSha
    property bool loaded: false
    property bool checkPending: false
    // The commit and its subject waiting on the checkout check below
    property string pendingSha
    property string pendingSummary

    // Remember what GitHub last reported, whether or not it was announced
    function remember(sha: string): void {
        lastSeenSha = sha;
        shaSaveTimer.restart();
    }

    // NOTE(fork): a commit is only news if this build does not already have it. Comparing it with
    // the previous check alone announced an update right after a push and rebuild that had already
    // put the shell on that very commit. The checkout's HEAD answers it, and when git cannot tell
    // (no checkout, commit never fetched) the commit is still announced rather than dropped.
    function announce(sha: string, summary: string): void {
        pendingSha = sha;
        pendingSummary = summary;
        repoProc.command = ["git", "-C", repoPath, "merge-base", "--is-ancestor", sha, "HEAD"];
        repoProc.running = true;
    }

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

            if (root.loaded && root.lastSeenSha && sha !== root.lastSeenSha && GlobalConfig.utilities.toasts.repoUpdateAvailable)
                root.announce(sha, json.commit?.message?.split("\n")[0] ?? "");
            else
                root.remember(sha);
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

    // 0: the checkout already contains that commit, so the build is not missing anything. 1: it does
    // not, so it is news. Anything else means git could not answer, which counts as news too.
    Process {
        id: repoProc

        onExited: (code, status) => {
            if (code !== 0 && root.pendingSha) {
                const what = root.pendingSummary ? Tr.tr("New commit on %1: %2").arg(root.repo).arg(root.pendingSummary) : Tr.tr("New commit on %1").arg(root.repo);
                Toaster.toast(root.toastTitle, `${what}\n${Tr.tr("Click to open Settings > Updates")}`, "update", Toast.Info, 10000);
            }

            if (root.pendingSha)
                root.remember(root.pendingSha);
            root.pendingSha = "";
            root.pendingSummary = "";
        }
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
