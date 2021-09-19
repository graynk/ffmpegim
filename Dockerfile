FROM debian:bullseye-slim as base

RUN apt-get -yqq update && \
    apt-get -yqq upgrade && \
    apt-get -yqq install --no-install-recommends ca-certificates expat libgomp1 libjpeg62-turbo libglib2.0-0 && \
    apt-get -yqq autoremove && \
    apt-get -yqq clean

FROM base as build

ENV FFMPEG_VERSION=4.4 \
    FDKAAC_VERSION=0.1.5 \
    OGG_VERSION=1.3.2 \
    OPUS_VERSION=1.2 \
    OPENJPEG_VERSION=2.1.2 \
    VORBIS_VERSION=1.3.5 \
    WEBP_VERSION=1.0.2 \
    X264_VERSION=20170226-2245-stable \
    LIBPNG_VERSION=1.6.9 \
    LIBJPEGTURBO_VERSION=2.1.1 \
    LIBLQR_VERSION=0.4.2 \
    IMAGEMAGICK_VERSION=7.1.0-8 \
    SRC=/usr/local

ARG OGG_SHA256SUM="e19ee34711d7af328cb26287f4137e70630e7261b17cbe3cd41011d73a654692 libogg-1.3.2.tar.gz"
ARG OPUS_SHA256SUM="77db45a87b51578fbc49555ef1b10926179861d854eb2613207dc79d9ec0a9a9 opus-1.2.tar.gz"
ARG VORBIS_SHA256SUM="6efbcecdd3e5dfbf090341b485da9d176eb250d893e3eb378c428a2db38301ce libvorbis-1.3.5.tar.gz"


ARG LD_LIBRARY_PATH=/opt/ffmpegim/lib
ARG MAKEFLAGS="-j2"
ARG PKG_CONFIG_PATH="/opt/ffmpegim/share/pkgconfig:/opt/ffmpegim/lib/pkgconfig:/opt/ffmpegim/lib64/pkgconfig"
ARG PREFIX=/opt/ffmpegim
ARG LD_LIBRARY_PATH="/opt/ffmpegim/lib:/opt/ffmpegim/lib64"


ARG DEBIAN_FRONTEND=noninteractive

RUN buildDeps="autoconf \
    automake \
    cmake \
    curl \
    bzip2 \
    libexpat1-dev \
    g++ \
    gcc \
    git \
    gperf \
    libtool \
    make \
    meson \
    nasm \
    perl \
    pkg-config \
    python \
    libssl-dev \
    yasm \
    zlib1g-dev \
    libglib2.0-dev \
    libjpeg62-turbo-dev" && \
    apt-get -yqq update && \
    apt-get -yqq install --no-install-recommends ${buildDeps}

## build deps
## x264 http://www.videolan.org/developers/x264.html
RUN \
    DIR=/tmp/x264 && \
    mkdir -p ${DIR} && \
    cd ${DIR} && \
    curl -sL https://download.videolan.org/pub/videolan/x264/snapshots/x264-snapshot-${X264_VERSION}.tar.bz2 | \
    tar -jx --strip-components=1 && \
    ./configure --prefix="${PREFIX}" --enable-shared --enable-pic --disable-cli && \
    make && \
    make install && \
    rm -rf ${DIR}

## libogg https://www.xiph.org/ogg/
RUN \
    DIR=/tmp/ogg && \
    mkdir -p ${DIR} && \
    cd ${DIR} && \
    curl -sLO http://downloads.xiph.org/releases/ogg/libogg-${OGG_VERSION}.tar.gz && \
    echo ${OGG_SHA256SUM} | sha256sum --check && \
    tar -zx --strip-components=1 -f libogg-${OGG_VERSION}.tar.gz && \
    ./configure --prefix="${PREFIX}" --enable-shared  && \
    make && \
    make install && \
    rm -rf ${DIR}

## libopus https://www.opus-codec.org/
RUN \
    DIR=/tmp/opus && \
    mkdir -p ${DIR} && \
    cd ${DIR} && \
    curl -sLO https://archive.mozilla.org/pub/opus/opus-${OPUS_VERSION}.tar.gz && \
    echo ${OPUS_SHA256SUM} | sha256sum --check && \
    tar -zx --strip-components=1 -f opus-${OPUS_VERSION}.tar.gz && \
    autoreconf -fiv && \
    ./configure --prefix="${PREFIX}" --enable-shared && \
    make && \
    make install && \
    rm -rf ${DIR}

## libvorbis https://xiph.org/vorbis/
RUN \
    DIR=/tmp/vorbis && \
    mkdir -p ${DIR} && \
    cd ${DIR} && \
    curl -sLO http://downloads.xiph.org/releases/vorbis/libvorbis-${VORBIS_VERSION}.tar.gz && \
    echo ${VORBIS_SHA256SUM} | sha256sum --check && \
    tar -zx --strip-components=1 -f libvorbis-${VORBIS_VERSION}.tar.gz && \
    ./configure --prefix="${PREFIX}" --with-ogg="${PREFIX}" --enable-shared && \
    make && \
    make install && \
    rm -rf ${DIR}

## fdk-aac https://github.com/mstorsjo/fdk-aac
RUN \
    DIR=/tmp/fdk-aac && \
    mkdir -p ${DIR} && \
    cd ${DIR} && \
    curl -sL https://github.com/mstorsjo/fdk-aac/archive/v${FDKAAC_VERSION}.tar.gz | \
    tar -zx --strip-components=1 && \
    autoreconf -fiv && \
    ./configure --prefix="${PREFIX}" --enable-shared --datadir="${DIR}" && \
    make && \
    make install && \
    rm -rf ${DIR}

