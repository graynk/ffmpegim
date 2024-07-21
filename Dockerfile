FROM jrottenberg/ffmpeg:7-nvidia as base

RUN apt-get -yqq update && \
    apt-get -yqq upgrade && \
    apt-get -yqq install --no-install-recommends ca-certificates expat libgomp1 libturbojpeg libglib2.0-0 && \
    apt-get -yqq autoremove && \
    apt-get -yqq clean

FROM base as build

ENV OPENJPEG_VERSION=2.5.2 \
    WEBP_VERSION=1.4.0 \
    LIBPNG_VERSION=1.6.43 \
    LIBLQR_VERSION=0.4.2 \
    IMAGEMAGICK_VERSION=7.1.1-35 \
    SRC=/usr/local

ARG LIBPNG_SHA256SUM="e804e465d4b109b5ad285a8fb71f0dd3f74f0068f91ce3cdfde618180c174925 libpng-${LIBPNG_VERSION}.tar.gz"
ARG LIBWEBP_SHA256SUM="61f873ec69e3be1b99535634340d5bde750b2e4447caa1db9f61be3fd49ab1e5 libwebp-${WEBP_VERSION}.tar.gz"


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
    libssl-dev \
    yasm \
    zlib1g-dev \
    libglib2.0-dev \
    nvidia-opencl-dev \
    libltdl-dev \
    libturbojpeg0-dev" && \
    apt-get -yqq update && \
    apt-get -yqq install --no-install-recommends ${buildDeps}

## build deps

## openjpeg https://github.com/uclouvain/openjpeg
RUN \
    DIR=/tmp/openjpeg && \
    mkdir -p ${DIR} && \
    cd ${DIR} && \
    git clone https://github.com/uclouvain/openjpeg.git ${DIR} -b v${OPENJPEG_VERSION} --depth 1 && \
    cmake -DBUILD_THIRDPARTY:BOOL=ON -DCMAKE_INSTALL_PREFIX="${PREFIX}" . && \
    make && \
    make install && \
    rm -rf ${DIR}

## libpng https://www.libpng.org/pub/png/libpng.html
RUN \
    DIR=/tmp/png && \
    mkdir -p ${DIR} && \
    cd ${DIR} && \
    curl -sLO https://download.sourceforge.net/libpng/libpng-${LIBPNG_VERSION}.tar.gz && \
    echo ${LIBPNG_SHA256SUM} | sha256sum --check && \
    tar -zx --strip-components=1 -f libpng-${LIBPNG_VERSION}.tar.gz && \
    ./configure --prefix="${PREFIX}" && \
    make check && \
    make install && \
    rm -rf ${DIR}

## Additional IM deps. TODO: compile libjpeg-turbo as well
## libwebp https://developers.google.com/speed/webp/
RUN \
    DIR=/tmp/webp && \
    mkdir -p ${DIR} && \
    cd ${DIR} && \
    curl -sLO https://storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-${WEBP_VERSION}.tar.gz && \
    echo ${LIBWEBP_SHA256SUM} | sha256sum --check && \
    tar -zx --strip-components=1 -f libwebp-${WEBP_VERSION}.tar.gz && \
    ./configure --prefix="${PREFIX}" --enable-shared && \
    make && \
    make install && \
    rm -rf ${DIR} \

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
ENV MAGICK_OCL_DEVICE=true
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
    --enable-opencl=yes \
    --disable-docs \
    --enable-hdri=no && \
    make && \
    make install

## Cleanup
RUN \
    ldd ${PREFIX}/bin/magick | cut -d ' ' -f 3 | xargs -i cp {} /usr/local/lib/ && \
    cp ${PREFIX}/bin/* /usr/local/bin/ && \
    cp -r ${PREFIX}/share/ImageMagick* /usr/local/share/ && \
    cp -r ${PREFIX}/include/ImageMagick* ${PREFIX}/include/lqr* ${PREFIX}/include/webp /usr/local/include && \
    mkdir -p /usr/local/lib/pkgconfig && \
    for pc in ${PREFIX}/lib/pkgconfig/ImageMagick*.pc ${PREFIX}/lib/pkgconfig/Magick*.pc ${PREFIX}/lib/pkgconfig/lqr*.pc ${PREFIX}/lib/pkgconfig/libwebp*.pc; do \
    sed "s:${PREFIX}:/usr/local:g" <"$pc" >/usr/local/lib/pkgconfig/"${pc##*/}"; \
    done

FROM base AS release
ENV LD_LIBRARY_PATH=/usr/local/lib:/usr/local/lib64
ENV MAGICK_OCL_DEVICE=true

COPY --from=build /usr/local /usr/local/

ENTRYPOINT [ "bash" ]