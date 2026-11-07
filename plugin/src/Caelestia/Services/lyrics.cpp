#include "lyrics.hpp"

#include <qdiriterator.h>
#include <qfileinfo.h>
#include <qjsonarray.h>
#include <qnetworkcookiejar.h>
#include <qsavefile.h>
#include <qurlquery.h>
#include <qvariantmap.h>

#include <algorithm>

#include "config/rootnodes.hpp"
#include "config/serviceconfig.hpp"
#include "config/userpaths.hpp"

namespace {

Q_LOGGING_CATEGORY(lcLyrics, "caelestia.lyrics", QtInfoMsg)

} // namespace

namespace caelestia::shell::services {

using Qt::StringLiterals::operator""_s;
using Qt::StringLiterals::operator""_ba;

namespace {

constexpr int k_loadDebounceMs = 50;
constexpr qreal k_indexFudge = 0.1;

[[nodiscard]] const QHash<QByteArray, QByteArray>& netEaseHeaders() {
    static const QHash<QByteArray, QByteArray> k_h = {
        { "User-Agent"_ba, "Mozilla/5.0 (X11; Linux x86_64; rv:120.0) Gecko/20100101 Firefox/120.0"_ba },
        { "Referer"_ba, "https://music.163.com/"_ba },
    };
    return k_h;
}

[[nodiscard]] const QHash<QByteArray, QByteArray>& lrclibHeaders() {
    static const QHash<QByteArray, QByteArray> k_h = {
        { "User-Agent"_ba, "caelestia-shell (https://github.com/caelestia-dots/shell)"_ba },
    };
    return k_h;
}

[[nodiscard]] QString joinArtists(const QString& s) {
    return s.trimmed();
}

[[nodiscard]] QString sanitizeFilenamePart(const QString& s) {
    QString out;
    out.reserve(s.size());
    for (const QChar c : s) {
        if (c == u'/' || c == u'\0') {
            out.append(u'_');
        } else {
            out.append(c);
        }
    }
    return out;
}

[[nodiscard]] bool containsCi(const QString& haystack, const QString& needle) {
    return haystack.contains(needle, Qt::CaseInsensitive);
}

} // namespace

Lyrics::Lyrics(QObject* parent)
    : QObject(parent)
    , m_nam(new QNetworkAccessManager(this))
    , m_loadDebounce(new QTimer(this))
    , m_keyWatcher(new QFileSystemWatcher(this)) {
    m_loadDebounce->setSingleShot(true);
    m_loadDebounce->setInterval(k_loadDebounceMs);
    QObject::connect(m_loadDebounce, &QTimer::timeout, this, &Lyrics::doLoad);

    const auto* cfg = config::ConfigSingleton::instance();
    const auto* svcCfg = cfg->services();
    const auto* paths = cfg->paths();

    m_preferredBackend = svcCfg->lyricsBackend();

    QObject::connect(
        svcCfg, &config::ServiceConfig::lyricsBackendChanged, this, &Lyrics::onPreferredBackendConfigChanged);
    QObject::connect(paths, &config::UserPaths::lyricsDirChanged, this, &Lyrics::onLyricsDirChanged);

    m_lastSpicyKey = spicyKey();
    QObject::connect(m_keyWatcher, &QFileSystemWatcher::fileChanged, this, &Lyrics::onSpicyKeyChanged);
    QObject::connect(m_keyWatcher, &QFileSystemWatcher::directoryChanged, this, &Lyrics::onSpicyKeyChanged);
    watchSpicyKey();

    loadLyricsMap();
}

QStringList Lyrics::lyrics() const {
    return m_lyrics;
}

QVariantList Lyrics::lines() const {
    QVariantList out;
    out.reserve(m_lines.size());
    for (const auto& line : m_lines) {
        QVariantList words;
        words.reserve(line.words.size());
        for (const auto& word : line.words) {
            words.append(QVariantMap{
                { u"text"_s, word.text },
                { u"start"_s, word.start },
                { u"end"_s, word.end },
                { u"joinNext"_s, word.joinNext },
            });
        }
        out.append(QVariantMap{
            { u"time"_s, line.time },
            { u"text"_s, line.text },
            { u"words"_s, words },
        });
    }
    return out;
}

bool Lyrics::wordTimed() const {
    return m_wordTimed;
}

LyricsBackend Lyrics::backend() const {
    return m_backend;
}

LyricsBackend Lyrics::preferredBackend() const {
    return m_preferredBackend;
}

void Lyrics::setPreferredBackend(LyricsBackend value) {
    if (m_preferredBackend == value) {
        return;
    }
    m_preferredBackend = value;
    emit preferredBackendChanged();

    config::ConfigSingleton::instance()->services()->set_lyricsBackend(value);

    scheduleLoad();
}

QList<LyricCandidate> Lyrics::lyricCandidates() const {
    return m_candidates;
}

LyricCandidate Lyrics::selectedCandidate() const {
    return m_selected;
}

void Lyrics::setSelectedCandidate(const LyricCandidate& value) {
    if (m_selected == value) {
        return;
    }
    m_selected = value;
    emit selectedCandidateChanged();

    if (!value.isValid()) {
        return;
    }

    const auto b = value.backend();
    setBackend(b);
    setLoading(true);

    cancelInFlight();
    const int reqId = newRequestId();

    if (b == LyricsBackend::LRCLIB || b == LyricsBackend::NetEase) {
        const QString cached = readCachedLrc(b, value.id());
        if (!cached.isEmpty()) {
            const auto lines = parseLrc(cached);
            if (!lines.isEmpty()) {
                setLines(lines, b);
                setLoading(false);
                if (!m_settingFromPrefs) {
                    persistTrackPrefs();
                }
                return;
            }
        }
    }

    if (b == LyricsBackend::LRCLIB) {
        fetchLrclibById(value.id(), reqId);
    } else if (b == LyricsBackend::NetEase) {
        fetchNetEaseLyricsById(value.id(), reqId);
    } else if (b == LyricsBackend::Local) {
        // For local, the id is the file path. Read directly.
        QFile f(value.id());
        if (f.open(QIODevice::ReadOnly)) {
            const QString text = QString::fromUtf8(f.readAll());
            setLines(parseLrc(text), LyricsBackend::Local);
            setLoading(false);
        } else {
            qCWarning(lcLyrics) << "selectedCandidate: cannot open local file" << value.id();
            setLoading(false);
        }
    }

    if (!m_settingFromPrefs) {
        persistTrackPrefs();
    }
}

bool Lyrics::loading() const {
    return m_loading;
}

bool Lyrics::hasLyrics() const {
    return m_hasLyrics;
}

qreal Lyrics::offset() const {
    return m_offset;
}

void Lyrics::setOffset(qreal value) {
    if (qFuzzyCompare(m_offset, value)) {
        return;
    }
    m_offset = value;
    emit offsetChanged();

    if (!m_settingFromPrefs) {
        persistTrackPrefs();
    }
}

QString Lyrics::trackArtist() const {
    return m_artist;
}

QString Lyrics::trackTitle() const {
    return m_title;
}

int Lyrics::indexForTime(qreal time) const {
    if (m_lines.isEmpty()) {
        return -1;
    }
    const qreal target = time - m_offset + k_indexFudge;
    qsizetype lo = 0;
    qsizetype hi = m_lines.size();
    while (lo < hi) {
        const qsizetype mid = lo + (hi - lo) / 2;
        if (m_lines.at(mid).time <= target) {
            lo = mid + 1;
        } else {
            hi = mid;
        }
    }
    return static_cast<int>(lo - 1);
}

qreal Lyrics::timeForIndex(int index) const {
    if (index < 0 || index >= m_lines.size()) {
        return -1.0;
    }
    return m_lines.at(index).time + m_offset;
}

qreal Lyrics::wordProgress(int line, int word, qreal time) const {
    if (line < 0 || line >= m_lines.size()) {
        return 0.0;
    }
    const auto& words = m_lines.at(line).words;
    if (word < 0 || word >= words.size()) {
        return 0.0;
    }

    const auto& w = words.at(word);
    // The offset moves the lyrics, not the track: a positive offset means the words land later.
    const qreal now = time - m_offset;
    if (w.end <= w.start) {
        return now >= w.start ? 1.0 : 0.0;
    }
    return std::clamp((now - w.start) / (w.end - w.start), 0.0, 1.0);
}

void Lyrics::setTrack(
    const QString& artist, const QString& title, const QString& album, qreal duration, const QString& spotifyId) {
    const QString a = artist.trimmed();
    const QString t = title.trimmed();
    const QString id = spotifyId.trimmed();

    if (a == m_artist && t == m_title && album == m_album && id == m_spotifyId
        && qFuzzyCompare(duration + 1.0, m_duration + 1.0)) {
        return;
    }

    m_artist = a;
    m_title = t;
    m_album = album;
    m_duration = duration;
    m_spotifyId = id;
    emit trackChanged();

    scheduleLoad();
}

void Lyrics::clearTrack() {
    cancelInFlight();
    m_artist.clear();
    m_title.clear();
    m_album.clear();
    m_duration = 0.0;
    m_spotifyId.clear();
    emit trackChanged();

    clearCandidates();
    clearLines();
    setLoading(false);
}

void Lyrics::refresh() {
    scheduleLoad();
}

void Lyrics::setBackend(LyricsBackend value) {
    if (m_backend == value) {
        return;
    }
    m_backend = value;
    emit backendChanged();
}

void Lyrics::setLoading(bool value) {
    if (m_loading == value) {
        return;
    }
    m_loading = value;
    emit loadingChanged();
}

void Lyrics::setLines(QVector<LyricLine> lines, LyricsBackend source) {
    std::ranges::sort(lines, [](const LyricLine& a, const LyricLine& b) {
        return a.time < b.time;
    });

    m_lines = std::move(lines);
    m_wordTimed = std::ranges::any_of(m_lines, [](const LyricLine& l) {
        return !l.words.isEmpty();
    });
    QStringList list;
    list.reserve(m_lines.size());
    for (const auto& l : std::as_const(m_lines)) {
        list.append(l.text);
    }
    m_lyrics = std::move(list);

    setBackend(source);
    emit lyricsChanged();

    const auto hasLyrics = !m_lines.isEmpty();
    if (hasLyrics != m_hasLyrics) {
        m_hasLyrics = hasLyrics;
        emit hasLyricsChanged();
    }
}

void Lyrics::clearLines() {
    if (!m_hasLyrics) {
        return;
    }

    // Doesn't actually clear lines, set a flag instead so anims can run
    m_hasLyrics = false;
    m_wordTimed = false;
    emit hasLyricsChanged();
}

void Lyrics::appendCandidates(const QList<LyricCandidate>& add) {
    if (add.isEmpty()) {
        return;
    }
    bool changed = false;
    for (const auto& c : add) {
        if (!m_candidates.contains(c)) {
            m_candidates.append(c);
            changed = true;
        }
    }
    if (changed) {
        emit lyricCandidatesChanged();
    }
}

void Lyrics::clearCandidates() {
    if (m_candidates.isEmpty()) {
        return;
    }
    m_candidates.clear();
    emit lyricCandidatesChanged();
}

void Lyrics::scheduleLoad() {
    m_loadDebounce->start();
}

int Lyrics::newRequestId() {
    return ++m_currentRequestId;
}

void Lyrics::cancelInFlight() {
    for (auto it = m_pendingReplies.begin(); it != m_pendingReplies.end(); ++it) {
        const auto& replies = it.value();
        for (const auto& ptr : replies) {
            if (auto* const reply = ptr.data()) {
                reply->abort();
                reply->deleteLater();
            }
        }
    }
    m_pendingReplies.clear();
}

void Lyrics::trackReply(int reqId, QNetworkReply* reply) {
    if (!reply) {
        return;
    }
    m_pendingReplies[reqId].append(QPointer<QNetworkReply>(reply));
}

void Lyrics::doLoad() {
    if (m_artist.isEmpty() && m_title.isEmpty()) {
        clearLines();
        clearCandidates();
        setLoading(false);
        return;
    }

    cancelInFlight();
    const int reqId = newRequestId();

    setLoading(true);
    clearLines();
    clearCandidates();

    // The offset belongs to the track, not to whichever source answers, so it is restored here
    // rather than down in the fallback: a word-timed track needs the same correction the
    // line-timed one would have had.
    m_settingFromPrefs = true;
    setOffset(m_lyricsMap.value(trackKey()).toObject().value(u"offset"_s).toDouble(0.0));
    m_settingFromPrefs = false;

    // Always populate online candidates for the picker, regardless of preferred backend
    searchLrclibCandidates(reqId);
    searchNetEaseCandidates(reqId);

    /*
     * Word timings first, when they could exist: a Spotify stream, whose own track id the
     * word-timed source takes directly, and a key to ask it with. They are the one thing the
     * other sources cannot give - those know where each line starts and nothing finer, so a
     * view can only light the line whole - which makes the extra request worth it.
     *
     * Anything short of a syllable sync falls through to the line-timed sources unchanged: no
     * id, no key, key refused, nothing found, or a track that source only timed by line. The
     * chain below is untouched, so a track without word timings behaves exactly as it did.
     */
    if (!m_spotifyId.isEmpty() && !spicyKey().isEmpty()) {
        trySpicy(reqId);
        return;
    }

    loadFallback(reqId);
}

void Lyrics::loadFallback(int reqId) {
    if (reqId != m_currentRequestId) {
        return;
    }

    // The backend and id picked for this track last time, if one was saved
    const QJsonObject saved = m_lyricsMap.value(trackKey()).toObject();
    LyricCandidate restored;
    const QString savedBackendKey = saved.value(u"backend"_s).toString();
    const QString savedId = saved.value(u"id"_s).toString();
    if (!savedBackendKey.isEmpty() && !savedId.isEmpty()) {
        restored = LyricCandidate(backendFromKey(savedBackendKey), savedId, m_title, m_artist, m_album, m_duration);
    }

    if (restored.isValid()) {
        // Honor saved selection for this track
        m_settingFromPrefs = true;
        setSelectedCandidate(restored);
        m_settingFromPrefs = false;
        return;
    }

    // Primary attempt by preferred backend
    switch (m_preferredBackend) {
    case LyricsBackend::Local:
        tryLocal(reqId);
        break;
    case LyricsBackend::LRCLIB:
        tryLrclib(reqId);
        break;
    case LyricsBackend::NetEase:
        tryNetEase(reqId);
        break;
    case LyricsBackend::Auto:
    default:
        tryLocal(reqId);
        break;
    }
}

void Lyrics::chainNext(LyricsBackend justFailed, int reqId) {
    if (m_preferredBackend != LyricsBackend::Auto) {
        // Non-auto modes don't chain
        setLoading(false);
        return;
    }
    switch (justFailed) {
    case LyricsBackend::Local:
        tryLrclib(reqId);
        return;
    case LyricsBackend::LRCLIB:
        tryNetEase(reqId);
        return;
    case LyricsBackend::NetEase:
    default:
        setLoading(false);
        return;
    }
}

void Lyrics::tryLocal(int reqId) {
    if (reqId != m_currentRequestId) {
        return;
    }

    setBackend(LyricsBackend::Local);

    const QString dir = lyricsDir();
    if (dir.isEmpty()) {
        chainNext(LyricsBackend::Local, reqId);
        return;
    }

    const QString direct = tryReadLocalLrc(dir, m_artist, m_title);
    if (!direct.isEmpty()) {
        QFile f(direct);
        if (f.open(QIODevice::ReadOnly)) {
            const QString text = QString::fromUtf8(f.readAll());
            const auto lines = parseLrc(text);
            if (!lines.isEmpty()) {
                setLines(lines, LyricsBackend::Local);
                appendCandidates(
                    { LyricCandidate(LyricsBackend::Local, direct, m_title, m_artist, m_album, m_duration) });
                m_selected = LyricCandidate(LyricsBackend::Local, direct, m_title, m_artist, m_album, m_duration);
                emit selectedCandidateChanged();
                if (!m_settingFromPrefs) {
                    persistTrackPrefs();
                }
                setLoading(false);
                return;
            }
        }
    }

    const QString recursive = findLocalLrcRecursive(dir, m_artist, m_title);
    if (!recursive.isEmpty()) {
        QFile f(recursive);
        if (f.open(QIODevice::ReadOnly)) {
            const QString text = QString::fromUtf8(f.readAll());
            const auto lines = parseLrc(text);
            if (!lines.isEmpty()) {
                setLines(lines, LyricsBackend::Local);
                appendCandidates(
                    { LyricCandidate(LyricsBackend::Local, recursive, m_title, m_artist, m_album, m_duration) });
                m_selected = LyricCandidate(LyricsBackend::Local, recursive, m_title, m_artist, m_album, m_duration);
                emit selectedCandidateChanged();
                if (!m_settingFromPrefs) {
                    persistTrackPrefs();
                }
                setLoading(false);
                return;
            }
        }
    }

    qCDebug(lcLyrics) << "no local lrc for" << m_artist << "-" << m_title;
    chainNext(LyricsBackend::Local, reqId);
}

void Lyrics::tryLrclib(int reqId) {
    if (reqId != m_currentRequestId) {
        return;
    }

    setBackend(LyricsBackend::LRCLIB);

    QUrl url(u"https://lrclib.net/api/get"_s);
    QUrlQuery q;
    q.addQueryItem(u"track_name"_s, m_title);
    q.addQueryItem(u"artist_name"_s, m_artist);
    if (!m_album.isEmpty()) {
        q.addQueryItem(u"album_name"_s, m_album);
    }

    constexpr qreal k_maxDurationSecs = std::numeric_limits<int>::max();
    if (m_duration > 0 && qIsFinite(m_duration) && m_duration < k_maxDurationSecs) {
        q.addQueryItem(u"duration"_s, QString::number(qRound(m_duration)));
    }
    url.setQuery(q);

    auto* reply = getJson(url, lrclibHeaders());
    trackReply(reqId, reply);

    QObject::connect(reply, &QNetworkReply::finished, this, [this, reply, reqId] {
        reply->deleteLater();
        if (reqId != m_currentRequestId) {
            return;
        }
        if (reply->error() != QNetworkReply::NoError) {
            qCDebug(lcLyrics) << "lrclib /get error:" << reply->errorString();
            chainNext(LyricsBackend::LRCLIB, reqId);
            return;
        }
        const QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
        const QJsonObject obj = doc.object();
        const QString synced = obj.value(u"syncedLyrics"_s).toString();
        const qint64 id = static_cast<qint64>(obj.value(u"id"_s).toDouble());

        if (synced.isEmpty()) {
            qCDebug(lcLyrics) << "lrclib: no syncedLyrics for" << m_artist << "-" << m_title;
            chainNext(LyricsBackend::LRCLIB, reqId);
            return;
        }

        const auto lines = parseLrc(synced);
        if (lines.isEmpty()) {
            chainNext(LyricsBackend::LRCLIB, reqId);
            return;
        }

        writeCachedLrc(LyricsBackend::LRCLIB, QString::number(id), synced);
        setLines(lines, LyricsBackend::LRCLIB);
        const LyricCandidate cand(LyricsBackend::LRCLIB, QString::number(id), obj.value(u"trackName"_s).toString(),
            obj.value(u"artistName"_s).toString(), obj.value(u"albumName"_s).toString(),
            obj.value(u"duration"_s).toDouble());
        appendCandidates({ cand });
        m_selected = cand;
        emit selectedCandidateChanged();
        if (!m_settingFromPrefs) {
            persistTrackPrefs();
        }
        setLoading(false);
    });
}

void Lyrics::tryNetEase(int reqId) {
    if (reqId != m_currentRequestId) {
        return;
    }

    setBackend(LyricsBackend::NetEase);

    // Reset cookies (LyricsBackend::NetEase rejects requests with stale cookies sometimes)
    m_nam->setCookieJar(new QNetworkCookieJar(m_nam));

    QUrl url(u"https://music.163.com/api/search/get"_s);
    QUrlQuery q;
    q.addQueryItem(u"s"_s, u"%1 %2"_s.arg(m_title, m_artist));
    q.addQueryItem(u"type"_s, u"1"_s);
    q.addQueryItem(u"limit"_s, u"5"_s);
    url.setQuery(q);

    auto* reply = getJson(url, netEaseHeaders());
    trackReply(reqId, reply);

    QObject::connect(reply, &QNetworkReply::finished, this, [this, reply, reqId] {
        reply->deleteLater();
        if (reqId != m_currentRequestId) {
            return;
        }
        if (reply->error() != QNetworkReply::NoError) {
            qCDebug(lcLyrics) << "netease /search error:" << reply->errorString();
            chainNext(LyricsBackend::NetEase, reqId);
            return;
        }

        const QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
        const QJsonArray songs = doc.object().value(u"result"_s).toObject().value(u"songs"_s).toArray();

        // Find best match by artist substring
        qint64 bestId = -1;
        for (const auto& v : songs) {
            const QJsonObject s = v.toObject();
            const QJsonArray artists = s.value(u"artists"_s).toArray();
            if (artists.isEmpty()) {
                continue;
            }
            const QString sArtist = artists.first().toObject().value(u"name"_s).toString();
            if (containsCi(m_artist, sArtist) || containsCi(sArtist, m_artist)) {
                bestId = static_cast<qint64>(s.value(u"id"_s).toDouble());
                break;
            }
        }

        if (bestId < 0) {
            qCDebug(lcLyrics) << "netease: no artist match for" << m_artist << "-" << m_title;
            chainNext(LyricsBackend::NetEase, reqId);
            return;
        }

        fetchNetEaseLyricsById(QString::number(bestId), reqId);
    });
}

/*
 * Word timings from Spicy Lyrics, which is the one public source that carries them. It is asked
 * by Spotify's own id rather than by title and artist, so there is no matching to get wrong; the
 * key is a secret and lives in a file of its own rather than in the config.
 *
 * Nothing here is fatal. A refused key, a track it does not know, an answer timed only by line:
 * all of them hand the track to loadFallback, which is the engine exactly as it was.
 */
void Lyrics::trySpicy(int reqId) {
    if (reqId != m_currentRequestId) {
        return;
    }

    const QString key = spicyKey();
    if (key.isEmpty() || m_spotifyId.isEmpty()) {
        loadFallback(reqId);
        return;
    }

    const QUrl url(u"https://api.spicylyrics.org/v1/lyrics/"_s + m_spotifyId);
    QHash<QByteArray, QByteArray> headers;
    headers.insert("Authorization"_ba, "Bearer " + key.toUtf8());

    auto* reply = getJson(url, headers);
    trackReply(reqId, reply);

    QObject::connect(reply, &QNetworkReply::finished, this, [this, reply, reqId] {
        reply->deleteLater();
        if (reqId != m_currentRequestId) {
            return;
        }

        const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        if (status != 200 || reply->error() != QNetworkReply::NoError) {
            qCDebug(lcLyrics) << "spicy /lyrics error:" << status << reply->errorString();
            loadFallback(reqId);
            return;
        }

        const QJsonObject body = QJsonDocument::fromJson(reply->readAll()).object().value(u"Body"_s).toObject();
        const auto lines = parseSpicy(body);
        if (lines.isEmpty()) {
            qCDebug(lcLyrics) << "spicy: no word timings for" << m_artist << "-" << m_title;
            loadFallback(reqId);
            return;
        }

        // Whatever candidate the previous track had picked is still in m_selected, and an offset
        // change would save its id against this track. Nothing here came from a candidate, so
        // there is nothing to keep.
        if (m_selected.isValid()) {
            m_selected = LyricCandidate();
            emit selectedCandidateChanged();
        }

        setLines(lines, LyricsBackend::SpicyLyrics);
        setLoading(false);
    });
}

void Lyrics::searchLrclibCandidates(int reqId) {
    QUrl url(u"https://lrclib.net/api/search"_s);
    QUrlQuery q;
    q.addQueryItem(u"track_name"_s, m_title);
    q.addQueryItem(u"artist_name"_s, m_artist);
    url.setQuery(q);

    auto* reply = getJson(url, lrclibHeaders());
    trackReply(reqId, reply);

    QObject::connect(reply, &QNetworkReply::finished, this, [this, reply, reqId] {
        reply->deleteLater();
        if (reqId != m_currentRequestId) {
            return;
        }
        if (reply->error() != QNetworkReply::NoError) {
            qCDebug(lcLyrics) << "lrclib /search error:" << reply->errorString();
            return;
        }
        const QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
        const QJsonArray arr = doc.array();

        QList<LyricCandidate> add;
        add.reserve(arr.size());
        for (const auto& v : arr) {
            const QJsonObject o = v.toObject();
            if (o.value(u"syncedLyrics"_s).isNull() && o.value(u"plainLyrics"_s).isNull()) {
                continue;
            }
            add.append(
                LyricCandidate(LyricsBackend::LRCLIB, QString::number(static_cast<qint64>(o.value(u"id"_s).toDouble())),
                    o.value(u"trackName"_s).toString(), o.value(u"artistName"_s).toString(),
                    o.value(u"albumName"_s).toString(), o.value(u"duration"_s).toDouble()));
        }
        appendCandidates(add);
    });
}

void Lyrics::searchNetEaseCandidates(int reqId) {
    m_nam->setCookieJar(new QNetworkCookieJar(m_nam));

    QUrl url(u"https://music.163.com/api/search/get"_s);
    QUrlQuery q;
    q.addQueryItem(u"s"_s, u"%1 %2"_s.arg(m_title, m_artist));
    q.addQueryItem(u"type"_s, u"1"_s);
    q.addQueryItem(u"limit"_s, u"5"_s);
    url.setQuery(q);

    auto* reply = getJson(url, netEaseHeaders());
    trackReply(reqId, reply);

    QObject::connect(reply, &QNetworkReply::finished, this, [this, reply, reqId] {
        reply->deleteLater();
        if (reqId != m_currentRequestId) {
            return;
        }
        if (reply->error() != QNetworkReply::NoError) {
            qCDebug(lcLyrics) << "netease candidates error:" << reply->errorString();
            return;
        }
        const QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
        const QJsonArray songs = doc.object().value(u"result"_s).toObject().value(u"songs"_s).toArray();

        QList<LyricCandidate> add;
        add.reserve(songs.size());
        for (const auto& v : songs) {
            const QJsonObject s = v.toObject();
            QStringList artistNames;
            const QJsonArray artists = s.value(u"artists"_s).toArray();
            artistNames.reserve(artists.size());
            for (const auto& a : artists) {
                artistNames.append(a.toObject().value(u"name"_s).toString());
            }
            add.append(LyricCandidate(LyricsBackend::NetEase,
                QString::number(static_cast<qint64>(s.value(u"id"_s).toDouble())), s.value(u"name"_s).toString(),
                artistNames.join(u", "_s)));
        }
        appendCandidates(add);
    });
}

void Lyrics::fetchLrclibById(const QString& id, int reqId) {
    const QUrl url(u"https://lrclib.net/api/get/"_s + id);
    auto* reply = getJson(url, lrclibHeaders());
    trackReply(reqId, reply);

    QObject::connect(reply, &QNetworkReply::finished, this, [this, reply, reqId, id] {
        reply->deleteLater();
        if (reqId != m_currentRequestId) {
            return;
        }
        if (reply->error() != QNetworkReply::NoError) {
            qCWarning(lcLyrics) << "lrclib /get/{id} error:" << reply->errorString();
            setLoading(false);
            return;
        }
        const QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
        const QString synced = doc.object().value(u"syncedLyrics"_s).toString();
        if (synced.isEmpty()) {
            qCDebug(lcLyrics) << "lrclib /get/{id}: no syncedLyrics";
            setLoading(false);
            return;
        }
        writeCachedLrc(LyricsBackend::LRCLIB, id, synced);
        setLines(parseLrc(synced), LyricsBackend::LRCLIB);
        setLoading(false);
    });
}

void Lyrics::fetchNetEaseLyricsById(const QString& id, int reqId) {
    QUrl url(u"https://music.163.com/api/song/lyric"_s);
    QUrlQuery q;
    q.addQueryItem(u"id"_s, id);
    q.addQueryItem(u"lv"_s, u"1"_s);
    q.addQueryItem(u"kv"_s, u"1"_s);
    q.addQueryItem(u"tv"_s, u"-1"_s);
    url.setQuery(q);

    auto* reply = getJson(url, netEaseHeaders());
    trackReply(reqId, reply);

    QObject::connect(reply, &QNetworkReply::finished, this, [this, reply, reqId, id] {
        reply->deleteLater();
        if (reqId != m_currentRequestId) {
            return;
        }
        if (reply->error() != QNetworkReply::NoError) {
            qCWarning(lcLyrics) << "netease /lyric error:" << reply->errorString();
            setLoading(false);
            return;
        }
        const QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
        const QString lrc = doc.object().value(u"lrc"_s).toObject().value(u"lyric"_s).toString();
        if (lrc.isEmpty()) {
            qCDebug(lcLyrics) << "netease /lyric: empty for id" << id;
            setLoading(false);
            return;
        }
        writeCachedLrc(LyricsBackend::NetEase, id, lrc);
        setLines(parseLrc(lrc), LyricsBackend::NetEase);
        setLoading(false);
    });
}

QNetworkReply* Lyrics::getJson(const QUrl& url, const QHash<QByteArray, QByteArray>& headers) {
    QNetworkRequest req(url);
    req.setAttribute(QNetworkRequest::CacheLoadControlAttribute, QNetworkRequest::AlwaysNetwork);
    req.setRawHeader("Cache-Control"_ba, "no-cache, no-store"_ba);
    req.setRawHeader("Pragma"_ba, "no-cache"_ba);
    req.setRawHeader("Connection"_ba, "close"_ba);
    req.setRawHeader("Accept"_ba, "application/json"_ba);
    for (auto it = headers.constBegin(); it != headers.constEnd(); ++it) {
        req.setRawHeader(it.key(), it.value());
    }
    return m_nam->get(req);
}

void Lyrics::onPreferredBackendConfigChanged() {
    const LyricsBackend desired = config::ConfigSingleton::instance()->services()->lyricsBackend();
    if (desired == m_preferredBackend) {
        return;
    }
    m_preferredBackend = desired;
    emit preferredBackendChanged();
    scheduleLoad();
}

void Lyrics::onLyricsDirChanged() {
    scheduleLoad();
}

/*
 * The key is watched rather than only read when a track loads, so pasting one in reaches the track
 * already playing instead of the next one.
 *
 * The directory is watched as well as the file: a file that does not exist yet cannot be watched at
 * all, and a key written by an editor (which saves to a temporary and renames over the old file)
 * takes the watch on the path down with it. Re-adding both on every signal is what keeps the watch
 * alive across that.
 */
void Lyrics::watchSpicyKey() {
    const QFileInfo info(spicyKeyPath());

    const QString dir = info.absolutePath();
    if (QFileInfo::exists(dir) && !m_keyWatcher->directories().contains(dir)) {
        m_keyWatcher->addPath(dir);
    }

    const QString file = info.absoluteFilePath();
    if (info.exists() && !m_keyWatcher->files().contains(file)) {
        m_keyWatcher->addPath(file);
    }
}

void Lyrics::onSpicyKeyChanged() {
    watchSpicyKey();

    // The config directory holds shell.json too, so most of what stirs it has nothing to do with
    // the key. Only a key that actually reads differently is worth a reload.
    const QString key = spicyKey();
    if (key == m_lastSpicyKey) {
        return;
    }
    m_lastSpicyKey = key;

    // Only the word-timed source reads it, and only a Spotify stream can ask that source at all,
    // so there is nothing for anything else to pick up
    if (m_spotifyId.isEmpty()) {
        return;
    }

    qCInfo(lcLyrics) << (key.isEmpty() ? "spicy key removed" : "spicy key changed") << "- reloading lyrics";
    scheduleLoad();
}

void Lyrics::loadLyricsMap() {
    m_lyricsMap = {};
    m_lyricsMapLoaded = false;

    QFile f(lyricsMapPath());
    if (!f.open(QIODevice::ReadOnly)) {
        m_lyricsMapLoaded = true;
        return;
    }
    const QByteArray bytes = f.readAll();
    f.close();

    QJsonParseError err{};
    const QJsonDocument doc = QJsonDocument::fromJson(bytes, &err);
    if (err.error != QJsonParseError::NoError) {
        qCWarning(lcLyrics) << "lyrics_map.json parse error:" << err.errorString();
        m_lyricsMapLoaded = true;
        return;
    }
    m_lyricsMap = doc.object();
    m_lyricsMapLoaded = true;
}

void Lyrics::persistTrackPrefs() {
    if (!m_lyricsMapLoaded || trackKey().isEmpty()) {
        return;
    }
    const QString key = trackKey();
    QJsonObject entry = m_lyricsMap.value(key).toObject();
    entry.insert(u"offset"_s, m_offset);
    if (m_selected.isValid()) {
        entry.insert(u"backend"_s, backendKey(m_selected.backend()));
        entry.insert(u"id"_s, m_selected.id());
    }
    m_lyricsMap.insert(key, entry);

    QDir().mkpath(stateDir());

    QSaveFile out(lyricsMapPath());
    if (!out.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        qCWarning(lcLyrics) << "cannot open" << lyricsMapPath() << "for write:" << out.errorString();
        return;
    }
    const QByteArray bytes = QJsonDocument(m_lyricsMap).toJson(QJsonDocument::Compact);
    if (out.write(bytes) != bytes.size()) {
        qCWarning(lcLyrics) << "short write to" << lyricsMapPath();
        out.cancelWriting();
        return;
    }
    if (!out.commit()) {
        qCWarning(lcLyrics) << "commit failed for" << lyricsMapPath() << ":" << out.errorString();
    }
}

QString Lyrics::lyricsDir() {
    QString dir = config::ConfigSingleton::instance()->paths()->lyricsDir();
    if (dir.isEmpty()) {
        return {};
    }
    if (dir == u"~"_s) {
        dir = QDir::homePath();
    } else if (dir.startsWith(u"~/"_s)) {
        dir.replace(0, 1, QDir::homePath());
    }
    while (dir.endsWith(u'/') && dir.size() > 1) {
        dir.chop(1);
    }
    return dir;
}

QString Lyrics::lyricsMapPath() {
    return stateDir() + u"/lyrics_map.json"_s;
}

QString Lyrics::trackKey() const {
    if (m_artist.isEmpty() && m_title.isEmpty()) {
        return {};
    }
    return u"%1 - %2"_s.arg(joinArtists(m_artist), m_title);
}

QString Lyrics::backendKey(LyricsBackend value) {
    switch (value) {
    case LyricsBackend::Local:
        return u"Local"_s;
    case LyricsBackend::LRCLIB:
        return u"LRCLIB"_s;
    case LyricsBackend::NetEase:
        return u"NetEase"_s;
    case LyricsBackend::SpicyLyrics:
        return u"SpicyLyrics"_s;
    case LyricsBackend::Auto:
    default:
        return u"Auto"_s;
    }
}

LyricsBackend Lyrics::backendFromKey(const QString& key) {
    if (key.compare(u"Local"_s, Qt::CaseInsensitive) == 0) {
        return LyricsBackend::Local;
    }
    if (key.compare(u"LRCLIB"_s, Qt::CaseInsensitive) == 0) {
        return LyricsBackend::LRCLIB;
    }
    if (key.compare(u"NetEase"_s, Qt::CaseInsensitive) == 0) {
        return LyricsBackend::NetEase;
    }
    if (key.compare(u"SpicyLyrics"_s, Qt::CaseInsensitive) == 0) {
        return LyricsBackend::SpicyLyrics;
    }
    return LyricsBackend::Auto;
}

const QString& Lyrics::stateDir() {
    static const QString k_dir = [] {
        QString state = qEnvironmentVariable("XDG_STATE_HOME");
        if (state.isEmpty()) {
            state = QDir::homePath() + u"/.local/state"_s;
        }
        return state + u"/caelestia/lyrics"_s;
    }();
    return k_dir;
}

const QString& Lyrics::cacheDir() {
    static const QString k_dir = [] {
        QString cache = qEnvironmentVariable("XDG_CACHE_HOME");
        if (cache.isEmpty()) {
            cache = QDir::homePath() + u"/.cache"_s;
        }
        return cache + u"/caelestia/lyrics"_s;
    }();
    return k_dir;
}

QString Lyrics::cachePathFor(LyricsBackend backend, const QString& id) {
    if (id.isEmpty() || backend == LyricsBackend::Auto || backend == LyricsBackend::Local) {
        return {};
    }
    return u"%1/%2/%3.lrc"_s.arg(cacheDir(), backendKey(backend), sanitizeFilenamePart(id));
}

QString Lyrics::readCachedLrc(LyricsBackend backend, const QString& id) {
    const QString path = cachePathFor(backend, id);
    if (path.isEmpty()) {
        return {};
    }
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly)) {
        return {};
    }
    return QString::fromUtf8(f.readAll());
}

