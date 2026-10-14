---
name: reelcut
description: Turn a long video (a livestream, an X/Twitter Space, a talk, a meeting recording, a podcast with video) into short vertical reels with burned-in, word-by-word captions, or just transcribe a video locally with timestamps. Use when someone asks for highlights, spicy bits, clips, reels, shorts or TikToks from a recording, a summary of a video, or a transcript of a video or meeting. Runs transcription locally (Parakeet, CPU), so long recordings cost no model tokens; only picking the clips needs a model, and that can be any agent.
---

# reelcut

From a long recording to reels: fetch → transcribe → pick → cut → page.
The tool is `reelcut` (a single Python script), or the container image
`reelcut`, which carries yt-dlp, ffmpeg, Parakeet and its model:

```
alias reelcut='podman run --rm -v "$PWD":/work:z reelcut'   # paths below are then under /work
```

## Steps

1. **Fetch:** `reelcut fetch URL DIR` downloads `audio.*`, `video.mp4` and
   `meta.tsv` (title, channel, duration, date). For a local file, copy it to
   `DIR/video.mp4`. The audio is optional, and the video's own sound is used
   without it.
2. **Transcribe:** `reelcut transcribe DIR`. The audio is cut into 60 s
   pieces and Parakeet runs several pieces at once (`--threads` per piece,
   `--jobs` pieces at a time). It writes:
   - `words.json`: one `[start, end, word]` per word, in seconds;
   - `transcript-ts.txt`: one `[H:MM:SS]` per sentence;
   - `transcript.txt`: one marker per minute, for reading.

   Speed: about 12× real time on a 20-core laptop. An 82-minute talk took
   7 minutes.
3. **Summarise or pick:** `reelcut prompt DIR` prints the instructions and
   the transcript, which can go to any model. To save your own quota, hand
   the transcript to a cheaper agent: put it where that agent can read it,
   and ask for clips in this format:
   `N | START H:MM:SS | END H:MM:SS | speaker | hook title | until LASTWORD`
4. **Cut:** `reelcut cut DIR clips.txt OUT --fix Heard=Meant …` writes one
   `NN-hook.mp4` per clip. Each is 1080×1920 with captions four words at a
   time, the word being spoken in yellow, the hook title shown for 3.5 s,
   and short fades. A landscape recording is cropped to 9:16 around its
   middle. Each line it prints ends with the clip's last words: check them.
5. **Page:** `reelcut page OUT --title "…"` writes an `index.html` that plays
   them all.

## Picking: what makes a clip

- It has to stand on its own: a strong claim, a joke that lands, a quotable
  one-liner, a vivid image. Start on the setup and end right after the
  punchline, never trailing off. 20–55 s works best.
- Use a mix of speakers, and skip the pre-show and housekeeping.
- Leave out a moment whose payoff rests on a slur, however funny. If the
  user insists, keep it for a private cut only.

## Checking before you deliver

- **Names:** the transcription mishears names (an "H. L. Mencken" became
  "Meakin"; "Sterlin" became "Sterling"). Read each name in the clips
  against the video itself (on-screen labels, the title, the description)
  and fix them with `--fix`. Ask the user if unsure. Getting a person's name
  wrong is the mistake people notice.
- **Fillers** ("um", "uh") are removed from the captions by default and kept
  in the sound. `--keep-fillers` keeps them in the captions too.
- **The end:** the cut ends at the end of the sentence starting at END, or at
  LASTWORD if it is given. Use LASTWORD whenever two sentences share a stamp.
- **Look at a frame** of one reel (`ffmpeg -ss 5 -i reel.mp4 -frames:v 1
  f.jpg`). If captions sit on something important, move them with
  `--caption-margin` and `--hook-margin` (px from the bottom and from the
  top of 1920).

## Traps already hit

- Parakeet prints the word timings on **stderr**. Its stdout holds only the
  text. `reelcut` keeps both; a hand-rolled pipeline that drops stderr loses
  all the timings.
- A portrait video's 1080p format is 1920 tall: a `height<=1080` filter
  skips it. `fetch` ranks formats instead (`-S res:1080,proto:https,…`,
  where res is the shorter side) and prefers plain https: HLS (m3u8)
  formats come in throttled fragments, about 300 KB/s.
- yt-dlp falls behind YouTube; an HTTP 403 on everything usually means
  `yt-dlp -U`, or rebuilding the image.
- Mount with `:z` (lower case), never `:Z`, on an SELinux machine. `:Z`
  gives the folder a label private to one container, so a second container
  on the same folder (a fetch beside a transcribe, a `prompt` call) takes it
  away from the first, which then fails mid-write with a bare
  `PermissionError` (scribe, 2026-10-13). `:z` shares the label.
- Initials ("H. L.") are not sentence ends. `reelcut` knows this, so don't
  count sentences by `.` yourself.

## Delivering

Name each reel by its hook. Publishing is the user's call: ask where the
reels should go (a share link, a page) unless they have said.
