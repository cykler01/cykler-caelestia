#include "downloads.hpp"

#include <qdatetime.h>
#include <qdir.h>
#include <qdiriterator.h>
#include <qfile.h>
#include <qfileinfo.h>
#include <qloggingcategory.h>
#include <qregularexpression.h>
#include <qstandardpaths.h>

#include <sys/stat.h>

namespace {

Q_LOGGING_CATEGORY(lcDownloads, "caelestia.downloads", QtInfoMsg)

} // namespace

namespace caelestia::shell::services {

using Qt::StringLiterals::operator""_s;

namespace {

// Long enough that a burst of writes to one manifest is read once, short enough to feel live
constexpr int k_debounceMs = 250;
constexpr int k_pollMs = 1000;
// Below this the speed reads as noise between two writes, so the previous figure is kept
constexpr qint64 k_minSpeedWindowMs = 400;

// A part file whose blocks on disk fall this far short of its apparent size was reserved whole up
// front (Firefox does this), so the shortfall is what is left to fetch rather than a sparse file
// nobody is writing
constexpr qreal k_preallocRatio = 0.97;

/*
 * Steam's StateFlags, of which only two mean bytes are moving right now:
 *   4   fully installed      256  update running
 *   2   update required      512  update paused      1024  update started
 *
 * The byte counts alone are not enough to go on. Steam leaves the last run's BytesToDownload in
 * the manifest after an install finishes and resets BytesDownloaded to 0, so an idle library full
 * of installed games reads as a library full of downloads that never got started. A queued update
 * (6 = installed + update required) and a paused one (518) are not in flight either, so neither
 * is counted.
 */
// StateUpdateRunning | StateUpdateStarted: what a manifest says while an update is under way
constexpr int k_steamDownloading = 256 | 1024;
// StateUpdatePaused | StateUpdateStopping: set alongside the two above while an update is stopped
// rather than running, which is not a download anyone wants told about
constexpr int k_steamNotRunning = 512 | 8388608;

/*
 * Steam only rewrites BytesDownloaded in the manifest when a download pauses or stops, so while one
 * runs the manifest sits at whatever it said last. What does move is the staging directory
 * (steamapps/downloading/<appid>): files are written there as chunks arrive, and the blocks
 * allocated in it track the manifest's own BytesStaged to within a few megabytes. Blocks rather
 * than apparent size, because Steam reserves its files whole up front.
 */
qint64 allocatedBytes(const QString& dirPath) {
    if (!QFileInfo(dirPath).isDir()) {
        return 0;
    }

    qint64 sum = 0;
    QDirIterator it(dirPath, QDir::Files | QDir::NoDotAndDotDot, QDirIterator::Subdirectories);
    while (it.hasNext()) {
        struct stat st {};
        if (::stat(it.next().toUtf8().constData(), &st) == 0) {
            sum += static_cast<qint64>(st.st_blocks) * 512;
        }
    }
    return sum;
}

const QStringList& partSuffixes() {
    static const QStringList k_suffixes{ u"crdownload"_s, u"part"_s, u"download"_s, u"opdownload"_s };
    return k_suffixes;
}

} // namespace

Downloads::Downloads(QObject* parent)
    : QObject(parent)
    , m_watcher(new QFileSystemWatcher(this))
    , m_pollTimer(new QTimer(this))
    , m_debounce(new QTimer(this)) {
    m_debounce->setSingleShot(true);
    m_debounce->setInterval(k_debounceMs);
    QObject::connect(m_debounce, &QTimer::timeout, this, &Downloads::rescan);

    m_pollTimer->setInterval(k_pollMs);
    QObject::connect(m_pollTimer, &QTimer::timeout, this, &Downloads::rescan);

    QObject::connect(m_watcher, &QFileSystemWatcher::directoryChanged, this, &Downloads::onWatchedChanged);
    QObject::connect(m_watcher, &QFileSystemWatcher::fileChanged, this, &Downloads::onWatchedChanged);

    watchPaths();
    rescan();
}

QVariantList Downloads::active() const {
    return m_active;
}

bool Downloads::busy() const {
    return !m_active.isEmpty();
}

int Downloads::count() const {
    return static_cast<int>(m_active.size());
}

QVariantMap Downloads::primary() const {
    if (m_active.isEmpty()) {
        return {};
    }

    QVariantMap best = m_active.first().toMap();
    qreal bestProgress = -1.0;
    for (const auto& entry : m_active) {
        const QVariantMap map = entry.toMap();
        const qreal p = map.value(u"progress"_s).toReal();
        if (p > bestProgress) {
            bestProgress = p;
            best = map;
        }
    }
    return best;
}

qreal Downloads::progress() const {
    qint64 done = 0;
    qint64 total = 0;
    for (const auto& entry : m_active) {
        const QVariantMap map = entry.toMap();
        const qint64 t = map.value(u"total"_s).toLongLong();
        if (t > 0) {
            done += map.value(u"done"_s).toLongLong();
            total += t;
        }
    }
    if (total <= 0) {
        return -1.0;
    }
    return static_cast<qreal>(done) / static_cast<qreal>(total);
}

qreal Downloads::speed() const {
    qreal sum = 0.0;
    for (const auto& entry : m_active) {
        sum += entry.toMap().value(u"speed"_s).toReal();
    }
    return sum;
}

void Downloads::refresh() {
    rescan();
}

void Downloads::onWatchedChanged() {
    // A watch on a file is dropped when it is renamed away, which is exactly how a download ends
    watchPaths();
    m_debounce->start();
}

QString Downloads::downloadDir() {
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::DownloadLocation);
    return dir.isEmpty() ? QDir::homePath() + u"/Downloads"_s : dir;
}

