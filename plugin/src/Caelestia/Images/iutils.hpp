#pragma once

#include <qjsengine.h>
#include <qobject.h>
#include <qqmlengine.h>
#include <qqmlintegration.h>
#include <qurl.h>
#include <qvariant.h>

namespace caelestia::images {

class IUtils : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    static IUtils* create(QQmlEngine* engine, QJSEngine* jsEngine);

    Q_INVOKABLE static QUrl urlForPath(const QString& path, int fillMode);

    // NOTE(fork): persists an in-memory image into the image cache and returns its path.
    // QtMultimedia hands embedded cover art over as a QImage, which Image.source cannot
    // take directly, so it goes through here and then back through urlForPath(). The name
    // is derived from the image contents, so the same artwork is only ever written once.
    Q_INVOKABLE static QString saveImageToCache(const QVariant& image);

private:
    explicit IUtils(QObject* parent = nullptr);
};

} // namespace caelestia::images
