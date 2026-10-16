#include "requests.hpp"

#include <qjsvalue.h>
#include <qjsvalueiterator.h>
#include <qloggingcategory.h>
#include <qnetworkaccessmanager.h>
#include <qnetworkcookiejar.h>
#include <qnetworkreply.h>
#include <qnetworkrequest.h>
#include <qqmlengine.h>
#include <qvariant.h>

namespace {

Q_LOGGING_CATEGORY(lcRequests, "caelestia.requests", QtInfoMsg)

} // namespace

namespace caelestia {

using Qt::StringLiterals::operator""_s;
using Qt::StringLiterals::operator""_ba;

namespace {

QVariantMap responseMetadata(const QNetworkReply* reply) {
    QVariantMap headers;

    for (const auto& [name, value] : reply->rawHeaderPairs()) {
        headers.insert(QString::fromLatin1(name).toLower(), QString::fromLatin1(value));
    }

    return {
        { u"statusCode"_s, reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt() },
        { u"headers"_s, headers },
    };
}

} // namespace

Requests::Requests(QObject* parent)
    : QObject(parent)
    , m_manager(new QNetworkAccessManager(this)) {}

QNetworkRequest Requests::buildRequest(const QUrl& url, const QJSValue& headers) {
    QNetworkRequest request(url);
    request.setAttribute(QNetworkRequest::CacheLoadControlAttribute, QNetworkRequest::AlwaysNetwork);
    request.setAttribute(QNetworkRequest::CookieSaveControlAttribute, QNetworkRequest::Manual);
    request.setRawHeader("Cache-Control"_ba, "no-cache, no-store"_ba);
    request.setRawHeader("Pragma"_ba, "no-cache"_ba);
    request.setRawHeader("Connection"_ba, "close"_ba);

    if (headers.isObject()) {
        QJSValueIterator it(headers);
        while (it.hasNext()) {
            it.next();
            request.setRawHeader(it.name().toUtf8(), it.value().toString().toUtf8());
        }
    }

    return request;
}

void Requests::handleReply(QNetworkReply* reply, const QJSValue& onSuccess, const QJSValue& onError) const {
    const QString body = QString::fromUtf8(reply->readAll());

    QJSValue metadata;
    if (auto* engine = qmlEngine(this))
        metadata = engine->toScriptValue(responseMetadata(reply));

    if (reply->error() == QNetworkReply::NoError) {
        onSuccess.call({ body, metadata });
    } else if (onError.isCallable()) {
        QJSValue bodyValue;
        if (auto* engine = qmlEngine(this))
            bodyValue = engine->toScriptValue(body);

        // The body is passed after the metadata so existing handlers, which
        // expect the metadata as the second argument, keep working
        onError.call({ reply->errorString(), metadata, bodyValue });
    } else {
        qCWarning(lcRequests) << reply->errorString();
    }

    reply->deleteLater();
}

void Requests::get(const QUrl& url, const QJSValue& onSuccess, const QJSValue& onError, const QJSValue& headers) const {
    if (!onSuccess.isCallable()) {
        qCWarning(lcRequests) << "get: onSuccess is not callable";
        return;
    }

    auto* reply = m_manager->get(buildRequest(url, headers));
    QObject::connect(reply, &QNetworkReply::finished, this, [this, reply, onSuccess, onError] {
        handleReply(reply, onSuccess, onError);
    });
}

void Requests::post(const QUrl& url, const QString& body, const QJSValue& onSuccess, const QJSValue& onError,
    const QJSValue& headers) const {
    if (!onSuccess.isCallable()) {
        qCWarning(lcRequests) << "post: onSuccess is not callable";
        return;
    }

    auto* reply = m_manager->post(buildRequest(url, headers), body.toUtf8());
    QObject::connect(reply, &QNetworkReply::finished, this, [this, reply, onSuccess, onError] {
        handleReply(reply, onSuccess, onError);
    });
}

void Requests::resetCookies() const {
    m_manager->setCookieJar(new QNetworkCookieJar(m_manager));
}

} // namespace caelestia
