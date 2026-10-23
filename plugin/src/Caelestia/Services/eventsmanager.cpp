#include "eventsmanager.hpp"

#include <qdbusconnection.h>
#include <qdbuserror.h>
#include <qdbusmessage.h>
#include <qdbuspendingcall.h>
#include <QDBusPendingCallWatcher>
#include <qdbusreply.h>
#include <qdir.h>
#include <qfile.h>
#include <qfileinfo.h>
#include <qfilesystemwatcher.h>
#include <qfuture.h>
#include <qfuturewatcher.h>
#include <qloggingcategory.h>
#include <qmimedatabase.h>
#include <qstandardpaths.h>
#include <qtextstream.h>
#include <qtimezone.h>
#include <qregularexpression.h>

#include <qtconcurrentrun.h>

#include <algorithm>

namespace caelestia::shell::services {

using Qt::StringLiterals::operator""_s;

namespace {

Q_LOGGING_CATEGORY(lcEvents, "caelestia.services.events", QtInfoMsg)

constexpr auto k_dbusService = "org.gnome.Shell.CalendarServer";
constexpr auto k_dbusPath = "/org/gnome/Shell/CalendarServer";
constexpr auto k_dbusInterface = "org.gnome.Shell.CalendarServer";
constexpr auto k_dbusSignal = "EventsAddedOrUpdated";

QString calendarDataDir() {
    return QDir(QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation)).filePath("evolution/calendar");
}

QString calendarConfigDir() {
    return QDir(QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation)).filePath("evolution/sources");
}

// colour of an EDS source: Color= key inside its .source keyfile
QString colourForSource(const QString& path) {
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text))
        return {};

    while (!f.atEnd()) {
        const auto line = f.readLine();
        if (line.startsWith("Color="))
            return QString::fromUtf8(line.mid(6)).trimmed();
    }
    return {};
}

// display name of an EDS source: DisplayName= (unlocalised, last key wins in our case)
QString nameForSource(const QString& path) {
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text))
        return {};

    QString name;
    while (!f.atEnd()) {
        const auto line = f.readLine();
        const int eq = line.indexOf('=');
        if (eq > 0 && line.left(eq) == "DisplayName")
            name = QString::fromUtf8(line.mid(eq + 1)).trimmed();
    }
    return name;
}

QDateTime fromIcsStamp(QStringView stamp) {
    // DATE-TIME forms: YYYYMMDDThhmmss(Z?) — DATE form: YYYYMMDD
    if (stamp.size() < 8)
        return {};
    const auto d = QDate(stamp.mid(0, 4).toInt(), stamp.mid(4, 2).toInt(), stamp.mid(6, 2).toInt());
    if (!d.isValid())
        return {};

    bool isUtc = false;
    int hh = 0, mm = 0, ss = 0;
    if (stamp.size() >= 15 && stamp[8] == 'T') {
        hh = stamp.mid(9, 2).toInt();
        mm = stamp.mid(11, 2).toInt();
        ss = stamp.mid(13, 2).toInt();
        isUtc = stamp.size() >= 16 && stamp[15] == 'Z';
    }

    QDateTime dt = QDateTime(d, QTime(hh, mm, ss));
    if (isUtc)
        dt.setTimeZone(QTimeZone::utc());
    else
        dt = QDateTime(d, QTime(hh, mm, ss), QTimeZone::systemTimeZone());
    return dt;
}

QDate fromIcsDate(QStringView stamp) {
    if (stamp.size() < 8)
        return {};
    const auto d = QDate(stamp.mid(0, 4).toInt(), stamp.mid(4, 2).toInt(), stamp.mid(6, 2).toInt());
    return d.isValid() ? d : QDate();
}

// strip \n / \\ and key escapes
QString icsUnescape(QString s) {
    s.replace("\\n", " ");
    s.replace("\\,", ",");
    s.replace("\\;", ";");
    s.replace("\\\\", "\\");
    return s;
}