void Lyrics::writeCachedLrc(LyricsBackend backend, const QString& id, const QString& text) {
    if (text.isEmpty()) {
        return;
    }
    const QString path = cachePathFor(backend, id);
    if (path.isEmpty()) {
        return;
    }
    QDir().mkpath(QFileInfo(path).absolutePath());

    QSaveFile out(path);
    if (!out.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        qCWarning(lcLyrics) << "cannot open" << path << "for write:" << out.errorString();
        return;
    }
    const QByteArray bytes = text.toUtf8();
    if (out.write(bytes) != bytes.size()) {
        qCWarning(lcLyrics) << "short write to" << path;
        out.cancelWriting();
        return;
    }
    if (!out.commit()) {
        qCWarning(lcLyrics) << "commit failed for" << path << ":" << out.errorString();
    }
}

QString Lyrics::tryReadLocalLrc(const QString& dir, const QString& artist, const QString& title) {
    if (artist.isEmpty() && title.isEmpty()) {
        return {};
    }
    const QString flat = u"%1/%2 - %3.lrc"_s.arg(dir, sanitizeFilenamePart(artist), sanitizeFilenamePart(title));
    return QFile::exists(flat) ? flat : QString();
}

QString Lyrics::findLocalLrcRecursive(const QString& dir, const QString& artist, const QString& title) {
    if (dir.isEmpty()) {
        return {};
    }
    if (artist.isEmpty() && title.isEmpty()) {
        return {};
    }

    QDirIterator it(dir, QStringList{ u"*.lrc"_s }, QDir::Files | QDir::NoDotAndDotDot,
        QDirIterator::Subdirectories | QDirIterator::FollowSymlinks);

    while (it.hasNext()) {
        const QString path = it.next();
        const QString name = it.fileName();
        if ((artist.isEmpty() || containsCi(name, artist)) && (title.isEmpty() || containsCi(name, title))) {
            return path;
        }
    }
    return {};
}

