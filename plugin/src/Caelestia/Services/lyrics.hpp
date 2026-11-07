#pragma once

#include <qfilesystemwatcher.h>
#include <qhash.h>
#include <qjsonobject.h>
#include <qlist.h>
#include <qnetworkaccessmanager.h>
#include <qnetworkreply.h>
#include <qtimer.h>
#include <qvariantlist.h>

#include "lyriccandidate.hpp"

namespace caelestia::shell::services {

// One timed piece of a word. A syllable sync splits "even" into "e" and "ven", and the two
// have to be drawn as one word, so each piece says whether the piece after it follows it with
// no space in between.
struct LyricWord {
    qreal start = 0.0;
    qreal end = 0.0;
    QString text;
    bool joinNext = false;
};

struct LyricLine {
    qreal time = 0.0;
    QString text;
    // Word timings, when the source had them; empty when it timed only the line. That empty
    // list is the signal to light the line whole rather than sweep it, because a sweep is a
    // claim about where in the line the voice is and nothing else here can support one.
    QList<LyricWord> words;
};

class Lyrics : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(QStringList lyrics READ lyrics NOTIFY lyricsChanged)
    // The same lines with their word timings, as [{time, text, words: [{text, start, end,
    // joinNext}]}], for the views that sweep a line rather than lighting it whole.
    Q_PROPERTY(QVariantList lines READ lines NOTIFY lyricsChanged)
    Q_PROPERTY(bool wordTimed READ wordTimed NOTIFY lyricsChanged)
    Q_PROPERTY(caelestia::shell::config::LyricsBackend::Enum backend READ backend NOTIFY backendChanged)
    Q_PROPERTY(caelestia::shell::config::LyricsBackend::Enum preferredBackend READ preferredBackend WRITE
            setPreferredBackend NOTIFY preferredBackendChanged)
    Q_PROPERTY(QList<caelestia::shell::services::LyricCandidate> lyricCandidates READ lyricCandidates NOTIFY
            lyricCandidatesChanged)
    Q_PROPERTY(caelestia::shell::services::LyricCandidate selectedCandidate READ selectedCandidate WRITE
            setSelectedCandidate NOTIFY selectedCandidateChanged)
    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)
    Q_PROPERTY(bool hasLyrics READ hasLyrics NOTIFY hasLyricsChanged)
    Q_PROPERTY(qreal offset READ offset WRITE setOffset NOTIFY offsetChanged)
    Q_PROPERTY(QString trackArtist READ trackArtist NOTIFY trackChanged)
    Q_PROPERTY(QString trackTitle READ trackTitle NOTIFY trackChanged)

public:
    explicit Lyrics(QObject* parent = nullptr);

    [[nodiscard]] QStringList lyrics() const;
    [[nodiscard]] QVariantList lines() const;
    [[nodiscard]] bool wordTimed() const;
    [[nodiscard]] LyricsBackend backend() const;
    [[nodiscard]] LyricsBackend preferredBackend() const;
    void setPreferredBackend(LyricsBackend value);
    [[nodiscard]] QList<LyricCandidate> lyricCandidates() const;
    [[nodiscard]] LyricCandidate selectedCandidate() const;
    void setSelectedCandidate(const LyricCandidate& value);
    [[nodiscard]] bool loading() const;
    [[nodiscard]] bool hasLyrics() const;
    [[nodiscard]] qreal offset() const;
    void setOffset(qreal value);
    [[nodiscard]] QString trackArtist() const;
    [[nodiscard]] QString trackTitle() const;

    [[nodiscard]] Q_INVOKABLE int indexForTime(qreal time) const;
    [[nodiscard]] Q_INVOKABLE qreal timeForIndex(int index) const;
    // How far through one word the singing is, 0 to 1, with the per-track offset applied.
    [[nodiscard]] Q_INVOKABLE qreal wordProgress(int line, int word, qreal time) const;
    Q_INVOKABLE void setTrack(const QString& artist, const QString& title, const QString& album = {},
        qreal duration = 0.0, const QString& spotifyId = {});
    Q_INVOKABLE void clearTrack();
    Q_INVOKABLE void refresh();

