# reelcut

From a long video to short vertical reels with captions that follow the
words. Transcription runs locally on the CPU with
[Parakeet](https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3) (via
whisper.cpp's `parakeet-cli`), so an hour of audio costs no API tokens. Only
picking the clips needs a model, and that can be any model, or a person.

```
reelcut fetch URL DIR           # audio + video with yt-dlp
reelcut transcribe DIR          # words.json, transcript-ts.txt, transcript.txt
reelcut prompt DIR              # what to ask a model to pick the clips
reelcut cut DIR clips.txt OUT   # one 1080x1920 reel per clip
reelcut page OUT                # an index.html that plays them
```

An 82-minute talk transcribed in 7 minutes on a 20-core laptop. The six reels
cut from it took about 8 seconds each.

## With the container

The image carries yt-dlp, ffmpeg, `parakeet-cli` and the model (about 1 GB),
for amd64 and arm64:

```
alias reelcut='podman run --rm -v "$PWD":/work:Z ghcr.io/vpavlin/reelcut'
reelcut fetch 'https://www.youtube.com/watch?v=…' /work/talk
reelcut transcribe /work/talk
reelcut prompt /work/talk > talk/prompt.txt     # give this to a model
# save its answer as talk/clips.txt
reelcut cut /work/talk /work/talk/clips.txt /work/talk/reels --fix Meakin=Mencken
reelcut page /work/talk/reels --title "Highlights"
```

To build it yourself: `podman build -t reelcut .`

## Without it

You need Python 3, ffmpeg, yt-dlp, the DejaVu fonts, and `parakeet-cli` with
its model: build whisper.cpp's `parakeet-cli` target and download
`ggml-parakeet-tdt-0.6b-v3-q4_k.bin` from `ggml-org/parakeet-GGUF`. The
Containerfile has the exact commands. Point at them with `REELCUT_PARAKEET`
and `REELCUT_MODEL` if they are not in `~/.local/bin` and
`~/.local/share/whisper`.

## The clips file

One clip per line, as `reelcut prompt` asks for:

```
1 | 0:35:52 | 0:36:32 | Sal | Blockchain analytics is voodoo | until voodoo
```

START is the stamp of the first sentence, END the stamp of the last sentence,
both from `transcript-ts.txt`. `until` names the clip's last word, which pins
the cut when two sentences share a stamp.

## Captions

- four words at a time, the one being said in yellow;
- the hook title for the first 3.5 seconds;
- "um" and "uh" left out (`--keep-fillers` keeps them), but kept in the sound;
- misheard words fixed with `--fix HEARD=MEANT`; check names against the
  video, because they are what the transcription gets wrong most;
- placed for a portrait layout. Move them with `--caption-margin` and
  `--hook-margin`. A landscape video is cropped to 9:16 around its middle.

## For agents

`skills/reelcut/SKILL.md` is a Claude Code skill for the whole flow, with
the traps already hit. Copy or link it into `~/.claude/skills/`.

## License

Dual-licensed under [MIT](LICENSE-MIT) or [Apache 2.0](LICENSE-APACHE-v2),
at your option.