/*
 * The key is a secret, so it lives in a file of its own rather than in the config, which is the
 * file people paste into issues and commit to dotfile repos. It is read on every load, so pasting
 * one in takes effect on the next track without restarting the shell.
 */
QString Lyrics::spicyKeyPath() {
    static const QString k_path = [] {
        QString config = qEnvironmentVariable("XDG_CONFIG_HOME");
        if (config.isEmpty()) {
            config = QDir::homePath() + u"/.config"_s;
        }
        return config + u"/caelestia/spicylyrics.key"_s;
    }();
    return k_path;
}

QString Lyrics::spicyKey() {
    QFile f(spicyKeyPath());
    if (!f.open(QIODevice::ReadOnly)) {
        return {};
    }
    return QString::fromUtf8(f.readAll()).trimmed();
}

/*
 * Only a syllable sync is taken here. "Line" and "Static" answers are the same kind of thing
 * LRCLIB and NetEase give, and those are what the engine already knows how to fall back to, so
 * the fallback is left to do it rather than this picking up a second line-timed source.
 *
 * Background vocals are skipped: they are a second voice with timings of their own, and the views
 * here show one line at a time, which would turn them into a duplicate row flashing straight
 * after the lead rather than a voice singing over it.
 */
QVector<LyricLine> Lyrics::parseSpicy(const QJsonObject& body) {
    if (body.value(u"Type"_s).toString() != u"Syllable"_s) {
        return {};
    }

    QVector<LyricLine> result;
    const QJsonArray content = body.value(u"Content"_s).toArray();
    result.reserve(content.size());

    for (const auto& value : content) {
        const QJsonObject part = value.toObject().value(u"Lead"_s).toObject();
        const QJsonArray syllables = part.value(u"Syllables"_s).toArray();
        if (syllables.isEmpty()) {
            continue;
        }

        QList<LyricWord> words;
        QString text;
        for (const auto& sv : syllables) {
            const QJsonObject s = sv.toObject();
            const QString piece = s.value(u"Text"_s).toString();
            if (piece.trimmed().isEmpty()) {
                continue;
            }
            /*
             * IsPartOfWord describes the gap *after* a piece, not before it: it is set on the
             * one that runs into the next. "e"(true) + "ven"(false) is "even". Read the other
             * way round, every space in the line lands one syllable late.
             */
            const bool joinNext = s.value(u"IsPartOfWord"_s).toBool();
            words.append(LyricWord{
                .start = s.value(u"StartTime"_s).toDouble(),
                .end = s.value(u"EndTime"_s).toDouble(),
                .text = piece,
                .joinNext = joinNext,
            });
            text += piece;
            if (!joinNext) {
                text += u' ';
            }
        }

        if (words.isEmpty()) {
            continue;
        }

        result.append(LyricLine{
            .time = part.value(u"StartTime"_s).toDouble(words.first().start),
            .text = text.trimmed(),
            .words = words,
        });
    }

    return result;
}

