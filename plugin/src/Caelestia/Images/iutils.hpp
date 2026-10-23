#pragma once

#include <qobject.h>
#include <qqmlintegration.h>
#include <qvariant.h>

namespace caelestia::images {

class IUtils : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    explicit IUtils(QObject* parent = nullptr);

    // NOTE(fork): persists an in-memory image into the image cache and returns its path.
    // QtMultimedia hands embedded cover art over as a QImage, which Image.source cannot
    // take directly, so it goes through here and is then used as a plain file path. The
    // name is derived from the image contents, so the same artwork is only ever written once.
    Q_INVOKABLE static QString saveImageToCache(const QVariant& image);
};

} // namespace caelestia::images
