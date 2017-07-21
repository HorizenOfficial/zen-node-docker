FROM zencash/gosu-base:1.10

MAINTAINER cronicc@protonmail.com

COPY zen-2.0.9-4-246baa3-amd64.deb zen-2.0.9-4-246baa3-amd64.deb.sha256 /root/

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends install apt-utils \
    && DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends install ca-certificates curl wget libgomp1 \
# move to gpg verification once CI release process is set up
#    && curl signature.asc \
#    && export GNUPGHOME="$(mktemp -d)" \
#    && gpg --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys \
#    && gpg --batch --verify /root/$package signature.asc \
#    && rm -r "$GNUPGHOME" \
    && cd /root && sha256sum -c /root/zen-2.0.9-4-246baa3-amd64.deb.sha256 | grep -q OK \
    && dpkg -i /root/zen-2.0.9-4-246baa3-amd64.deb \
    && rm /root/zen-2.0.9-4-246baa3-amd64.deb* \
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
