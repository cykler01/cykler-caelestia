#pragma once

#include <qhash.h>
#include <qobject.h>
#include <qqmlintegration.h>
#include <qset.h>
#include <qstringlist.h>
#include <qvariantmap.h>

namespace caelestia::shell::models {

// NOTE(fork): pulls the picture embedded in an audio file (an m4a's covr atom, an mp3's APIC
// frame, a FLAC or Ogg picture block) out to a file in the cache, so the music library can show
// each track's own art rather than guessing from the images that sit next to it. Extraction is
// asked for per track by whatever is on screen, read off the UI thread a few files at a time,
// and remembered on disk, so a folder is only ever read once.
class MusicCovers : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    // Every track that has been looked at, keyed by absolute path. The value is the cached
    // image, or an empty string for a file with no embedded art, so the UI can tell "still
    // looking" (no key) from "nothing there" (empty)
    Q_PROPERTY(QVariantMap covers READ covers NOTIFY coversChanged)

public:
    explicit MusicCovers(QObject* parent = nullptr);

    [[nodiscard]] QVariantMap covers() const;

    // Queues a track for extraction. Free for a track that is already known or already queued.
    Q_INVOKABLE void want(const QString& path);

    // Whether this track has been looked at yet, and what was found: the cached image, or
    // nothing. Cheaper than reading covers from every row that wants one track's answer.
    [[nodiscard]] Q_INVOKABLE bool knows(const QString& path) const;
    [[nodiscard]] Q_INVOKABLE QString coverOf(const QString& path) const;

signals:
    void coversChanged();

private:
    QVariantMap m_covers;
    QStringList m_pending;
    QSet<QString> m_requested;
    bool m_running{ false };

    void pump();
    static QHash<QString, QString> extract(const QStringList& paths);
    static QString extractOne(const QString& path);
};

} // namespace caelestia::shell::models
