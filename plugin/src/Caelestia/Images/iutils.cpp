#include "iutils.hpp"

#include <qbytearrayview.h>
#include <qcryptographichash.h>
#include <qdir.h>
#include <qfile.h>
#include <qimage.h>
#include <qloggingcategory.h>
#include <qsavefile.h>
#include <qstandardpaths.h>

namespace {

Q_LOGGING_CATEGORY(lcIUtils, "caelestia.images.utils", QtInfoMsg)

using Qt::StringLiterals::operator""_s;

QString cacheDir() {
    return QStandardPaths::writableLocation(QStandardPaths::GenericCacheLocation) + u"/caelestia/multimedia/art"_s;
}

} // namespace

namespace caelestia::shell::images {

IUtils::IUtils(QObject* parent)
    : QObject(parent) {}

QString IUtils::saveImageToCache(const QVariant& image) {
    if (!image.canConvert<QImage>())
        return {};

    QImage img = image.value<QImage>();
    if (img.isNull())
        return {};

    // Normalised first so the same artwork hashes the same whatever it arrived as
    img = img.convertToFormat(QImage::Format_ARGB32);

    QCryptographicHash hash(QCryptographicHash::Sha256);
    hash.addData(QByteArrayView(reinterpret_cast<const char*>(img.constBits()), img.sizeInBytes()));
    const QString sha = QString::fromLatin1(hash.result().toHex());

    const QString path = cacheDir() + u'/' + sha + u"-art.png"_s;
    if (QFile::exists(path))
        return path;

    if (!QDir().mkpath(cacheDir())) {
        qCWarning(lcIUtils).noquote() << "Failed to create cache dir" << cacheDir();
        return {};
    }

    QSaveFile file(path);
    if (!file.open(QIODevice::WriteOnly) || !img.save(&file, "PNG") || !file.commit()) {
        qCWarning(lcIUtils).noquote() << "Failed to write" << path;
        return {};
    }

    qCDebug(lcIUtils).noquote() << "Cached embedded cover art to" << path;
    return path;
}

} // namespace caelestia::shell::images
