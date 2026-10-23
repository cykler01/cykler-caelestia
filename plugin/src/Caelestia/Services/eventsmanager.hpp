#pragma once

#include <qdatetime.h>
#include <qdbusmessage.h>
#include <qobject.h>
#include <qqmlintegration.h>
#include <qstringlist.h>
#include <qvariant.h>

#include "service.hpp"

class QDBusPendingCallWatcher;
class QFileSystemWatcher;

namespace caelestia::shell::services {

// A single calendar incident as exposed to QML: {start, end, summary, colour, calendar}
struct CalendarEvent {
    QDateTime start;
    QDateTime end;
    QString summary;
    QString colour;
    QString calendar;
};

class EventsManager : public Service {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    // Flat list of variants in the watched window. Day grids derive both "day has an
    // event" (day-of-start..day-of-end) and the colour to use from this.
    Q_PROPERTY(QVariantList variants READ variants NOTIFY variantsChanged)
    // yyyy-MM-dd -> colour hex for days covered by any event; last writer wins per day.
    Q_PROPERTY(QVariantMap dayColours READ dayColours NOTIFY variantsChanged)
    // Events came from the gnome-shell CalendarServer D-Bus service rather than the cache.
    Q_PROPERTY(bool usingDbus READ usingDbus NOTIFY usingDbusChanged)
    // CalendarServer was unreachable, so we fell back to parsing EDS's own .ics file.
    Q_PROPERTY(bool fallbackActive READ fallbackActive NOTIFY fallbackActiveChanged)

public:
    explicit EventsManager(QObject* parent = nullptr);

    [[nodiscard]] QVariantList variants() const;
    [[nodiscard]] QVariantMap dayColours() const;
    [[nodiscard]] bool usingDbus() const;
    [[nodiscard]] bool fallbackActive() const;

    Q_INVOKABLE void refresh(bool force = false);

    // Watch a window (local dates, inclusive); the dashboard calls this as months page by.
    Q_INVOKABLE void setWindow(const QDate& from, const QDate& to);

signals:
    void variantsChanged();
    void usingDbusChanged();
    void fallbackActiveChanged();

protected:
    void start() override;
    void stop() override;

private:
    void fetch(bool force);
    void fetchFromDbus();
    void fetchFromCache();

    void setUsingDbus(bool value);
    void setFallbackActive(bool value);

    void startDbus();
    void startCacheWatcher();
    void applyEvents(const QVariantList& events, bool fromDbus);

    static QVariantList parseIcs(const QString& path, const QDateTime& since, const QDateTime& until,
                                 const QString& calendarName, const QString& colour);

    QVariantList m_variants;
    bool m_usingDbus = false;
    bool m_fallbackActive = false;
    bool m_fetchInFlight = false;

    // The watched window. D-Bus SetTimeRange uses these; the cache reader clips to them.
    QDateTime m_since;
    QDateTime m_until;

    QFileSystemWatcher* m_cacheWatcher = nullptr;

private slots:
    void onEventsAddedOrUpdated(const QDBusMessage& message);
};

} // namespace caelestia::shell::services
