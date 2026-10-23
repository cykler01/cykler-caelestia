#pragma once

#include <qbytearray.h>
#include <qjsonobject.h>
#include <qlocalsocket.h>
#include <qobject.h>
#include <qqmlintegration.h>
#include <qstring.h>
#include <qtimer.h>
#include <qvariantmap.h>

namespace caelestia::shell::services {

// NOTE(fork): a client for Discord's local IPC rich presence. Discord listens on a
// unix socket (discord-ipc-0..9) and speaks small binary-framed JSON messages, so this
// connects, does the handshake and pushes SET_ACTIVITY payloads built by the QML side.
// The last activity is remembered and sent once the handshake is accepted, so callers
// can just hand over whatever is playing without worrying about Discord being open yet.
class DiscordRpc : public QObject {
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QString clientId READ clientId WRITE setClientId NOTIFY clientIdChanged)
    Q_PROPERTY(bool connected READ connected NOTIFY connectedChanged)

public:
    explicit DiscordRpc(QObject* parent = nullptr);

    [[nodiscard]] QString clientId() const;
    void setClientId(const QString& clientId);

    [[nodiscard]] bool connected() const;

    Q_INVOKABLE void setActivity(const QVariantMap& activity);
    Q_INVOKABLE void clearActivity();

signals:
    void clientIdChanged();
    void connectedChanged();

private:
    // Discord IPC opcodes
    enum Opcode : quint32 {
        Handshake = 0,
        Frame = 1,
        Close = 2,
        Ping = 3,
        Pong = 4,
    };

    QString m_clientId;
    QLocalSocket* m_socket;
    QTimer m_reconnectTimer;
    QByteArray m_buffer;
    QJsonObject m_pendingActivity;
    bool m_hasPending = false;
    bool m_clearPending = false;
    bool m_ready = false;

    void connectToDiscord();
    [[nodiscard]] QString findSocketPath() const;

    void handleConnected();
    void handleDisconnected();
    void handleReadyRead();
    void handleError(QLocalSocket::LocalSocketError error);
    void handleFrame(quint32 opcode, const QByteArray& payload);

    void writeFrame(quint32 opcode, const QJsonObject& payload);
    void sendActivity(const QJsonObject& activity);
    void flushPending();
    void setReady(bool ready);
};

} // namespace caelestia::shell::services