signals:
    void lyricsChanged();
    void backendChanged();
    void preferredBackendChanged();
    void lyricCandidatesChanged();
    void selectedCandidateChanged();
    void loadingChanged();
    void hasLyricsChanged();
    void offsetChanged();
    void trackChanged();

private:
    void setBackend(LyricsBackend value);
    void setLoading(bool value);
    void setLines(QVector<LyricLine> lines, LyricsBackend source);
    void clearLines();
    void appendCandidates(const QList<LyricCandidate>& add);
    void clearCandidates();

    void scheduleLoad();
    void doLoad();
    void cancelInFlight();
    int newRequestId();

    void tryLocal(int reqId);
    void tryLrclib(int reqId);
    void tryNetEase(int reqId);
    void trySpicy(int reqId);
    // The line-timed sources, which answer whenever no word timings were found.
    void loadFallback(int reqId);
    void chainNext(LyricsBackend justFailed, int reqId);

    void searchLrclibCandidates(int reqId);
    void searchNetEaseCandidates(int reqId);

    void fetchLrclibById(const QString& id, int reqId);
    void fetchNetEaseLyricsById(const QString& id, int reqId);

    QNetworkReply* getJson(const QUrl& url, const QHash<QByteArray, QByteArray>& headers = {});
    void trackReply(int reqId, QNetworkReply* reply);

    void onPreferredBackendConfigChanged();
    void onLyricsDirChanged();
    void watchSpicyKey();
    void onSpicyKeyChanged();

    void loadLyricsMap();
    void persistTrackPrefs();

    [[nodiscard]] static QString lyricsDir();
    [[nodiscard]] static QString lyricsMapPath();
    [[nodiscard]] QString trackKey() const;
    [[nodiscard]] static QString backendKey(LyricsBackend value);
    [[nodiscard]] static LyricsBackend backendFromKey(const QString& key);

    [[nodiscard]] static const QString& stateDir();
    [[nodiscard]] static const QString& cacheDir();
    [[nodiscard]] static QString cachePathFor(LyricsBackend backend, const QString& id);
    [[nodiscard]] static QString readCachedLrc(LyricsBackend backend, const QString& id);
    static void writeCachedLrc(LyricsBackend backend, const QString& id, const QString& text);

    [[nodiscard]] static QString spicyKeyPath();
    [[nodiscard]] static QString spicyKey();
    [[nodiscard]] static QVector<LyricLine> parseSpicy(const QJsonObject& body);

    [[nodiscard]] static QVector<LyricLine> parseLrc(const QString& text);
    [[nodiscard]] static QString tryReadLocalLrc(const QString& dir, const QString& artist, const QString& title);
    [[nodiscard]] static QString findLocalLrcRecursive(const QString& dir, const QString& artist, const QString& title);

    QNetworkAccessManager* m_nam;
    QTimer* m_loadDebounce;
    QFileSystemWatcher* m_keyWatcher;

    QVector<LyricLine> m_lines;
    QStringList m_lyrics;
    LyricsBackend m_backend = LyricsBackend::Auto;
    LyricsBackend m_preferredBackend = LyricsBackend::Auto;
    QList<LyricCandidate> m_candidates;
    LyricCandidate m_selected;
    bool m_loading = false;
    bool m_hasLyrics = false;
    qreal m_offset = 0.0;

    QString m_artist;
    QString m_title;
    QString m_album;
    qreal m_duration = 0.0;
    // Spotify's own id for the track, which is what the word-timed source is asked by.
    QString m_spotifyId;
    // The key as it was last seen, so a stir in the config directory that left it alone costs a
    // read and nothing else.
    QString m_lastSpicyKey;
    bool m_wordTimed = false;

    int m_currentRequestId = 0;
    QHash<int, QList<QPointer<QNetworkReply>>> m_pendingReplies;

    QJsonObject m_lyricsMap;
    bool m_lyricsMapLoaded = false;
    bool m_settingFromPrefs = false;
};

} // namespace caelestia::shell::services
