#include "musictags.hpp"

#include <qfile.h>
#include <qfuture.h>
#include <qloggingcategory.h>
#include <qtconcurrentrun.h>

#include <taglib/fileref.h>
#include <taglib/tag.h>

namespace {

Q_LOGGING_CATEGORY(lcMusicTags, "caelestia.musictags", QtInfoMsg)

QString tagString(const TagLib::String& value) {
    return QString::fromStdString(value.to8Bit(true));
}

} // namespace

namespace caelestia::models {

using Qt::StringLiterals::operator""_s;

MusicTags::MusicTags(QObject* parent)
    : QObject(parent) {}

QVariantMap MusicTags::tags() const {
    return m_tags;
}

bool MusicTags::scanning() const {
    return m_scanning;
}

int MusicTags::scanned() const {
    return m_scanned;
}

void MusicTags::scan(const QStringList& paths) {
    if (paths.isEmpty()) {
        return;
    }

    // Either already reading these files or finished reading them. Tags changing underneath
    // an unchanged file is not worth a rescan; a library that actually changed hands over a
    // different set of paths and lands here again.
    if (paths == m_requested) {
        return;
    }

    m_requested = paths;
    const quint64 generation = ++m_generation;
    const int count = static_cast<int>(paths.size());

    setScanning(true);

    QtConcurrent::run(&MusicTags::read, paths).then(this, [this, generation, count](const QVariantMap& result) {
        // A newer scan started while this one ran, so its results are the ones that count
        if (generation != m_generation) {
            return;
        }

        // Merge rather than replace, so the files this scan didn't read (or hadn't reached
        // yet) keep whatever was already known about them, and drop anything that is no
        // longer in the library
        QVariantMap merged;
        for (const QString& path : m_requested) {
            const auto existing = m_tags.constFind(path);
            if (existing != m_tags.constEnd()) {
                merged.insert(path, *existing);
            }
        }
        for (auto it = result.constBegin(); it != result.constEnd(); ++it) {
            merged.insert(it.key(), it.value());
        }

        m_tags = merged;
        m_scanned = count;
        setScanning(false);

        qCDebug(lcMusicTags) << "read tags for" << count << "files," << result.size() << "of them tagged";
        emit tagsChanged();
    });
}

QVariantMap MusicTags::tagsFor(const QString& path) const {
    return m_tags.value(path).toMap();
}

QString MusicTags::artistOf(const QString& path) const {
    return tagsFor(path).value(u"artist"_s).toString();
}

QString MusicTags::titleOf(const QString& path) const {
    return tagsFor(path).value(u"title"_s).toString();
}

void MusicTags::setScanning(bool scanning) {
    if (m_scanning == scanning) {
        return;
    }

    m_scanning = scanning;
    emit scanningChanged();
}

QVariantMap MusicTags::read(const QStringList& paths) {
    QVariantMap tags;

    for (const QString& path : paths) {
        const TagLib::FileRef file(path.toUtf8().constData());
        const TagLib::Tag* tag = file.isNull() ? nullptr : file.tag();
        if (tag == nullptr) {
            continue;
        }

        QVariantMap entry;
        const QString artist = tagString(tag->artist()).trimmed();
        const QString title = tagString(tag->title()).trimmed();
        const QString album = tagString(tag->album()).trimmed();
        if (!artist.isEmpty()) {
            entry.insert(u"artist"_s, artist);
        }
        if (!title.isEmpty()) {
            entry.insert(u"title"_s, title);
        }
        if (!album.isEmpty()) {
            entry.insert(u"album"_s, album);
        }

        if (!entry.isEmpty()) {
            tags.insert(path, entry);
        }
    }

    return tags;
}

} // namespace caelestia::models
