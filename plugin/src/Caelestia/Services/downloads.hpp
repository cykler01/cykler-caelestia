#pragma once

#include <qfilesystemwatcher.h>
#include <qhash.h>
#include <qqmlintegration.h>
#include <qtimer.h>
#include <qvariantlist.h>

namespace caelestia::shell::services {

// NOTE(fork): one download in flight, from whichever source knew about it.
struct DownloadItem {
    QString id;
    // "browser" or "steam", which is all the UI needs to pick an icon
    QString kind;
    QString name;
    qint64 done = 0;
    // 0 when the source cannot say - a Chromium part file only grows, it never says how far it
    // has to go, so those show what has arrived and no percentage
    qint64 total = 0;
    qreal speed = 0.0;
    qint64 lastDone = 0;
    qint64 lastAt = 0;
};

/*
 * What is downloading right now, for the notch to show.
 *
 * Neither source can be subscribed to, so both are read off the disk they are already writing to:
 *
 *  - Browsers leave a part file next to the finished one while they work (.crdownload for the
 *    Chromium family, .part for the Firefox one) and rename it away at the end, so the download
 *    directory is the list. Firefox reserves the whole file up front and fills it in, so there the
 *    blocks actually allocated against the apparent size give a real percentage; Chromium just
 *    appends, so those have a size and no total.
 *
 *  - Steam keeps BytesDownloaded and BytesToDownload in each app's manifest and rewrites it as it
 *    goes, across every library folder listed in libraryfolders.vdf.
 *
 * Both are watched rather than polled, so an idle machine costs nothing; the timer below only runs
 * while something is actually downloading, to move the figures between writes and work out a rate.
 */
class Downloads : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    // [{ id, kind, name, done, total, progress, speed }], newest last
    Q_PROPERTY(QVariantList active READ active NOTIFY activeChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY activeChanged)
    Q_PROPERTY(int count READ count NOTIFY activeChanged)
    // The one to show when there is only room for one: the furthest along that knows its total,
    // and the first otherwise
    Q_PROPERTY(QVariantMap primary READ primary NOTIFY activeChanged)
    // Across everything with a known total, 0 to 1; -1 when nothing can say
    Q_PROPERTY(qreal progress READ progress NOTIFY activeChanged)
    Q_PROPERTY(qreal speed READ speed NOTIFY activeChanged)

public:
    explicit Downloads(QObject* parent = nullptr);

    [[nodiscard]] QVariantList active() const;
    [[nodiscard]] bool busy() const;
    [[nodiscard]] int count() const;
    [[nodiscard]] QVariantMap primary() const;
    [[nodiscard]] qreal progress() const;
    [[nodiscard]] qreal speed() const;

    Q_INVOKABLE void refresh();

signals:
    void activeChanged();

private:
    void rescan();
    static void scanBrowser(QHash<QString, DownloadItem>& found);
    static void scanSteam(QHash<QString, DownloadItem>& found);

    void watchPaths();
    void onWatchedChanged();

    [[nodiscard]] static QString downloadDir();
    [[nodiscard]] static QStringList steamAppsDirs();
    [[nodiscard]] static bool steamRunning();
    [[nodiscard]] static QString vdfValue(const QString& text, const QString& key);

    QFileSystemWatcher* m_watcher;
    QTimer* m_pollTimer;
    QTimer* m_debounce;

    QHash<QString, DownloadItem> m_items;
    QVariantList m_active;
};

} // namespace caelestia::shell::services
