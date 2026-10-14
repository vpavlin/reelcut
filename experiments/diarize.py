"""Who speaks when: sherpa-onnx offline diarization (pyannote segmentation +
TitaNet embeddings), then each word of words.json labelled with its speaker.
diarize.py DIR [NUM_SPEAKERS]"""
import json, os, subprocess, sys, time
import numpy as np
import sherpa_onnx

d = sys.argv[1]
n = int(sys.argv[2]) if len(sys.argv) > 2 else 2
M = '/tmp/diar-models'
src = next(os.path.join(d, f) for f in sorted(os.listdir(d)) if f.startswith(('audio.', 'video.')))
pcm = subprocess.run(['ffmpeg', '-loglevel', 'error', '-i', src, '-ac', '1', '-ar', '16000', '-f', 's16le', '-'],
                     capture_output=True, check=True).stdout
samples = np.frombuffer(pcm, dtype=np.int16).astype(np.float32) / 32768
cfg = sherpa_onnx.OfflineSpeakerDiarizationConfig(
    segmentation=sherpa_onnx.OfflineSpeakerSegmentationModelConfig(
        pyannote=sherpa_onnx.OfflineSpeakerSegmentationPyannoteModelConfig(
            model=f'{M}/sherpa-onnx-pyannote-segmentation-3-0/model.onnx'), num_threads=8),
    embedding=sherpa_onnx.SpeakerEmbeddingExtractorConfig(model=f'{M}/titanet.onnx', num_threads=8),
    clustering=sherpa_onnx.FastClusteringConfig(num_clusters=n),
    min_duration_on=0.3, min_duration_off=0.5)
t = time.time()
segs = sherpa_onnx.OfflineSpeakerDiarization(cfg).process(samples).sort_by_start_time()
took = time.time() - t
segs = [(s.start, s.end, s.speaker) for s in segs]
words = json.load(open(os.path.join(d, 'words.json')))
labelled = []
for a, b, w in words:
    mid = (a + b) / 2
    hit = [sp for s0, s1, sp in segs if s0 <= mid <= s1]
    if not hit:  # in a gap: the nearest segment
        hit = [min(segs, key=lambda s: min(abs(s[0] - mid), abs(s[1] - mid)))[2]]
    labelled.append([a, b, w, chr(65 + hit[0])])
json.dump(labelled, open(os.path.join(d, 'words-spk.json'), 'w'))
dur = len(samples) / 16000
print(f'{dur:.0f} s of audio diarized in {took:.1f} s ({dur / took:.0f}x real time), {len(segs)} segments')
# Sentences with the speaker who said most of their words.
out, cur = [], []
for w in labelled:
    cur.append(w)
    if w[2].endswith(('.', '?', '!')) and not (len(w[2]) == 2 and w[2][0].isupper()):
        out.append(cur); cur = []
if cur: out.append(cur)
for s in out:
    spk = max(set(x[3] for x in s), key=[x[3] for x in s].count)
    mixed = '' if len(set(x[3] for x in s)) == 1 else ' (mixed)'
    t0 = int(s[0][0])
    print(f'[{t0 // 60}:{t0 % 60:02d}] {spk}{mixed}: ' + ' '.join(x[2] for x in s)[:90])
