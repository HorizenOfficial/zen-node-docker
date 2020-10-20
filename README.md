![latest release v2.0.22](https://img.shields.io/badge/latest%20release-v2.0.22-brightgreen.svg) ![latest bitcore release v2.0.22-bitcore](https://img.shields.io/badge/latest%20bitcore%20release-v2.0.22--bitcore-brightgreen.svg) ![Docker Automated build](https://img.shields.io/docker/automated/zencash/zen-node.svg) ![Docker Build Status](https://img.shields.io/docker/build/zencash/zen-node.svg) ![Docker Stars](https://img.shields.io/docker/stars/zencash/zen-node.svg) ![Docker Pulls](https://img.shields.io/docker/pulls/zencash/zen-node.svg)

## Docker image for the Horizen Blockchain Daemon - zend

#### Available tags

* `latest` built from [master:/latest/Dockerfile](https://github.com/HorizenOfficial/zen-node-docker/blob/master/latest/Dockerfile)
* `bitcore` for block explorers built from [master:/bitcore/Dockerfile](https://github.com/HorizenOfficial/zen-node-docker/blob/master/bitcore/Dockerfile)
* `dev` zend pre-release/development versions built from [master:/testing/Dockerfile](https://github.com/HorizenOfficial/zen-node-docker/blob/master/testing/Dockerfile)
* `bitcore-dev` zend bitcore pre-release/development versions built from [master:/bitcore-testing/Dockerfile](https://github.com/HorizenOfficial/zen-node-docker/blob/master/bitcore-testing/Dockerfile)

Release tags:
* `v2.0.22` tagged releases in format `vX.Y.Z(-$build)` built from [$TAG:/latest/Dockerfile](https://github.com/HorizenOfficial/zen-node-docker/blob/v2.0.22/latest/Dockerfile)
* `v2.0.22-bitcore` tagged bitcore releases for block explorers in format `vX.Y.Z(-$build)-bitcore` built from [$TAG:/bitcore/Dockerfile](https://github.com/HorizenOfficial/zen-node-docker/blob/v2.0.22-bitcore/bitcore/Dockerfile)
* `v2.1.0-beta1` pre-release/development releases in format `vX.Y.Z-(alphaX|betaX|rcX)` built from [$TAG:/testing/Dockerfile](https://github.com/HorizenOfficial/zen-node-docker/blob/v2.1.0-beta1/testing/Dockerfile)
* `v2.0.16-rc1-bitcore` bitcore pre-release/development releases in format `vX.Y.Z-(alphaX|betaX|rcX)-bitcore` built from [$TAG:/bitcore-testing/Dockerfile](https://github.com/HorizenOfficial/zen-node-docker/blob/v2.0.16-rc1-bitcore/bitcore-testing/Dockerfile)

#### Usage examples
To run, execute `docker run --name zen-node zencash/zen-node`, this will create a minimal zen.conf file in the named volume `/mnt/zen` which is used as zend's data directory and downloads the ZCash trusted setup to the named volume `/mnt/zcash-params`. Once the trusted setup is downloaded and verified zend will start syncing with the blockchain.

To execute `zen-cli` commands inside of a running container, use `docker exec -it zen-node gosu user zen-cli $command`, to see available cli commands run `docker exec -it zen-node gosu user zen-cli help`.

To gain a shell inside of the container, run `docker exec -it zen-node gosu user bash`, after that `zen-cli` can be executed as if running natively.

To use data/params directories stored on the host instead of docker volumes, mount them into the docker container at `/mnt/zen` and `/mnt/zcash-params` and set `LOCAL_USER_ID` and `LOCAL_GRP_ID` environment variables, e.g. `docker run --name zen-node -e LOCAL_USER_ID=$(id -u) -e LOCAL_GRP_ID=$(id -g) -v "$HOME/.zen:/mnt/zen" -v "$HOME/.zcash-params:/mnt/zcash-params zencash/zen-node`.

To configure zend for use with block explorers, run `docker run --name zen-node -e OPTS="-txindex=1 -addressindex=1 -timestampindex=1 -spentindex=1 -zmqpubrawtx=tcp://*:28332 -zmqpubhashblock=tcp://*:28332" zencash/zen-node:bitcore`, but be aware of [zmq.md#security-warning](https://github.com/HorizenOfficial/zen/blob/master/doc/zmq.md#security-warning) when exposing the zmq port.

To make zend's P2P port reachable from the outside, run `docker run --name zen-node -p 9033:9033 zencash/zen-node` or to specify a custom port `docker run --name zen-node -p 9876:9876 -e PORT=9876 zencash/zen-node`.

**Note: never expose the RPC port (default 8231) to the internet! By default the RPC interface is not restricted by origin IP, this will change in a future release, see [Configuration options](https://github.com/HorizenOfficial/zen-node-docker#configuration-options) `RPC_ALLOWIP_PRESET` for more.**

For advanced usage, see [Configuration options](https://github.com/HorizenOfficial/zen-node-docker#configuration-options).
#### Samples

Systemd unit file and docker compose file samples are available [here](https://github.com/HorizenOfficial/zen-node-docker/tree/master/samples).
#### Configuration options

To configure the most commonly used zend options, the following environment variables can be used:

* `OPTS` define any command line options to run zend with, e.g. `-e OPTS="-txindex=1 -debug=1"` Available switches can be displayed with: `docker run --rm -e OPTS="-help" zencash/zen-node`
* `LOCAL_USER_ID` and `LOCAL_GRP_ID` change ownership of folders mounted into the container at `/mnt/zen` and `/mnt/zcash-params` to `LOCAL_USER_ID:LOCAL_GRP_ID`, if not provided `9001:9001` will be used. With this, host directories can be mounted into the container with the right ownership, zend runs with the same UID:GID inside of the container as specified with `LOCAL_USER_ID` and `LOCAL_GRP_ID`. Example: `docker run --rm -e LOCAL_USER_ID=$(id -u) -e LOCAL_GRP_ID=$(id -g) -v "$HOME/.zen:/mnt/zen" -v "$HOME/.zcash-params:/mnt/zcash-params zencash/zen-node`
* `PORT` to set the P2P port, e.g. `-e PORT=9033`
* `RPC_USER` to set the RPC username, e.g. `-e RPC_USER=zenuser`
* `RPC_PASSWORD` to set the RPC password, e.g. `-e RPC_PASSWORD=secret`
* `RPC_PORT` to set the RPC port, e.g. `-e RPC_PORT=8231`
* `RPC_ALLOWIP_PRESET` one of `ANY|SUBNET|LOCALHOST`, default `ANY`. `LOCALHOST` uses zend's default setting of only allowing localhost access. `SUBNET` tries to detect all local subnets/docker networks, disallowing any public networks. `ANY` allows IPv4 and IPv6 connections from anywhere by setting `rpcallowip=0.0.0.0/0` and `rpcallowip=::/0` in zen.conf, to keep backwards compatibility this is the current default. Example: `-e RPC_ALLOWIP_PRESET=SUBNET`
**NOTE: the default will change to `LOCALHOST` in a future release, as allowing `ANY` is a potential security risk if the RPC port is exposed to the internet.**
* `RPC_ALLOWIP` comma separated string of one or more IPs/subnets, no spaces. Valid are a single IP (e.g. 1.2.3.4), a network/netmask (e.g. 1.2.3.4/255.255.255.0) or a network/CIDR (e.g. 1.2.3.4/24). Allows RPC access from the provided IPs or networks by setting `rpcallowip=` for each value in zen.conf. Works in combination with `RPC_ALLOWIP_PRESET`. Example: `-e RPC_ALLOWIP="10.10.10.1,192.168.0.1/24,fe01:a1f:ea75:ca75::/128"`
* `EXTERNAL_IP` comma separated string of one or more of IPv4, IPv6 or the string "DETECT", no spaces. Adds `externalip=` for each provided IP Address to zen.conf. "DETECT" tries to determine the outgoing IPv4 and IPv6 address using DNS queries to resolver.opendns.org. Example: `-e EXTERNAL_IP="DETECT,1.1.1.1,2606:4700:4700::1111"`
* `ADDNODE` comma separated string of one or more nodes to try to connect to, in format IPv4:PORT, [IPv6]:PORT or FQDN:PORT, no spaces. Example: `-e ADDNODE="37.120.176.224:9033,[2a03:4000:6:8315::1]:9033,mainnet.horizen.global:9033"`
* `LOG=STDOUT` sets `-printtoconsole`, logging to docker logs instead of debug.log.
* `TLS_KEY_PATH` to set the SSL private key path, e.g. `-e TLS_KEY_PATH=/home/user/.zen/ssl.key`
* `TLS_CERT_PATH` to set the SSL certificate path, e.g. `-e TLS_CERT_PATH=/home/user/.zen/ssl.crt`
* `CUSTOM_SCRIPT` to run a user defined bash script before launching zend. This is useful to e.g. make backups of wallet.dat each time the container starts. Example: `-e CUSTOM_SCRIPT=/home/user/.zen/backup_wallet.sh`