/*
 * Every steamapps directory Steam might write a manifest into: the two well known roots, plus each
 * library listed in libraryfolders.vdf. The roots are usually symlinks onto the same place, so the
 * list is canonicalised and deduplicated rather than scanned twice.
 */
QStringList Downloads::steamAppsDirs() {
    const QString home = QDir::homePath();
    QStringList roots{
        home + u"/.steam/steam/steamapps"_s,
        home + u"/.local/share/Steam/steamapps"_s,
        home + u"/.var/app/com.valvesoftware.Steam/data/Steam/steamapps"_s,
    };

    for (const QString& root : std::as_const(roots)) {
        QFile f(root + u"/libraryfolders.vdf"_s);
        if (!f.open(QIODevice::ReadOnly)) {
            continue;
        }
        const QString text = QString::fromUtf8(f.readAll());

        static const QRegularExpression k_pathRe(uR"RX("path"\s+"([^"]+)")RX"_s);
        auto it = k_pathRe.globalMatch(text);
        while (it.hasNext()) {
            roots.append(it.next().captured(1) + u"/steamapps"_s);
        }
        break;
    }

    QStringList out;
    for (const QString& dir : std::as_const(roots)) {
        const QFileInfo info(dir);
        if (!info.isDir()) {
            continue;
        }
        const QString real = info.canonicalFilePath();
        if (!real.isEmpty() && !out.contains(real)) {
            out.append(real);
        }
    }
    return out;
}

QString Downloads::vdfValue(const QString& text, const QString& key) {
    const QRegularExpression re(u"\""_s + QRegularExpression::escape(key) + uR"RX("\s+"([^"]*)")RX"_s,
        QRegularExpression::CaseInsensitiveOption);
    const auto match = re.match(text);
    return match.hasMatch() ? match.captured(1) : QString();
}

void Downloads::watchPaths() {
    const auto addDir = [this](const QString& dir) {
        if (QFileInfo(dir).isDir() && !m_watcher->directories().contains(dir)) {
            m_watcher->addPath(dir);
        }
    };

    addDir(downloadDir());
    const auto steamDirs = steamAppsDirs();
    for (const QString& dir : steamDirs) {
        addDir(dir);
    }
}

/*
 * A browser leaves its part file in the download directory and renames it away when it is done, so
 * what is in there is what is in flight. Its apparent size is what the browser means it to end up
 * as only when the browser reserved it whole up front; otherwise the file simply grows, and there
 * is no total to report.
 */
void Downloads::scanBrowser(QHash<QString, DownloadItem>& found) {
    QDir dir(downloadDir());
    if (!dir.exists()) {
        return;
    }

    QStringList filters;
    for (const QString& suffix : partSuffixes()) {
        filters.append(u"*."_s + suffix);
    }

    const auto entries = dir.entryInfoList(filters, QDir::Files | QDir::NoDotAndDotDot);
    for (const QFileInfo& info : entries) {
        struct stat st {};
        if (::stat(info.absoluteFilePath().toUtf8().constData(), &st) != 0) {
            continue;
        }

        const qint64 apparent = static_cast<qint64>(st.st_size);
        const qint64 allocated = static_cast<qint64>(st.st_blocks) * 512;

        DownloadItem item;
        item.id = u"file:"_s + info.absoluteFilePath();
        item.kind = u"browser"_s;
        item.name = info.completeBaseName();
        if (apparent > 0 && allocated < static_cast<qint64>(static_cast<qreal>(apparent) * k_preallocRatio)) {
            item.done = allocated;
            item.total = apparent;
        } else {
            item.done = apparent;
            item.total = 0;
        }
        found.insert(item.id, item);
    }
}

// Whether Steam itself is up. A manifest left behind by a download that was interrupted goes on
// saying it is mid-update for as long as it sits there, so without this the notch keeps showing a
// download that stopped when Steam did - and there is nothing to walk the staging directory for
// either, so this is also what keeps a closed Steam from costing anything at all.
bool Downloads::steamRunning() {
    // Steam writes its pid here while it runs, and leaves the file behind when it stops, so the
    // pid in it is checked rather than taken as proof on its own
    QFile pidFile(QDir::homePath() + u"/.steam/steam.pid"_s);
    if (!pidFile.open(QIODevice::ReadOnly)) {
        return false;
    }

    bool ok = false;
    const qint64 pid = QString::fromUtf8(pidFile.readAll()).trimmed().toLongLong(&ok);
    if (!ok || pid <= 0) {
        return false;
    }

    // A pid on its own could have been handed to anything once Steam let go of it, so the process
    // it names has to still be Steam
    QFile comm(u"/proc/%1/comm"_s.arg(pid));
    if (!comm.open(QIODevice::ReadOnly)) {
        return false;
    }
    return QString::fromUtf8(comm.readAll()).trimmed().startsWith(u"steam"_s);
}