// Parse a VCALENDAR file into flat event variants clipped to [since, until].
QVariantList parseIcsFile(const QString& path, const QDateTime& since, const QDateTime& until,
                          const QString& calendarName, const QString& colour) {
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text))
        return {};

    // unfold RFC 5545 folded lines: continuation lines begin with a space/tab
    QString contents;
    QTextStream stream(&f);
    bool first = true;
    while (!stream.atEnd()) {
        const auto raw = stream.readLine();
        if (!first && (raw.startsWith(' ') || raw.startsWith('\t')))
            contents += raw.mid(1);
        else {
            if (!first)
                contents += '\n';
            contents += raw;
        }
        first = false;
    }

    const auto lines = contents.split('\n');

    QVariantList out;
    bool inEvent = false;
    QString summary;
    QDateTime start, end;
    QDate dateOnlyStart, dateOnlyEnd;

    auto emitEvent = [&] {
        if (!inEvent)
            return;
        inEvent = false;

        // an event with neither start nor a summary is not useful
        if (start.isNull() && dateOnlyStart.isNull())
            return;

        const QDateTime s = !start.isNull() ? start
                                            : QDateTime(dateOnlyStart, QTime(0, 0), QTimeZone::systemTimeZone());
        // all-day events with no DTEND span one day
        const QDateTime e = !end.isNull()          ? end
                            : !dateOnlyEnd.isNull() ? QDateTime(dateOnlyEnd, QTime(0, 0), QTimeZone::systemTimeZone())
                                                    : s.addSecs(3600);

        if (e <= since || s >= until)
            return;

        QVariantMap m;
        m.insert(u"summary"_s, summary);
        m.insert(u"start"_s, s);
        m.insert(u"end"_s, e);
        m.insert(u"colour"_s, colour);
        m.insert(u"calendar"_s, calendarName);
        out.append(m);

        summary.clear();
        start = end = QDateTime();
        dateOnlyStart = dateOnlyEnd = QDate();
    };

    for (const auto& line : lines) {
        const auto unescaped = icsUnescape(line);
        const int colon = unescaped.indexOf(':');
        if (colon <= 0)
            continue;

        const auto key = unescaped.left(colon).toUpper();
        const auto value = unescaped.mid(colon + 1).trimmed();

        if (key == "BEGIN:VEVENT") {
            inEvent = true;
        } else if (key == "END:VEVENT") {
            emitEvent();
        } else if (!inEvent) {
            continue;
        } else if (key.startsWith("SUMMARY")) {
            summary = value;
        } else if (key.startsWith("DTSTART")) {
            start = fromIcsStamp(value);
            dateOnlyStart = start.isNull() ? fromIcsDate(value) : QDate();
        } else if (key.startsWith("DTEND")) {
            end = fromIcsStamp(value);
            dateOnlyEnd = end.isNull() ? fromIcsDate(value) : QDate();
        }
    }

    // trailing event with no END (or no newline at EOF)
    emitEvent();
    return out;
}

struct CacheParse {
    QVariantList events;
    QStringList files;
};

// Parse every VEVENT-bearing .ics under the EDS per-calendar dirs, resolving the
// owning source's colour/display name as we go.
CacheParse parseCache(const QDateTime& since, const QDateTime& until) {
    CacheParse out;

    const auto dataDir = calendarDataDir();
    const auto configDir = calendarConfigDir();
    const auto calendarDirs = QDir(dataDir).entryList(QDir::Dirs | QDir::NoDotAndDotDot);

    for (const auto& dirName : calendarDirs) {
        // EDS stores the calendar's data in a dir named after the source UID
        const auto sourcePath = QDir(configDir).filePath(dirName + ".source");
        const auto colour = colourForSource(sourcePath);
        const auto name = nameForSource(sourcePath);

        const QDir dir(QDir(dataDir).filePath(dirName));
        for (const auto& icsPath : dir.entryList(QStringList() << "*.ics", QDir::Files)) {
            const auto abs = dir.filePath(icsPath);
            out.files.append(abs);
            const auto events = parseIcsFile(abs, since, until, name, colour);
            out.events.append(events);
        }
    }
    return out;
}

QVariantMap dayColourMap(const QVariantList& events) {
    QVariantMap out;
    for (const auto& ev : events) {
        const auto m = ev.toMap();
        const auto start = m.value(u"start"_s).toDateTime();
        const auto end = m.value(u"end"_s).toDateTime();
        if (!start.isValid())
            continue;
        const auto colour = m.value(u"colour"_s).toString();

        // for multi-day events this covers every day from start..end
        auto d = start.date();
        const auto last = end.isValid() ? end.date() : start.date();
        // if end is midnight of the next day (all-day), don't add a phantom last day
        const auto effectiveLast = (last > d && end.time() == QTime(0, 0)) ? last.addDays(-1) : last;
        while (d <= effectiveLast) {
            out.insert(d.toString(u"yyyy-MM-dd"_s), colour);
            d = d.addDays(1);
        }
    }
    return out;
}

} // namespace