QVector<LyricLine> Lyrics::parseLrc(const QString& text) {
    QVector<LyricLine> result;
    if (text.isEmpty()) {
        return result;
    }

    static const QRegularExpression k_timeRegex(u"\\[(\\d+):(\\d+(?:\\.\\d+)?)\\]"_s);
    static const QStringList k_creditKeywords = {
        u"作词"_s,
        u"作曲"_s,
        u"编曲"_s,
        u"制作"_s,
        u"收录"_s,
        u"演奏"_s,
        u"词："_s,
        u"曲："_s,
        u"Lyricist"_s,
        u"Composer"_s,
        u"Arranger"_s,
        u"Producer"_s,
        u"Mixing"_s,
        u"Mastering"_s,
    };

    const QStringList lines = text.split(u'\n');
    for (const QString& line : lines) {
        QList<QRegularExpressionMatch> matches;
        auto it = k_timeRegex.globalMatch(line);
        while (it.hasNext()) {
            matches.append(it.next());
        }
        if (matches.isEmpty()) {
            continue;
        }

        QString lyric = line;
        lyric.replace(k_timeRegex, QString());
        lyric = lyric.trimmed();

        const qreal firstTime = matches.first().captured(1).toInt() * 60.0 + matches.first().captured(2).toDouble();

        if (firstTime < 20.0) {
            bool isCredit = false;
            for (const QString& k : k_creditKeywords) {
                if (lyric.contains(k, Qt::CaseInsensitive)) {
                    isCredit = true;
                    break;
                }
            }
            if (isCredit && (lyric.contains(u':') || lyric.contains(QChar(0xFF1A)) || lyric.size() < 25)) {
                continue;
            }
        }

        for (const auto& m : matches) {
            const qreal t = m.captured(1).toInt() * 60.0 + m.captured(2).toDouble();
            result.append(LyricLine{ .time = t, .text = lyric, .words = {} });
        }
    }

    std::ranges::sort(result, [](const LyricLine& a, const LyricLine& b) {
        return a.time < b.time;
    });

    return result;
}

} // namespace caelestia::shell::services
