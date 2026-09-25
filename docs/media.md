# Media player, library and queue

The dashboard's media tab controls whatever is playing - an external MPRIS player or the built-in
local player - and the notification popout's library tab is where you browse and choose what to play.

[▶ Demo: the media tab](https://cykler.dev/caelestia/demos/media-player.mp4) ·
[▶ Demo: the library](https://cykler.dev/caelestia/demos/music-library.mp4)

## The media tab

One tab for every source, so the cover, lyrics and visualiser follow whatever is playing and the same
controls drive it. The source picker switches between the open MPRIS players and the built-in player,
and when there is nothing to control the tab says so rather than pretending there is something to
play.

This tab is only about controlling what is already playing - choosing music is the library's job.

[The equalizer](equalizer.md) is in a drawer under the player here once it has been switched on.

## Following what plays, and pinning a player

By default the tab follows your audio: a player that starts playing becomes the active one, and if the
active one stops while another is still playing, that one takes over. With nothing playing, the player
set as `services.defaultPlayer` wins, and failing that the first one open.

Picking a player by hand in the source picker **pins** it. While a pinned player is playing, nothing
else takes over from it, so clicking through tracks in the player you care about does not get
interrupted by, say, a browser tab starting a video. The pin lets go when that player stops, and the
automatic following resumes.

## The local player

Plays the audio files under `paths.musicDir` (defaults to your music folder, i.e. `~/Music`) in-shell:

- Seek, volume, shuffle (off / on) and repeat (off / all / one).
- Playing a track starts a fresh queue from what the list is showing, so a folder plays through
  instead of stopping after one song.
- **Shuffle reorders the queue** rather than leaving the list in one order and picking at random, so
  the queue the view shows is the order that plays. Switching it off puts the songs that have not
  played back in the order they were in, leaving anything added or moved while it was on where it is.

## The library

The notification popout's library tab lists the music folder. It is only built the first time you open
that tab, so the notification side stays as cheap to open as it was.

- **Browse by folder** - the folders under the music folder as they are on disk, with a breadcrumb
  beside the up and home buttons for climbing back out.
- **Cover art on every row** - a folder's own cover, a track's own art, or an icon on a rounded
  placeholder when there is none. Folders show how many tracks they hold and the playing track is
  marked.
- **Search that knows artists** - the search box matches titles, artists and albums across the whole
  library as well as paths, so an artist brings up everything by them while a folder or album name
  still finds its tracks. Artists come from the files' own tags, read by TagLib in the background and
  only when something asks for them, so a session that never searches never pays for the scan.
- **Add to queue** - the checklist button turns taps on tracks into a selection instead of playback.
  The selection is kept by path rather than by list position, so opening a folder or typing a search
  does not throw it away; *Add to queue* then appends them in the order they were picked. The button
  beside it takes everything the list is currently showing and gives it back again if it is all
  already selected. Adding never interrupts what is playing.

Under the list is a seek bar and a transport bar (shuffle, previous, play/pause, next, repeat). Those
are wired to the local player alone, so they keep driving the local queue while a browser is what is
playing, and they are disabled rather than hidden while nothing is queued. See
[notification-popout.md](notification-popout.md).

## Cover art

Art embedded in the track is shown first, falling back to an image named after the track (what yt-dlp
leaves behind, since Opus cannot hold one) and then to a `cover`, `folder` or `album` image in the
track's folder. Embedded art arrives from QtMultimedia as a `QImage`, which `Image.source` cannot take
directly, so it goes through the image cache first, keyed by content so the same artwork is only
written once.

## Known gap

Qt's ffmpeg backend only surfaces container-level tags. mp3 (ID3), flac and m4a tags are read
correctly, but Ogg/Opus puts its Vorbis comments on the stream instead, so those tracks show their file
name with no artist or album. Cover art is unaffected.

## Config

```json
"paths": {
    "musicDir": "~/Music"
}
```
