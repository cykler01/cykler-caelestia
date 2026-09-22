#include "iutils.hpp"

#include <qbytearrayview.h>
#include <qcryptographichash.h>
#include <qdir.h>
#include <qfile.h>
#include <qimage.h>
#include <qloggingcategory.h>
#include <qsavefile.h>

#include "cachingimageprovider.hpp"
#include "imagecacher.hpp"

namespace {

Q_LOGGING_CATEGORY(lcIUtils, "caelestia.images.utils", QtInfoMsg)

} // namespace

namespace caelestia::images {

using Qt::StringLiterals::operator""_s;

IUtils::IUtils(QObject* parent)
    : QObject(parent) {}

IUtils* IUtils::create(QQmlEngine* engine, QJSEngine* jsEngine) {
    Q_UNUSED(jsEngine);

    engine->addImageProvider(u"ccache"_s, new CachingImageProvider(CachingImageProvider::FillMode::Crop));
    engine->addImageProvider(u"fcache"_s, new CachingImageProvider(CachingImageProvider::FillMode::Fit));
    engine->addImageProvider(u"scache"_s, new CachingImageProvider(CachingImageProvider::FillMode::Stretch));

    return new IUtils(engine);
}

QUrl IUtils::urlForPath(const QString& path, int fillMode) {
    if (path.isEmpty())
        return {};

    QString prefix;
    switch (fillMode) {
    case 1: // Image.PreserveAspectFit
        prefix = u"fcache"_s;
        break;
    case 2: // Image.PreserveAspectCrop
        prefix = u"ccache"_s;
        break;
    default: // Image.Stretch or any other ones
        prefix = u"scache"_s;
        break;
    }

    QUrl url;
    url.setScheme(u"image"_s);
    url.setHost(prefix);
    url.setPath(path.startsWith(u'/') ? path : u'/' + path);
    return url;
}

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

    const QString path = ImageCacher::cacheDir() + u'/' + sha + u"-art.png"_s;
    if (QFile::exists(path))
        return path;

    if (!QDir().mkpath(ImageCacher::cacheDir())) {
        qCWarning(lcIUtils).noquote() << "Failed to create cache dir" << ImageCacher::cacheDir();
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

} // namespace caelestia::images