## openjpeg https://github.com/uclouvain/openjpeg
RUN \
    DIR=/tmp/openjpeg && \
    mkdir -p ${DIR} && \
    cd ${DIR} && \
    curl -sL https://github.com/uclouvain/openjpeg/archive/v${OPENJPEG_VERSION}.tar.gz | \
    tar -zx --strip-components=1 && \
    cmake -DBUILD_THIRDPARTY:BOOL=ON -DCMAKE_INSTALL_PREFIX="${PREFIX}" . && \
    make && \
    make install && \
    rm -rf ${DIR}

## libpng https://git.code.sf.net/p/libpng
RUN \
    DIR=/tmp/png && \
    mkdir -p ${DIR} && \
    cd ${DIR} && \
    git clone https://git.code.sf.net/p/libpng/code ${DIR} -b v${LIBPNG_VERSION} --depth 1 && \
    ./autogen.sh && \
    ./configure --prefix="${PREFIX}" && \
    make check && \
    make install && \
    rm -rf ${DIR}

## Build ffmpeg
## ffmpeg https://ffmpeg.org/
RUN  \
    DIR=/tmp/ffmpeg && mkdir -p ${DIR} && cd ${DIR} && \
    curl -sLO https://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.bz2 && \
    tar -jx --strip-components=1 -f ffmpeg-${FFMPEG_VERSION}.tar.bz2

RUN \
    DIR=/tmp/ffmpeg && mkdir -p ${DIR} && cd ${DIR} && \
    ./configure \
    --disable-debug \
    --disable-doc \
    --disable-ffplay \
    --enable-shared \
    --enable-gpl \
    --enable-libopus \
    --enable-libvorbis \
    --enable-libx264 \
    --enable-nonfree \
    --enable-libfdk_aac \
    --prefix="${PREFIX}" \
    --enable-libopenjpeg \
    --extra-libs=-lpthread \
    --extra-cflags="-I${PREFIX}/include" \
    --extra-ldflags="-L${PREFIX}/lib" && \
    make && \
    make install && \
    make distclean && \
    hash -r

## Additional IM deps. TODO: compile libjpeg-turbo as well
## libwebp https://developers.google.com/speed/webp/
RUN \
    DIR=/tmp/vebp && \
    mkdir -p ${DIR} && \
    cd ${DIR} && \
    curl -sL https://storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-${WEBP_VERSION}.tar.gz | \
    tar -zx --strip-components=1 && \
    ./configure --prefix="${PREFIX}" --enable-shared && \
    make && \
    make install && \
    rm -rf ${DIR}
## liblqr https://github.com/carlobaldassi/liblqr
RUN \
    DIR=/tmp/liblqr && \
    mkdir -p ${DIR} && \
    cd ${DIR} && \
    git clone https://github.com/carlobaldassi/liblqr.git ${DIR} -b v${LIBLQR_VERSION} --depth 1 && \
    ./configure --prefix="${PREFIX}" --enable-shared && \
    make check && \
    make install && \
    rm -rf ${DIR}

# Build ImageMagick
RUN \
    DIR=/tmp/ImageMagick && \
    git clone https://github.com/ImageMagick/ImageMagick.git ${DIR} -b ${IMAGEMAGICK_VERSION} --depth 1 && \
    cd ${DIR} && \
    ./configure \
    --prefix="${PREFIX}" \
    --enable-shared=yes \
    --with-quantum-depth=8 \
    --with-jpeg=yes	\
    --with-lqr=yes \
    --with-png=yes \
    --disable-docs \
    --enable-hdri=no && \
    make && \
    make install

## Cleanup
RUN \
    ldd ${PREFIX}/bin/ffmpeg | grep opt/ffmpeg | cut -d ' ' -f 3 | xargs -i cp {} /usr/local/lib/ && \
    ldd ${PREFIX}/bin/magick | grep opt/ffmpeg | cut -d ' ' -f 3 | xargs -i cp {} /usr/local/lib/ && \
    for lib in /usr/local/lib/*.so.*; do ln -s "${lib##*/}" "${lib%%.so.*}".so; done && \
    cp ${PREFIX}/bin/* /usr/local/bin/ && \
    cp -r ${PREFIX}/share/ImageMagick* /usr/local/share/ && \
    cp -r ${PREFIX}/share/ffmpeg /usr/local/share/ && \
    cp -r ${PREFIX}/include/libav* ${PREFIX}/include/libpostproc ${PREFIX}/include/libsw* ${PREFIX}/include/ImageMagick* ${PREFIX}/include/lqr* ${PREFIX}/include/webp /usr/local/include && \
    mkdir -p /usr/local/lib/pkgconfig && \
    for pc in ${PREFIX}/lib/pkgconfig/libav*.pc ${PREFIX}/lib/pkgconfig/libpostproc.pc ${PREFIX}/lib/pkgconfig/libsw*.pc ${PREFIX}/lib/pkgconfig/ImageMagick*.pc ${PREFIX}/lib/pkgconfig/Magick*.pc ${PREFIX}/lib/pkgconfig/lqr*.pc ${PREFIX}/lib/pkgconfig/libwebp*.pc; do \
    sed "s:${PREFIX}:/usr/local:g" <"$pc" >/usr/local/lib/pkgconfig/"${pc##*/}"; \
    done

FROM base AS release
ENV LD_LIBRARY_PATH=/usr/local/lib:/usr/local/lib64

COPY --from=build /usr/local /usr/local/

ENTRYPOINT [ "bash" ]