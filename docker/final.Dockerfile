ARG GO_VERSION

FROM golang:${GO_VERSION}-bullseye AS base

ARG DEBIAN_FRONTEND=noninteractive
ARG GORELEASER_VERSION
ARG APT_MIRROR
ARG TINI_VERSION
ARG GORELEASER_DOWNLOAD_URL=https://github.com/goreleaser/goreleaser/releases/download/v${GORELEASER_VERSION}
ARG TARGETARCH

COPY entrypoint.sh /

# Install deps
RUN \
    set -x \
 && echo "Starting image build for Debian" \
 && sed -ri "s/(httpredir|deb).debian.org/${APT_MIRROR:-deb.debian.org}/g" /etc/apt/sources.list \
 && sed -ri "s/(security).debian.org/${APT_MIRROR:-security.debian.org}/g" /etc/apt/sources.list \
 && apt-get update \
 && apt-get install --no-install-recommends -y -q \
    software-properties-common \
 && curl -fsSL https://download.docker.com/linux/ubuntu/gpg | APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=1 apt-key add - \
 && echo "deb [arch=$TARGETARCH] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list \
 && apt-get update \
 && apt-get install --no-install-recommends -y -q \
        tini \
        docker-ce \
        docker-ce-cli \
        make \
        git-core \
        wget \
        xz-utils \
        cmake \
        openssl \
 && apt -y autoremove \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

 RUN \
    GORELEASER_DOWNLOAD_FILE=goreleaser_${GORELEASER_VERSION}_${TARGETARCH}.deb \
 && GORELEASER_DOWNLOAD_DEB="${GORELEASER_DOWNLOAD_URL}/${GORELEASER_DOWNLOAD_FILE}" \
 && wget ${GORELEASER_DOWNLOAD_DEB} \
 && dpkg -i ${GORELEASER_DOWNLOAD_FILE} \
 && rm ${GORELEASER_DOWNLOAD_FILE} \
 && chmod +x /entrypoint.sh

ENTRYPOINT ["/usr/bin/tini", "--", "/entrypoint.sh"]

FROM base AS osx-cross-base
ENV OSX_CROSS_PATH=/osxcross
ARG DEBIAN_FRONTEND=noninteractive

SHELL ["/bin/bash", "-c"]
RUN \
    set -x; \
    echo "Starting image build for Debian" \
 && dpkg --add-architecture amd64 \
 && dpkg --add-architecture arm64 \
 && dpkg --add-architecture armel \
 && dpkg --add-architecture armhf \
 && dpkg --add-architecture i386 \
 && dpkg --add-architecture mips \
 && dpkg --add-architecture mipsel \
 && dpkg --add-architecture powerpc \
 && dpkg --add-architecture ppc64el \
 && dpkg --add-architecture s390x \
 && apt-get update \
 && apt-get install --no-install-recommends -y -q \
        autoconf \
        automake \
        bc \
        python \
        jq \
        binfmt-support \
        binutils-multiarch \
        build-essential \
        clang \
        gcc \
        g++ \
        libarchive-tools \
        gdb \
        mingw-w64 \
        crossbuild-essential-amd64 \
        crossbuild-essential-arm64 \
        crossbuild-essential-armel \
        crossbuild-essential-armhf \
        crossbuild-essential-mipsel \
        crossbuild-essential-ppc64el \
        crossbuild-essential-s390x \
        devscripts \
        libtool \
        llvm \
        multistrap \
        patch \
        mercurial \
        musl-tools \
 && apt -y autoremove \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/* \
    /tmp/* \
    /var/tmp/* \
    rm -rf /usr/share/man/* \
    /usr/share/doc

# install a copy of mingw with aarch64 support to enable windows on arm64
ARG TARGETARCH
ARG MINGW_VERSION=20220906

RUN \
    if [ ${TARGETARCH} = "arm64" ]; then MINGW_ARCH=aarch64; elif [ ${TARGETARCH} = "amd64" ]; then MINGW_ARCH=x86_64; else echo "unsupported TARGETARCH=${TARGETARCH}"; exit 1; fi \
 && wget -qO - "https://github.com/mstorsjo/llvm-mingw/releases/download/${MINGW_VERSION}/llvm-mingw-${MINGW_VERSION}-ucrt-ubuntu-18.04-${MINGW_ARCH}.tar.xz" | bsdtar -xf - \
 && ln -s llvm-mingw-20220906-ucrt-ubuntu-18.04-${MINGW_ARCH} llvm-mingw

FROM osx-cross-base AS osx-cross
ARG OSX_CROSS_COMMIT
ARG OSX_SDK
ARG OSX_SDK_SUM
ARG OSX_VERSION_MIN

WORKDIR "${OSX_CROSS_PATH}"

COPY patches /patches

RUN \
    git clone https://github.com/tpoechtrager/osxcross.git . \
 && git config user.name "Jayden Lee" \
 && git config user.email jaeseung-lee@linecorp.com \
 && git checkout -q "${OSX_CROSS_COMMIT}" \
 && git am < /patches/libcxx.patch \
 && rm -rf ./.git

# install osxcross:
COPY tars/${OSX_SDK}.tar.xz "${OSX_CROSS_PATH}/tarballs/${OSX_SDK}.tar.xz"

RUN \
    echo "${OSX_SDK_SUM}" "${OSX_CROSS_PATH}/tarballs/${OSX_SDK}.tar.xz" | sha256sum -c - \
 && apt-get update \
 && apt-get install --no-install-recommends -y -q \
        autotools-dev \
        libxml2-dev \
        lzma-dev \
        libssl-dev \
        zlib1g-dev \
        libmpc-dev \
        libmpfr-dev \
        libgmp-dev \
        llvm-dev \
        uuid-dev \
        binutils-multiarch-dev \
 && apt -y autoremove \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
 && UNATTENDED=1 OSX_VERSION_MIN=${OSX_VERSION_MIN} ./build.sh

FROM osx-cross-base AS final

ARG DEBIAN_FRONTEND=noninteractive

COPY --from=osx-cross "${OSX_CROSS_PATH}/target" "${OSX_CROSS_PATH}/target"
ENV PATH=${OSX_CROSS_PATH}/target/bin:$PATH