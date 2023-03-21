FROM zencash/gosu-base:1.16

MAINTAINER cronic@horizen.io

SHELL ["/bin/bash", "-c"]

ARG version=3.3.1-bitcore

ARG release=v${version}

ARG package=zen-${version}-legacy-cpu-amd64.deb

ENV TAG=${release}

COPY ./entrypoint.sh ./ca/* /root/

RUN set -eEuo pipefail \
    && touch /LEGACY \
    && apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends install apt-utils \
    && DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends dist-upgrade \
    && DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends install ca-certificates curl wget libgomp1 dnsutils aria2 iproute2 ipv6calc gnupg2 dirmngr \
    && cd /root && sha256sum -c /root/checksums.sha256 \
    && mv /root/*.crt /usr/local/share/ca-certificates/ \
    && update-ca-certificates \
    && curl -Lo /root/${package} "https://github.com/HorizenOfficial/zen/releases/download/${release}/${package}" \
    && curl -Lo /root/${package}.asc "https://github.com/HorizenOfficial/zen/releases/download/${release}/${package}.asc" \
    && export GNUPGHOME="$(mktemp -d)" \
    && ( gpg2 --batch --keyserver hkps://keys.openpgp.org --recv-keys 219F55740BBF7A1CE368BA45FB7053CE4991B669 || \
         gpg2 --batch --keyserver hkp://keyserver.ubuntu.com --recv-keys 219F55740BBF7A1CE368BA45FB7053CE4991B669 ) \
    && gpg2 --batch --verify /root/${package}.asc /root/${package} \
    && ( gpgconf --kill dirmngr || true ) \
    && ( gpgconf --kill gpg-agent || true ) \
    && rm -r "$GNUPGHOME" \
    && dpkg -i /root/${package} \
    && rm /root/{${package}*,*.sha256} \
    && mv /root/entrypoint.sh /usr/local/bin/ \
    && chmod +x /usr/local/bin/entrypoint.sh \
    && apt-get -y clean \
    && apt-get -y autoclean \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*.deb

# Default P2P communication port, can be changed via PORT env var, OPTS env var
# (e.g. docker run -e PORT=9876 or docker run -e OPTS="-port=9876") or via a "port=9876" line in zen.conf.
EXPOSE 9033

# Default RPC communication port, can be changed via RPC_PORT env var, OPTS env var
# (e.g. docker run -e RPC_PORT=8765 or docker run -e OPTS="-rpcport=8765") or via a "rpcport=8765" line in zen.conf.
# This port should never be mapped to the outside world via the "docker run -p/-P" switch.
EXPOSE 8231

# Data volumes, if you prefer mounting host directories use "-v /path/to/datadir:/mnt/zen",
# "-v /path/to/params:/mnt/zcash-params" command line options. Host directory ownership will be changed to the
# same UID/GID as provided by the "-e LOCAL_USER_ID=" and "-e LOCAL_GRP_ID=" env vars or 9001:9001 if not provided.
VOLUME ["/mnt/zen", "/mnt/zcash-params"]

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

CMD ["zend"]
