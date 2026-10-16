#pragma once

#include <qnetworkaccessmanager.h>
#include <qobject.h>
#include <qqmlengine.h>

namespace caelestia {

class Requests : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    explicit Requests(QObject* parent = nullptr);

    Q_INVOKABLE void get(const QUrl& url, const QJSValue& onSuccess, const QJSValue& onError = QJSValue(),
        const QJSValue& headers = QJSValue()) const;
    Q_INVOKABLE void post(const QUrl& url, const QString& body, const QJSValue& onSuccess,
        const QJSValue& onError = QJSValue(), const QJSValue& headers = QJSValue()) const;
    Q_INVOKABLE void resetCookies() const;

private:
    QNetworkAccessManager* m_manager;

    [[nodiscard]] static QNetworkRequest buildRequest(const QUrl& url, const QJSValue& headers);
    void handleReply(QNetworkReply* reply, const QJSValue& onSuccess, const QJSValue& onError) const;
};

} // namespace caelestia
