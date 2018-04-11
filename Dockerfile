FROM zencash/gosu-base:1.10

MAINTAINER cronicc@protonmail.com

ARG package=zen-2.0.11-0704488-amd64.deb
COPY $package $package.asc /root/

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends install apt-utils \
    && DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends install ca-certificates curl wget libgomp1 \
    && curl -Lo /usr/local/share/ca-certificates/lets-encrypt-x3-cross-signed.crt https://letsencrypt.org/certs/lets-encrypt-x3-cross-signed.pem.txt \
    && echo "e446c5e9dbef9d09ac9f7027c034602492437a05ff6c40011d7235fca639c79a  /usr/local/share/ca-certificates/lets-encrypt-x3-cross-signed.crt" | sha256sum -c - \
    && update-ca-certificates \
    && curl -Lo /root/$package "https://github.com/ZencashOfficial/zen/releases/download/$release/$package" \
    && curl -Lo /root/$package.asc "https://github.com/ZencashOfficial/zen/releases/download/$release/$package.asc" \
    && export GNUPGHOME="$(mktemp -d)" \
    && gpg --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys C0FBE0B4 \
    && gpg --batch --verify /root/$package.asc /root/$package \
    && rm -r "$GNUPGHOME" \
    && dpkg -i /root/$package \
    && rm /root/$package* \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Default testnet p2p communication port, can be changed via $OPTS (e.g. docker run -e OPTS="-port=9876")
# or via a "port=9876" line in zen.conf.
EXPOSE 9033

# Default testnet rpc communication port, can be changed via $OPTS (e.g. docker run -e OPTS="-rpcport=8765")
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
