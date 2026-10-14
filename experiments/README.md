# Experiments

## Who speaks when: diarization (`diarize.py`), 2026-10-14

Parakeet's transcript has words and times, not speakers. `diarize.py` labels
every word in `words.json` with a speaker (`words-spk.json`) using
sherpa-onnx's offline diarization: pyannote segmentation 3.0 plus NVIDIA
TitaNet-small speaker embeddings. Both are small ONNX models, run on the CPU,
and need no account.

Setup used:

```
python3 -m venv /tmp/diar-venv && /tmp/diar-venv/bin/pip install sherpa-onnx numpy
# models, into /tmp/diar-models (the script's M):
#   github.com/k2-fsa/sherpa-onnx/releases/download/speaker-segmentation-models/sherpa-onnx-pyannote-segmentation-3-0.tar.bz2
#   github.com/k2-fsa/sherpa-onnx/releases/download/speaker-recongition-models/nemo_en_titanet_small.onnx
/tmp/diar-venv/bin/python experiments/diarize.py DIR [NUM_SPEAKERS]
```

Tested on 4 minutes of a Logos podcast intro, with three voices (a narrator,
the host, the guest):

- **9x real time** on 8 threads (240 s in 28 s).
- **With the right speaker count (3), all three voices were separated
  correctly**, including the host-to-guest turn at 3:42. Mouth-movement
  speaker detection got that turn wrong by about 6 s.
- With too few speakers (2), the narrator was merged with the guest. The
  count matters; ask the person, or try automatic clustering.
- Boundaries are off by about a sentence at most: "Yeah, absolutely.",
  which opens a turn, went to the previous speaker.

Where it would go, not built yet:

1. `reelcut diarize DIR` writes the speaker into `words.json`, and
   `transcript-ts.txt` shows `A:` / `B:`. The clip picker then sees who said
   what.
2. A person names the speakers once (`--speakers "A=Petty,B=Václav"`, or a
   dropdown per face in the app), mapping voices to faces.
3. `--frame stack` gets captions in the speaker's colour and the active
   half highlighted; `--frame speaker` follows the labelled turns instead of
   guessing from mouths.
