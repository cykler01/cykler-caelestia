#include "imagecache.hpp"

#include <qcryptographichash.h>
#include <qfile.h>
#include <qfileinfo.h>
#include <qstandardpaths.h>

#include <algorithm>
#include <cmath>

#include "imagecacheworker.hpp"

namespace caelestia::shell::multimedia {

using Qt::StringLiterals::operator""_s;

namespace {

constexpr int k_bucket = 256;
constexpr QStringView k_version = u"1";

QString cacheDir() {
    return QStandardPaths::writableLocation(QStandardPaths::GenericCacheLocation) + u"/caelestia/multimedia/image"_s;
}

int roundUp(int value) {
    return std::max(1, (value + k_bucket - 1) / k_bucket) * k_bucket;
}

} // namespace

ImageCache* ImageCache::instance() {
    static ImageCache s_instance;
    return &s_instance;
}

ImageCache::ImageCache()
    : m_dir(cacheDir())
    , m_worker(new ImageCacheWorker(m_dir)) {
    m_worker->moveToThread(&m_thread);
    QObject::connect(&m_thread, &QThread::finished, m_worker, &QObject::deleteLater);
    m_thread.start(QThread::LowPriority);
    QMetaObject::invokeMethod(m_worker, &ImageCacheWorker::open, Qt::QueuedConnection);
}

ImageCache::~ImageCache() {
    m_thread.quit();
    m_thread.wait();
}

QSize ImageCache::bucketFor(const QSize& devicePixels) {
    if (devicePixels.isEmpty())
        return {};

    // Only the width is snapped to the bucket grid; the height is derived from the requested aspect ratio. Snapping
    // both edges rounds them up by different amounts, so the bucket ends up with a different shape to the source
    // size, and an image cropped to fit the bucket then has to be cropped again to fit the screen - a needless zoom
    // on top of the one the bucket already applied. Deriving the height from the aspect ratio keeps the two crops
    // aligned, so a wallpaper whose shape matches the screen is shown in full.
    const auto width = roundUp(devicePixels.width());
    const auto height = std::max(1,
        static_cast<int>(std::lround(static_cast<qreal>(width) * devicePixels.height() / devicePixels.width())));
    return { width, height };
}

QString ImageCache::keyFor(const QString& path, const QSize& bucket, Qt::AspectRatioMode mode) {
    const QFileInfo info(path);
    if (!info.exists())
        return {};

    const auto raw = u"%1|%2|%3|%4x%5|%6|%7"_s.arg(info.absoluteFilePath(),
        QString::number(info.lastModified().toSecsSinceEpoch()), QString::number(info.size()),
        QString::number(bucket.width()), QString::number(bucket.height()), QString::number(mode), k_version.toString());
    return QString::fromLatin1(QCryptographicHash::hash(raw.toUtf8(), QCryptographicHash::Sha256).toHex());
}

QUrl ImageCache::lookup(const QString& key) const {
    if (key.isEmpty())
        return {};

    const auto path = m_dir + u'/' + key + u".ktx"_s;
    if (!QFile::exists(path))
        return {};

    QMetaObject::invokeMethod(
        m_worker,
        [worker = m_worker, key] {
            worker->touch(key);
        },
        Qt::QueuedConnection);
    return QUrl::fromLocalFile(path);
}

void ImageCache::store(const QString& key, const QString& path, const QSize& bucket, Qt::AspectRatioMode mode) {
    if (key.isEmpty())
        return;

    QMetaObject::invokeMethod(
        m_worker,
        [worker = m_worker, key, path, bucket, mode] {
            worker->storeFile(key, path, bucket, mode);
        },
        Qt::QueuedConnection);
}

void ImageCache::store(const QString& key, const QImage& image, const QSize& bucket, Qt::AspectRatioMode mode) {
    if (key.isEmpty())
        return;

    QMetaObject::invokeMethod(
        m_worker,
        [worker = m_worker, key, image, bucket, mode] {
            worker->storeImage(key, image, bucket, mode);
        },
        Qt::QueuedConnection);
}

} // namespace caelestia::shell::multimedia