EventsManager::EventsManager(QObject* parent)
    : Service(parent)
    , m_cacheWatcher(new QFileSystemWatcher(this)) {
    // watch the EDS calendar dir tree so added calendars/deleted calendars are picked up
    QObject::connect(m_cacheWatcher, &QFileSystemWatcher::directoryChanged, this, [this] {
        startCacheWatcher(); // re-register watched dirs (a new calendar dir appeared)
        fetchFromCache();
    });
    QObject::connect(m_cacheWatcher, &QFileSystemWatcher::fileChanged, this, [this] {
        // a calendar.ics file was rewritten; the dir-level watcher may also fire, but this
        // catches content edits with no add/remove
        fetchFromCache();
    });
}

QVariantList EventsManager::variants() const {
    return m_variants;
}

QVariantMap EventsManager::dayColours() const {
    return dayColourMap(m_variants);
}

bool EventsManager::usingDbus() const {
    return m_usingDbus;
}

bool EventsManager::fallbackActive() const {
    return m_fallbackActive;
}

void EventsManager::setUsingDbus(bool value) {
    if (m_usingDbus != value) {
        m_usingDbus = value;
        emit usingDbusChanged();
    }
}

void EventsManager::setFallbackActive(bool value) {
    if (m_fallbackActive != value) {
        m_fallbackActive = value;
        emit fallbackActiveChanged();
    }
}

void EventsManager::start() {
    startDbus();
    startCacheWatcher();
    fetch(false);
}

void EventsManager::stop() {
    // watchers are our own children and the bus connection is shared, so nothing to do
}

void EventsManager::refresh(bool force) {
    setWindow(QDate::currentDate().addDays(-1), QDate::currentDate().addDays(31));
    fetch(force);
}

void EventsManager::setWindow(const QDate& from, const QDate& to) {
    const auto since = QDateTime(from, QTime(0, 0), QTimeZone::systemTimeZone());
    const auto until = QDateTime(to.addDays(1), QTime(0, 0), QTimeZone::systemTimeZone());

    if (m_since == since && m_until == until)
        return;

    m_since = since;
    m_until = until;

    if (m_fetchInFlight)
        return;

    if (m_usingDbus) {
        auto msg = QDBusMessage::createMethodCall(k_dbusService, k_dbusPath, k_dbusInterface, "SetTimeRange");
        msg << static_cast<qint64>(since.toSecsSinceEpoch()) << static_cast<qint64>(until.toSecsSinceEpoch()) << false;
        QDBusConnection::sessionBus().asyncCall(msg);
    } else {
        fetchFromCache();
    }
}

void EventsManager::fetch(bool force) {
    if (m_fetchInFlight)
        return;

    m_fetchInFlight = true;
    fetchFromDbus();
    if (!m_usingDbus)
        fetchFromCache();

    if (force) {
        // watched files may have been deleted/recreated between refreshes — re-register
        startCacheWatcher();
    }
}

void EventsManager::startDbus() {
    // Listen for pushes; gnome-shell only spawns the CalendarServer when IT is running,
    // so on Hyprland-first setups we will likely stay on cache fallback.
    QDBusConnection::sessionBus().connect(
        k_dbusService, k_dbusPath, k_dbusInterface, k_dbusSignal, this,
        SLOT(onEventsAddedOrUpdated(QDBusMessage)));
}

// gnome-shell's calendar server pushes a(ssxxa{sv}) tuples: (uid, summary, start, end, extras)
void EventsManager::onEventsAddedOrUpdated(const QDBusMessage& message) {
    const auto args = message.arguments();
    if (args.isEmpty() || args.first().userType() != QMetaType::QVariantList)
        return;

    QVariantList events;
    for (const auto& entryVar : args.first().toList()) {
        const auto tuple = entryVar.toList();
        if (tuple.size() < 4)
            continue;

        const auto start = QDateTime::fromSecsSinceEpoch(tuple.at(2).toLongLong());
        const auto end = QDateTime::fromSecsSinceEpoch(tuple.at(3).toLongLong());

        QVariantMap m;
        m.insert(u"summary"_s, tuple.at(1).toString());
        m.insert(u"start"_s, start);
        m.insert(u"end"_s, end);
        m.insert(u"colour"_s, tuple.at(0).toString()); // uid isn't a colour; use calendar fallback
        m.insert(u"calendar"_s, tuple.at(0).toString());
        events.append(m);
    }

    setUsingDbus(true);
    setFallbackActive(false);
    applyEvents(events, true);
}

