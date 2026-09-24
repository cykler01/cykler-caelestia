#pragma once

#include <qhash.h>
#include <qobject.h>
#include <qqmlintegration.h>
#include <qvariantmap.h>

namespace caelestia::models {

// NOTE(fork): reads artist/title/album out of audio files, which is what lets the music
// library group tracks by artist instead of by the folder they happen to sit in. TagLib
// reads a file's header rather than decoding it, so a whole library is a fraction of a
// second - but it is still done off the UI thread, since a big enough library is not.
class MusicTags : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    // Every file that has been read, keyed by absolute path. Each value is a map holding
    // whichever of artist/title/album that file actually carries, so the UI can fall back
    // field by field instead of discarding a track over one missing tag. Files with no
    // tags at all are left out.
    Q_PROPERTY(QVariantMap tags READ tags NOTIFY tagsChanged)
    Q_PROPERTY(bool scanning READ scanning NOTIFY scanningChanged)
    // How many files the last finished scan read, so the UI can tell "still reading" from
    // "read everything and none of it is tagged"
    Q_PROPERTY(int scanned READ scanned NOTIFY tagsChanged)

public:
    explicit MusicTags(QObject* parent = nullptr);

    [[nodiscard]] QVariantMap tags() const;
    [[nodiscard]] bool scanning() const;
    [[nodiscard]] int scanned() const;

    // Reads these files' tags in the background. Asking again for the set that is already
    // being read, or that has already been read, does nothing at all.
    Q_INVOKABLE void scan(const QStringList& paths);

    [[nodiscard]] Q_INVOKABLE QVariantMap tagsFor(const QString& path) const;
    [[nodiscard]] Q_INVOKABLE QString artistOf(const QString& path) const;
    // The track's own title, or - when it has none - nothing, so the caller can decide what
    // to show in its place rather than being handed a file name it can't tell apart from one
    Q_INVOKABLE QString titleOf(const QString& path) const;

signals:
    void tagsChanged();
    void scanningChanged();

private:
    QVariantMap m_tags;
    // The set the current/last scan was asked for, so repeats are free
    QStringList m_requested;
    quint64 m_generation{0};
    int m_scanned{0};
    bool m_scanning{false};

    void setScanning(bool scanning);
    static QVariantMap read(const QStringList& paths);
};

} // namespace caelestia::models
