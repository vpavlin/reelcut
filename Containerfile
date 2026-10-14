# reelcut: yt-dlp, ffmpeg, Parakeet (whisper.cpp's parakeet-cli) and its model,
# in one image. Build: podman build -t reelcut .   Run: see README.md.

FROM docker.io/library/debian:trixie-slim AS build
ARG WHISPER_COMMIT=60c0be6ac8fa71b1a2ae2dd938a31a34a508e774
RUN apt-get update -qq && apt-get install -y -qq --no-install-recommends \
        git cmake build-essential ca-certificates >/dev/null
RUN git clone -q https://github.com/ggml-org/whisper.cpp /src && cd /src && git checkout -q $WHISPER_COMMIT \
    && cmake -B build -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DWHISPER_BUILD_TESTS=OFF \
        -DGGML_NATIVE=OFF >/dev/null \
    && cmake --build build -j"$(nproc)" --target parakeet-cli >/dev/null \
    && install -m 755 build/bin/parakeet-cli /usr/local/bin/

FROM docker.io/library/debian:trixie-slim
ARG MODEL=ggml-parakeet-tdt-0.6b-v3-q4_k.bin
ARG MODEL_SHA256=8b205b8b39c6535e153de6fb11c51db46125d45c4f16ba496fe41a0fe71b885e
RUN apt-get update -qq && apt-get install -y -qq --no-install-recommends \
        ffmpeg python3 python3-numpy python3-pip fonts-dejavu-core libgomp1 ca-certificates curl unzip >/dev/null \
    && rm -rf /var/lib/apt/lists/*
# OpenCV for --frame speaker: the headless wheel (~50 MB), not Debian's
# python3-opencv, which brings a GUI and a video stack and adds 700 MB.
RUN pip install --no-cache-dir --break-system-packages --no-deps opencv-python-headless==4.10.0.84 \
    && apt-get purge -y -qq python3-pip >/dev/null && apt-get autoremove -y -qq >/dev/null
# yt-dlp moves with YouTube: the newest release at build time, and Deno, the
# JavaScript runtime it now needs for YouTube.
RUN curl -fsSL -o /usr/local/bin/yt-dlp https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp \
    && chmod 755 /usr/local/bin/yt-dlp \
    && curl -fsSL -o /tmp/deno.zip "https://github.com/denoland/deno/releases/latest/download/deno-$(uname -m)-unknown-linux-gnu.zip" \
    && unzip -q /tmp/deno.zip -d /usr/local/bin && rm /tmp/deno.zip
RUN mkdir -p /models && curl -fsSL -o /models/$MODEL https://huggingface.co/ggml-org/parakeet-GGUF/resolve/main/$MODEL \
    && echo "$MODEL_SHA256  /models/$MODEL" | sha256sum -c --quiet
# The face detector for --frame speaker (OpenCV's YuNet, 230 KB), checked.
ARG FACE_SHA256=8f2383e4dd3cfbb4553ea8718107fc0423210dc964f9f4280604804ed2552fa4
RUN curl -fsSL -o /models/yunet.onnx https://media.githubusercontent.com/media/opencv/opencv_zoo/main/models/face_detection_yunet/face_detection_yunet_2023mar.onnx \
    && echo "$FACE_SHA256  /models/yunet.onnx" | sha256sum -c --quiet
COPY --from=build /usr/local/bin/parakeet-cli /usr/local/bin/
COPY reelcut /usr/local/bin/reelcut
ENV REELCUT_MODEL=/models/$MODEL REELCUT_PARAKEET=/usr/local/bin/parakeet-cli REELCUT_FACE_MODEL=/models/yunet.onnx
WORKDIR /work
ENTRYPOINT ["reelcut"]