void Downloads::scanSteam(QHash<QString, DownloadItem>& found) {
    if (!steamRunning()) {
        return;
    }

    const auto dirs = steamAppsDirs();
    for (const QString& dirPath : dirs) {
        QDir dir(dirPath);
        const auto entries = dir.entryInfoList({ u"appmanifest_*.acf"_s }, QDir::Files | QDir::NoDotAndDotDot);
        for (const QFileInfo& info : entries) {
            QFile f(info.absoluteFilePath());
            if (!f.open(QIODevice::ReadOnly)) {
                continue;
            }
            const QString text = QString::fromUtf8(f.readAll());

            const int flags = vdfValue(text, u"StateFlags"_s).toInt();
            if ((flags & k_steamDownloading) == 0 || (flags & k_steamNotRunning) != 0) {
                continue;
            }

            const qint64 total = vdfValue(text, u"BytesToDownload"_s).toLongLong();
            qint64 done = vdfValue(text, u"BytesDownloaded"_s).toLongLong();
            if (total <= 0 || done >= total) {
                continue;
            }

            // The manifest is stale while the download runs (see allocatedBytes), so take the
            // staging directory's progress as a fraction of what is to be staged, if it is ahead
            const qint64 toStage = vdfValue(text, u"BytesToStage"_s).toLongLong();
            if (toStage > 0) {
                const QString appId = info.completeBaseName().mid(QStringLiteral("appmanifest_").size());
                const qint64 staged = allocatedBytes(dirPath + u"/downloading/"_s + appId);
                const qreal frac = qBound(0.0, static_cast<qreal>(staged) / static_cast<qreal>(toStage), 1.0);
                done = qBound(done, static_cast<qint64>(frac * static_cast<qreal>(total)), total - 1);
            }

            DownloadItem item;
            item.id = u"steam:"_s + info.completeBaseName();
            item.kind = u"steam"_s;
            item.name = vdfValue(text, u"name"_s);
            if (item.name.isEmpty()) {
                item.name = info.completeBaseName();
            }
            item.done = done;
            item.total = total;
            found.insert(item.id, item);
        }
    }
}

void Downloads::rescan() {
    QHash<QString, DownloadItem> found;
    scanBrowser(found);
    scanSteam(found);

    const qint64 now = QDateTime::currentMSecsSinceEpoch();

    // Carry the rate across from the last look, so a download that has only just appeared reports
    // nothing rather than a figure made up from a single sample
    for (auto it = found.begin(); it != found.end(); ++it) {
        const auto prev = m_items.constFind(it.key());
        if (prev == m_items.constEnd()) {
            it->lastDone = it->done;
            it->lastAt = now;
            continue;
        }

        const qint64 dt = now - prev->lastAt;
        if (dt >= k_minSpeedWindowMs && it->done >= prev->lastDone) {
            it->speed = static_cast<qreal>(it->done - prev->lastDone) * 1000.0 / static_cast<qreal>(dt);
            it->lastDone = it->done;
            it->lastAt = now;
        } else {
            it->speed = prev->speed;
            it->lastDone = prev->lastDone;
            it->lastAt = prev->lastAt;
        }
    }

    m_items = found;

    QVariantList list;
    list.reserve(m_items.size());
    for (auto it = m_items.constBegin(); it != m_items.constEnd(); ++it) {
        const qreal prog = it->total > 0 ? static_cast<qreal>(it->done) / static_cast<qreal>(it->total) : -1.0;
        list.append(QVariantMap{
            { u"id"_s, it->id },
            { u"kind"_s, it->kind },
            { u"name"_s, it->name },
            { u"done"_s, it->done },
            { u"total"_s, it->total },
            { u"progress"_s, prog },
            { u"speed"_s, it->speed },
        });
    }

    std::sort(list.begin(), list.end(), [](const QVariant& a, const QVariant& b) {
        return a.toMap().value(u"id"_s).toString() < b.toMap().value(u"id"_s).toString();
    });

    // Nothing to move between writes while nothing is downloading, so the poll stops dead
    if (m_items.isEmpty()) {
        m_pollTimer->stop();
    } else if (!m_pollTimer->isActive()) {
        m_pollTimer->start();
    }

    if (list == m_active) {
        return;
    }

    const bool wasBusy = !m_active.isEmpty();
    m_active = list;
    if (wasBusy != !m_active.isEmpty()) {
        qCDebug(lcDownloads) << (m_active.isEmpty() ? "all downloads finished" : "download started");
    }
    emit activeChanged();
}

} // namespace caelestia::shell::services
