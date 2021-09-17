FROM debian:bullseye-slim

ARG FFMPEG_VERSION=4.4
ARG IMAGEMAGICK_VERSION=7.1.0-7

RUN sed -i "s#deb http://deb.debian.org/debian bullseye main#deb http://deb.debian.org/debian bullseye main non-free#g" /etc/apt/sources.list && \
    apt-get -y update && \
    apt-get -y upgrade && \
    apt-get install -y \
    # General build stuff, both for IM and ffmpeg
    automake make cmake gcc g++ git-core meson ninja-build pkg-config texinfo wget yasm \
    # ffmpeg
    libxcb-shm0 libxcb-shape0 libxcb-xfixes0 libasound2 libsdl2-2.0-0 libsndio7.0 libxv1 libva2 libva-x11-2 libva-drm2 libvdpau1 libfdk-aac2 libx264-160 \
    # ffmpeg devel
    nasm libx264-dev libfdk-aac-dev libopus-dev libvorbis-dev libgnutls28-dev libsdl2-dev libtool libva-dev libvdpau-dev libxcb1-dev libxcb-shm0-dev libxcb-xfixes0-dev zlib1g-dev libunistring-dev \
    # IM
    libpng16-16 libjpeg62-turbo liblqr-1-0 libwebp6 libwebpmux3 libwebpdemux2 libgomp1 \
    # IM devel
    libpng-dev libjpeg62-turbo-dev libglib2.0-dev liblqr-1-0-dev libwebp-dev && \
    # Building ffmpeg
    mkdir -p ~/ffmpeg_sources ~/bin && \
    cd ~/ffmpeg_sources && \
    wget https://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.bz2 && \
    tar xjvf ffmpeg-${FFMPEG_VERSION}.tar.bz2 && \
    cd ffmpeg-${FFMPEG_VERSION} && \
    PKG_CONFIG_PATH="$HOME/ffmpeg_build/lib/pkgconfig" ./configure \
    --prefix="$HOME/ffmpeg_build" \
    --pkg-config-flags="--static" \
    --extra-cflags="-I$HOME/ffmpeg_build/include" \
    --extra-ldflags="-L$HOME/ffmpeg_build/lib" \
    --extra-libs="-lpthread -lm" \
    --ld="g++" \
    --bindir="/bin" \
    --enable-gpl \
    --enable-gnutls \
    --enable-libfdk-aac \
    --enable-libopus \
    --enable-libvorbis \
    --enable-libx264 \
    --enable-nonfree && \
    make && \
    make install && \
    hash -r && \
    # Building ImageMagick
    git clone https://github.com/ImageMagick/ImageMagick.git && \
    cd ImageMagick && git checkout ${IMAGEMAGICK_VERSION} && \
    ./configure --without-magick-plus-plus --disable-docs --disable-static && \
    make && make install && \
    ldconfig /usr/local/lib && \
    # Cleanup
    apt-get remove --autoremove --purge -y autoconf automake make cmake gcc g++ git-core meson ninja-build pkg-config texinfo wget yasm nasm libx264-dev libfdk-aac-dev libopus-dev libvorbis-dev libgnutls28-dev libsdl2-dev libtool libva-dev libvdpau-dev libxcb1-dev libxcb-shm0-dev libxcb-xfixes0-dev zlib1g-dev libunistring-dev libpng-dev libjpeg62-turbo-dev libglib2.0-dev liblqr-1-0-dev libwebp-dev && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf ffmpeg_sources && \
    rm -rf ffmpeg-${FFMPEG_VERSION} && \
    rm -rf /ImageMagick

ENTRYPOINT [ "bash" ]