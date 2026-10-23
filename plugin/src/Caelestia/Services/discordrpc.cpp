#include "discordrpc.hpp"

#include <qcoreapplication.h>
#include <qdatastream.h>
#include <qfileinfo.h>
#include <qjsondocument.h>
#include <qjsonvalue.h>
#include <qloggingcategory.h>
#include <qstringlist.h>
#include <quuid.h>

#include <utility>

namespace {

Q_LOGGING_CATEGORY(lcDiscord, "caelestia.services.discordrpc", QtInfoMsg)

// Every frame in and out is dumped when this is set, so the exact payloads the shell
// sends can be inspected (and compared against another player's) without a debugger.
bool rpcDebug() {
    static const bool enabled = qEnvironmentVariableIsSet("CAELESTIA_DISCORD_DEBUG");
    return enabled;
}

} // namespace

namespace caelestia::shell::services {

using Qt::StringLiterals::operator""_s;

DiscordRpc::DiscordRpc(QObject* parent)
    : QObject(parent)
    , m_socket(new QLocalSocket(this)) {
    m_reconnectTimer.setSingleShot(true);
    m_reconnectTimer.setInterval(5000);
    QObject::connect(&m_reconnectTimer, &QTimer::timeout, this, &DiscordRpc::connectToDiscord);

    QObject::connect(m_socket, &QLocalSocket::connected, this, &DiscordRpc::handleConnected);
    QObject::connect(m_socket, &QLocalSocket::disconnected, this, &DiscordRpc::handleDisconnected);
    QObject::connect(m_socket, &QLocalSocket::readyRead, this, &DiscordRpc::handleReadyRead);
    QObject::connect(m_socket, &QLocalSocket::errorOccurred, this, &DiscordRpc::handleError);
}

QString DiscordRpc::clientId() const {
    return m_clientId;
}

void DiscordRpc::setClientId(const QString& clientId) {
    if (m_clientId == clientId)
        return;

    m_clientId = clientId;
    emit clientIdChanged();

    m_reconnectTimer.stop();
    m_buffer.clear();
    setReady(false);

    if (m_socket->state() != QLocalSocket::UnconnectedState)
        m_socket->abort();

    if (!m_clientId.isEmpty())
        connectToDiscord();
}

bool DiscordRpc::connected() const {
    return m_ready;
}

void DiscordRpc::setActivity(const QVariantMap& activity) {
    m_pendingActivity = QJsonObject::fromVariantMap(activity);
    m_hasPending = true;
    m_clearPending = false;

    if (m_ready)
        flushPending();
}

void DiscordRpc::clearActivity() {
    m_hasPending = false;
    m_clearPending = true;

    if (m_ready)
        flushPending();
}

void DiscordRpc::connectToDiscord() {
    if (m_clientId.isEmpty())
        return;

    // Already connected or mid-connect: nothing to do
    if (m_socket->state() != QLocalSocket::UnconnectedState)
        return;

    const auto path = findSocketPath();
    if (path.isEmpty()) {
        // Discord is not running yet; look again shortly
        m_reconnectTimer.start();
        return;
    }

    qCInfo(lcDiscord) << "Connecting to Discord IPC socket" << path;
    m_socket->connectToServer(path);
}

QString DiscordRpc::findSocketPath() const {
    QStringList dirs;
    const auto runtime = qEnvironmentVariable("XDG_RUNTIME_DIR");
    const auto tmp = qEnvironmentVariable("TMPDIR");

    if (!runtime.isEmpty()) {
        dirs << runtime;
        // Flatpak and Snap slot their own runtimes in here
        dirs << runtime + u"/app/com.discordapp.Discord"_s;
        dirs << runtime + u"/app/com.discordapp.DiscordCanary"_s;
        dirs << runtime + u"/snap.discord"_s;
        dirs << runtime + u"/snap.discord-canary"_s;
    }
    if (!tmp.isEmpty())
        dirs << tmp;
    dirs << u"/tmp"_s;

    for (const auto& dir : std::as_const(dirs)) {
        for (int i = 0; i < 10; i++) {
            const auto path = dir + u"/discord-ipc-"_s + QString::number(i);
            if (QFileInfo::exists(path))
                return path;
        }
    }

    return {};
}

void DiscordRpc::handleConnected() {
    qCInfo(lcDiscord) << "Connected to Discord, sending handshake";

    QJsonObject handshake;
    handshake.insert(u"v"_s, 1);
    handshake.insert(u"client_id"_s, m_clientId);
    writeFrame(Handshake, handshake);
}

void DiscordRpc::handleDisconnected() {
    qCInfo(lcDiscord) << "Disconnected from Discord";

    m_buffer.clear();
    setReady(false);

    if (!m_clientId.isEmpty())
        m_reconnectTimer.start();
}

void DiscordRpc::handleReadyRead() {
    m_buffer += m_socket->readAll();

    while (m_buffer.size() >= 8) {
        const auto* data = reinterpret_cast<const uchar*>(m_buffer.constData());
        const quint32 opcode = static_cast<quint32>(data[0]) | (static_cast<quint32>(data[1]) << 8) | (static_cast<quint32>(data[2]) << 16) | (static_cast<quint32>(data[3]) << 24);
        const quint32 length = static_cast<quint32>(data[4]) | (static_cast<quint32>(data[5]) << 8) | (static_cast<quint32>(data[6]) << 16) | (static_cast<quint32>(data[7]) << 24);

        if (m_buffer.size() < 8 + static_cast<qsizetype>(length))
            break;

        const auto payload = m_buffer.mid(8, static_cast<qsizetype>(length));
        m_buffer.remove(0, 8 + static_cast<qsizetype>(length));
        handleFrame(opcode, payload);
    }
}

void DiscordRpc::handleError(QLocalSocket::LocalSocketError error) {
    qCWarning(lcDiscord) << "Discord IPC socket error:" << error;

    setReady(false);

    if (!m_clientId.isEmpty() && !m_reconnectTimer.isActive())
        m_reconnectTimer.start();
}

void DiscordRpc::handleFrame(quint32 opcode, const QByteArray& payload) {
    if (opcode == Ping) {
        writeFrame(Pong, QJsonDocument::fromJson(payload).object());
        return;
    }

    if (opcode == Close) {
        qCInfo(lcDiscord) << "Discord closed the connection";
        m_socket->disconnectFromServer();
        return;
    }

    if (opcode != Frame)
        return;

    const auto message = QJsonDocument::fromJson(payload).object();
    const auto event = message.value(u"evt"_s).toString();

    if (rpcDebug())
        qCInfo(lcDiscord) << "<-" << QString::fromUtf8(payload);

    if (event == u"READY"_s) {
        qCInfo(lcDiscord) << "Discord RPC handshake accepted";
        setReady(true);
        flushPending();
    } else if (event == u"ERROR"_s) {
        qCWarning(lcDiscord) << "Discord RPC error:" << message.value(u"data"_s).toVariant().toString();
    }
}

void DiscordRpc::writeFrame(quint32 opcode, const QJsonObject& payload) {
    if (m_socket->state() != QLocalSocket::ConnectedState) {
        qCWarning(lcDiscord) << "Cannot write frame, socket is not connected";
        return;
    }

    const auto body = QJsonDocument(payload).toJson(QJsonDocument::Compact);

    if (rpcDebug())
        qCInfo(lcDiscord) << "->" << QString::fromUtf8(body);

    QByteArray frame;
    frame.reserve(8 + body.size());
    QDataStream stream(&frame, QIODevice::WriteOnly);
    stream.setByteOrder(QDataStream::LittleEndian);
    stream << opcode << static_cast<quint32>(body.size());
    frame.append(body);

    m_socket->write(frame);
    m_socket->flush();
}

void DiscordRpc::sendActivity(const QJsonObject& activity) {
    QJsonObject args;
    args.insert(u"pid"_s, QJsonValue(static_cast<double>(QCoreApplication::applicationPid())));
    args.insert(u"activity"_s, activity.isEmpty() ? QJsonValue(QJsonValue::Null) : QJsonValue(activity));

    QJsonObject payload;
    payload.insert(u"cmd"_s, u"SET_ACTIVITY"_s);
    payload.insert(u"args"_s, args);
    payload.insert(u"nonce"_s, QUuid::createUuid().toString(QUuid::WithoutBraces));

    writeFrame(Frame, payload);
}

void DiscordRpc::flushPending() {
    if (!m_ready)
        return;

    if (m_clearPending) {
        m_clearPending = false;
        m_hasPending = false;
        sendActivity({});
        return;
    }

    if (m_hasPending) {
        m_hasPending = false;
        sendActivity(m_pendingActivity);
    }
}

void DiscordRpc::setReady(bool ready) {
    if (m_ready == ready)
        return;

    m_ready = ready;
    emit connectedChanged();
}

} // namespace caelestia::shell::services
