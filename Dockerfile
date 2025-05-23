ARG SOLANUM_UID=10000

FROM alpine:latest AS builder

RUN set -xe; \
	ARCH=$(apk --print-arch) && \
    BUILD_FLAG=$(case "$ARCH" in \
        aarch64) echo "--build=aarch64-unknown-linux-gnu" ;; \
        x86_64) echo "--build=x86_64-unknown-linux-gnu" ;; \
        *) echo "--build=$ARCH-unknown-linux-gnu" ;; \
    esac) && \
	apk add --no-cache --virtual .build-deps \
		git \
		alpine-sdk \
		flex \
		bison \
		sqlite-dev \
		gnutls-dev \
		zlib-dev \
		automake \
		autoconf \
		libtool \
		openssl \
		openssl-dev \
	\
	&& git clone https://github.com/solanum-ircd/solanum.git \
	&& cd /solanum \
        && ./autogen.sh \
	&& ./configure --prefix=/usr/local/ --sysconfdir=/ircd/etc --enable-openssl $BUILD_FLAG \
	&& make \
        && make install \
	&& mv /ircd/etc/ircd.conf.example /ircd/etc/ircd.conf \
	&& openssl dhparam -out /ircd/etc/dh.pem 2048 \
	&& apk del .build-deps \
	&& rm -rf /var/cache/apk/*

FROM alpine:latest
ARG SOLANUM_UID


RUN mkdir /ircd
RUN adduser -D -h /ircd -u $SOLANUM_UID ircd
RUN chown -R ircd /ircd

RUN apk add --no-cache sqlite-dev openssl libtool
COPY --from=builder --chown=ircd /usr/local /usr/local
COPY --from=builder --chown=ircd /ircd /ircd

USER ircd

EXPOSE 5000
EXPOSE 6665-6669
EXPOSE 6697
EXPOSE 9999

CMD ["/usr/local/bin/solanum", "-foreground"]