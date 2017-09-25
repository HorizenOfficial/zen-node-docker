FROM zencash/gosu-base:1.10

MAINTAINER cronicc@protonmail.com

ENV release=v2.0.10 package=zen-2.0.10-amd64.deb

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends install apt-utils \
    && DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends install ca-certificates curl wget libgomp1 \
    && curl -Lo /root/$package "https://github.com/ZencashOfficial/zen/releases/download/$release/$package" \
    && curl -Lo /root/$package.asc "https://github.com/ZencashOfficial/zen/releases/download/$release/$package.asc" \
    && export GNUPGHOME="$(mktemp -d)" \
    && gpg --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 4991B669 \
    && gpg --batch --verify /root/$package.asc /root/$package \
    && rm -r "$GNUPGHOME" \
#    && cd /root && sha256sum -c /root/$package.sha256 | grep -q OK \
    && dpkg -i /root/$package \
    && rm /root/$package* \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Default p2p communication port, can be changed via $OPTS (e.g. docker run -e OPTS="-port=9876")
# or via a "port=9876" line in zen.conf.
EXPOSE 9033

# Default rpc communication port, can be changed via $OPTS (e.g. docker run -e OPTS="-rpcport=8765")
# or via a "rpcport=8765" line in zen.conf. This port should never be mapped to the outside world
# via the "docker run -p/-P" command.
EXPOSE 8231

# Data volumes, if you prefer mounting a host directory use "-v /path:/mnt/zen" command line
# option (folder ownership will be changed to the same UID/GID as provided by the docker run command)
VOLUME ["/mnt/zen", "/mnt/zcash-params"]

COPY entrypoint.sh /usr/local/bin/entrypoint.sh

RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

CMD ["zend"]
