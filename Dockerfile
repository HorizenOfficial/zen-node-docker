FROM zencash/gosu-base:1.10

MAINTAINER cronicc@protonmail.com

ENV release=v.2.0.9-2-b4315d9 package=zen-2.0.9-2-b4315d9-amd64.deb checksum=f009270e9f18062724ca925d57ccc571e854acfc01856eb3ba6148b28862c9d9

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends install apt-utils \
    && DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends install ca-certificates curl wget libgomp1 \
    && curl -Lo /root/$package "https://github.com/ZencashOfficial/zen/releases/download/$release/$package" \
# move to gpg verification once CI release process is set up
#    && curl signature.asc \
#    && export GNUPGHOME="$(mktemp -d)" \
#    && gpg --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys \
#    && gpg --batch --verify /root/$package signature.asc \
#    && rm -r "$GNUPGHOME" \
    && sha256sum /root/$package | grep -q $checksum \
    && dpkg -i /root/$package \
    && rm /root/$package \
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