void EventsManager::startCacheWatcher() {
    // Track the whole set of .ics files, re-registering on directory churn.
    const auto dataDir = calendarDataDir();

    const auto dirs = QDir(dataDir).entryList(QDir::Dirs | QDir::NoDotAndDotDot);
    for (const auto& d : dirs) {
        const auto abs = QDir(dataDir).filePath(d);
        if (!m_cacheWatcher->directories().contains(abs))
            m_cacheWatcher->addPath(abs);
    }

    for (const auto& d : dirs) {
        const QDir dir(QDir(dataDir).filePath(d));
        for (const auto& ics : dir.entryList(QStringList() << "*.ics", QDir::Files)) {
            const auto abs = dir.filePath(ics);
            if (!m_cacheWatcher->files().contains(abs))
                m_cacheWatcher->addPath(abs);
        }
    }
}

struct FetchJob {
    QVariantList dbusEvents;
    QVariantList cacheEvents;
    QStringList cacheDirs;
    QStringList cacheFiles;
    bool dbusAvailable = false;
    bool dbusFailed = false;
};

void EventsManager::fetchFromDbus() {
    auto msg = QDBusMessage::createMethodCall(k_dbusService, k_dbusPath, k_dbusInterface, "SetTimeRange");
    msg << static_cast<qint64>(m_since.toSecsSinceEpoch()) << static_cast<qint64>(m_until.toSecsSinceEpoch()) << true;

    auto* watcher = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(msg), this);

    QObject::connect(watcher, &QDBusPendingCallWatcher::finished, this, [this](QDBusPendingCallWatcher* self) {
        self->deleteLater();
        m_fetchInFlight = false;

        const QDBusReply<void> reply = *self;
        if (reply.isValid()) {
            setUsingDbus(true);
            setFallbackActive(false);
            // the server now pushes EventsAddedOrUpdated; keep the cache parse as a
            // starting frame so the grid isn't blank while the server catches up
            fetchFromCache();
        } else {
            setUsingDbus(false);
            setFallbackActive(true);
            qCDebug(lcEvents) << "CalendarServer unavailable:" << reply.error().message();
            fetchFromCache();
        }
    });
}

void EventsManager::fetchFromCache() {
    const auto since = m_since;
    const auto until = m_until;

    auto* watcher = new QFutureWatcher<CacheParse>(this);
    QObject::connect(watcher, &QFutureWatcherBase::finished, this, [this, watcher] {
        watcher->deleteLater();
        m_fetchInFlight = false;

        const auto result = watcher->result();

        // Drop watch registrations for paths that no longer exist so removed
        // calendars stop firing directoryChanged.
        const QStringList watched = m_cacheWatcher->directories() + m_cacheWatcher->files();
        QStringList stillThere = result.cacheDirs + result.cacheFiles;
        for (const auto& path : watched) {
            if (!stillThere.contains(path) && QFile::exists(path)) {
                m_cacheWatcher->removePath(path);
            }
        }

        applyEvents(result.events, false);
    });
    watcher->setFuture(QtConcurrent::run([since, until] { return parseCache(since, until); }));
}

void EventsManager::applyEvents(const QVariantList& events, bool fromDbus) {
    Q_UNUSED(fromDbus);

    // Events come unsorted; make ranges deterministic for the day-colour map
    QVariantList sorted = events;
    std::ranges::sort(sorted, [](const QVariant& a, const QVariant& b) {
        const auto da = a.toMap().value(u"start"_s).toDateTime();
        const auto db = b.toMap().value(u"start"_s).toDateTime();
        return da < db;
    });

    if (sorted == m_variants)
        return;

    m_variants = sorted;
    emit variantsChanged();
}

} // namespace caelestia::shell::services
