#include "musiccovers.hpp"

#include <qcryptographichash.h>
#include <qdir.h>
#include <qfile.h>
#include <qfileinfo.h>
#include <qfuture.h>
#include <qloggingcategory.h>
#include <qsavefile.h>
#include <qtconcurrentrun.h>

#include <taglib/fileref.h>
#include <taglib/tbytevector.h>
#include <taglib/tlist.h>
#include <taglib/tmap.h>
#include <taglib/tpropertymap.h>
#include <taglib/tvariant.h>

namespace {

Q_LOGGING_CATEGORY(lcMusicCovers, "caelestia.musiccovers", QtInfoMsg)

// Small enough that the UI stays responsive between batches, big enough that a folder of
// a few hundred tracks is not a few hundred separate wakeups
constexpr int k_batchSize = 12;

QString cacheDir() {
    QString cache = qEnvironmentVariable("XDG_CACHE_HOME");
    if (cache.isEmpty())
        cache = QDir::homePath() + QStringLiteral("/.cache");
    return cache + QStringLiteral("/caelestia/musiccovers");
}

QString extensionFor(const QByteArray& data) {
    if (data.startsWith("\x89PNG"))
        return QStringLiteral("png");
    if (data.startsWith("RIFF") && data.mid(8, 4) == "WEBP")
        return QStringLiteral("webp");
    return QStringLiteral("jpg");
}

} // namespace

namespace caelestia::shell::models {

MusicCovers::MusicCovers(QObject* parent)
    : QObject(parent) {}

QVariantMap MusicCovers::covers() const {
    return m_covers;
}

bool MusicCovers::knows(const QString& path) const {
    return m_covers.contains(path);
}

QString MusicCovers::coverOf(const QString& path) const {
    return m_covers.value(path).toString();
}

void MusicCovers::want(const QString& path) {
    if (path.isEmpty() || m_requested.contains(path))
        return;

    m_requested.insert(path);
    m_pending.append(path);
    pump();
}

void MusicCovers::pump() {
    if (m_running || m_pending.isEmpty())
        return;

    m_running = true;

    // The most recently asked for first, since that is what is on screen now
    QStringList batch;
    while (!m_pending.isEmpty() && batch.size() < k_batchSize)
        batch.append(m_pending.takeLast());

    QtConcurrent::run(&MusicCovers::extract, batch).then(this, [this](const QHash<QString, QString>& result) {
        for (auto it = result.constBegin(); it != result.constEnd(); ++it)
            m_covers.insert(it.key(), it.value());

        m_running = false;
        emit coversChanged();
        pump();
    });
}

QHash<QString, QString> MusicCovers::extract(const QStringList& paths) {
    QHash<QString, QString> out;
    for (const QString& path : paths)
        out.insert(path, extractOne(path));
    return out;
}

QString MusicCovers::extractOne(const QString& path) {
    const QFileInfo info(path);
    if (!info.exists())
        return {};

    // Keyed on where the file is and when it last changed, so retagged art is picked up
    QCryptographicHash hash(QCryptographicHash::Sha1);
    hash.addData(path.toUtf8());
    hash.addData(QByteArray::number(info.lastModified().toMSecsSinceEpoch()));
    hash.addData(QByteArray::number(info.size()));
    const QString base = cacheDir() + u'/' + QString::fromLatin1(hash.result().toHex());

    // Written out before, either with art or as a marker that there was none
    for (const QString& ext : { QStringLiteral("jpg"), QStringLiteral("png"), QStringLiteral("webp") }) {
        if (QFile::exists(base + u'.' + ext))
            return base + u'.' + ext;
    }
    if (QFile::exists(base + QStringLiteral(".none")))
        return {};

    QByteArray data;
    {
        TagLib::FileRef file(path.toUtf8().constData());
        if (!file.isNull()) {
            const auto pictures = file.complexProperties("PICTURE");
            // Prefer the front cover when a file carries several pictures
            TagLib::ByteVector first;
            for (const auto& picture : pictures) {
                const TagLib::ByteVector bytes = picture.value("data").toByteVector();
                if (bytes.isEmpty())
                    continue;

                const bool front = picture.value("pictureType").toString() == "Front Cover";
                if (first.isEmpty() || front)
                    first = bytes;
                if (front)
                    break;
            }
            if (!first.isEmpty())
                data = QByteArray(first.data(), static_cast<qsizetype>(first.size()));
        }
    }

    if (!QDir().mkpath(cacheDir()))
        return {};

    if (data.isEmpty()) {
        QFile marker(base + QStringLiteral(".none"));
        if (marker.open(QIODevice::WriteOnly))
            marker.close();
        return {};
    }

    const QString target = base + u'.' + extensionFor(data);
    QSaveFile out(target);
    if (!out.open(QIODevice::WriteOnly) || out.write(data) != data.size() || !out.commit()) {
        qCWarning(lcMusicCovers) << "could not write" << target;
        return {};
    }

    return target;
}

} // namespace caelestia::shell::models
