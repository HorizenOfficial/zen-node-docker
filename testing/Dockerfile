FROM zencash/gosu-base:1.12

MAINTAINER cronic@zensystem.io

ARG package=zen-2.1.0-beta4-amd64.deb

COPY $package $package.asc /root/

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends install apt-utils \
    && DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends dist-upgrade \
    && DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends install ca-certificates curl wget libgomp1 dnsutils aria2 iproute2 ipv6calc \
    && curl -Lo /usr/local/share/ca-certificates/lets-encrypt-x3-cross-signed.crt https://letsencrypt.org/certs/lets-encrypt-x3-cross-signed.pem.txt \
    && echo "e446c5e9dbef9d09ac9f7027c034602492437a05ff6c40011d7235fca639c79a  /usr/local/share/ca-certificates/lets-encrypt-x3-cross-signed.crt" | sha256sum -c - \
    && update-ca-certificates \
    && export GNUPGHOME="$(mktemp -d)" \
    && gpg --batch --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 4991B669 || \
    gpg --batch --keyserver hkp://ipv4.pool.sks-keyservers.net --recv-keys 4991B669 || \
    gpg --batch --keyserver hkp://pgp.mit.edu:80 --recv-keys 4991B669 \
    && gpg --batch --verify /root/$package.asc /root/$package \
    && rm -r "$GNUPGHOME" \
    && dpkg -i /root/$package \
    && rm /root/$package* \
    && apt-get -y clean \
    && apt-get -y autoclean \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*.deb

# Default testnet P2P communication port, can be changed via PORT env var, OPTS env var
# (e.g. docker run -e PORT=9876 or docker run -e OPTS="-port=9876") or via a "port=9876" line in zen.conf.
EXPOSE 19033

# Default testnet RPC communication port, can be changed via RPC_PORT env var, OPTS env var
# (e.g. docker run -e RPC_PORT=8765 or docker run -e OPTS="-rpcport=8765") or via a "rpcport=8765" line in zen.conf.
# This port should never be mapped to the outside world via the "docker run -p/-P" switch.
EXPOSE 18231

# Data volumes, if you prefer mounting host directories use "-v /path/to/datadir:/mnt/zen",
# "-v /path/to/params:/mnt/zcash-params" command line options. Host directory ownership will be changed to the
# same UID/GID as provided by the "-e LOCAL_USER_ID=" and "-e LOCAL_GRP_ID=" env vars or 9001:9001 if not provided.
VOLUME ["/mnt/zen", "/mnt/zcash-params"]

COPY entrypoint.sh /usr/local/bin/entrypoint.sh

RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

CMD ["zend"]
