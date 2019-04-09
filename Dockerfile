FROM zencash/gosu-base:1.11

MAINTAINER cronic@zensystem.io

ARG release=v2.0.17

ARG package=zen-2.0.17-amd64.deb

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends install apt-utils \
    && DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends dist-upgrade \
    && DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends install ca-certificates curl wget libgomp1 dnsutils aria2 \
    && curl -Lo /usr/local/share/ca-certificates/lets-encrypt-x3-cross-signed.crt https://letsencrypt.org/certs/lets-encrypt-x3-cross-signed.pem.txt \
    && echo "e446c5e9dbef9d09ac9f7027c034602492437a05ff6c40011d7235fca639c79a  /usr/local/share/ca-certificates/lets-encrypt-x3-cross-signed.crt" | sha256sum -c - \
    && update-ca-certificates \
    && curl -Lo /root/$package "https://github.com/ZencashOfficial/zen/releases/download/$release/$package" \
    && curl -Lo /root/$package.asc "https://github.com/ZencashOfficial/zen/releases/download/$release/$package.asc" \
    && export GNUPGHOME="$(mktemp -d)" \
    && gpg --batch --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 219F55740BBF7A1CE368BA45FB7053CE4991B669 || \
    gpg --batch --keyserver hkp://ipv4.pool.sks-keyservers.net --recv-keys 219F55740BBF7A1CE368BA45FB7053CE4991B669 || \
    gpg --batch --keyserver hkp://pgp.mit.edu:80 --recv-keys 219F55740BBF7A1CE368BA45FB7053CE4991B669 \
    && gpg --batch --verify /root/$package.asc /root/$package \
    && rm -r "$GNUPGHOME" \
    && dpkg -i /root/$package \
    && rm /root/$package* \
    && apt-get -y clean \
    && apt-get -y autoclean \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*.deb

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
