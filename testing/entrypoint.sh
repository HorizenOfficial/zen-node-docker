#!/bin/bash
set -eo pipefail

# Add local user unless root
# Either use LOCAL_USER_ID/LOCAL_GRP_ID if present or fallback to 9001

USER_ID=${LOCAL_USER_ID:-9001}
GRP_ID=${LOCAL_GRP_ID:-9001}

if [ ! "$USER_ID" == "0"  ]; then
    getent group $GRP_ID > /dev/null 2>&1 || groupadd -g $GRP_ID user
    id -u user > /dev/null 2>&1 || useradd --shell /bin/bash -u $USER_ID -g $GRP_ID -o -c "" -m user
    LOCAL_UID=$(id -u user)
    LOCAL_GID=$(id -g user)
    if [ ! "$USER_ID" == "$LOCAL_UID" ] || [ ! "$GRP_ID" == "$LOCAL_GID" ]; then
        echo -e "WARNING: User with differing UID $LOCAL_UID/GID $LOCAL_GID already exists, most likely this container was started before with a different UID/GID. Re-create it to change UID/GID.\n"
    fi
else
    LOCAL_UID=$USER_ID
    LOCAL_GID=$GRP_ID
    echo -e "WARNING: Starting container processes as root. This has some security implications and goes against docker best practice.\n"
fi

echo -e "Starting with UID/GID : $LOCAL_UID/$LOCAL_GID\n"

# set $HOME
if [ ! "$USER_ID" == "0"  ]; then
    export USERNAME=user
    export HOME=/home/$USERNAME
else
    export USERNAME=root
    export HOME=/root
fi

# If volumes for zen or zcash-params are present, symlink them to user's home, if not create folders.
if [ -d "/mnt/zen" ]; then
    if [ ! -L $HOME/.zen ]; then
        ln -fs /mnt/zen $HOME/.zen > /dev/null 2>&1
    fi
else
    mkdir -p $HOME/.zen
fi
if [ -d "/mnt/zcash-params" ]; then
    if [ ! -L $HOME/.zcash-params ]; then
        ln -fs /mnt/zcash-params $HOME/.zcash-params > /dev/null 2>&1
    fi
else
    mkdir -p $HOME/.zcash-params
fi

# Check if we have minimal mainnet and testnet zen.conf files, if not create them.
if [ ! -e "$HOME/.zen/zen.conf" ]; then
    touch $HOME/.zen/zen.conf
fi
if [ ! -d "$HOME/.zen/testnet3" ]; then
    mkdir -p $HOME/.zen/testnet3
fi
if [ ! -e "$HOME/.zen/testnet3/zen.conf" ]; then
    touch $HOME/.zen/testnet3/zen.conf
fi
if ! grep -q 'rpcuser' $HOME/.zen/zen.conf ; then
    echo 'rpcuser=user' >> $HOME/.zen/zen.conf
fi
if ! grep -q 'rpcuser' $HOME/.zen/testnet3/zen.conf ; then
    echo 'rpcuser=user' >> $HOME/.zen/testnet3/zen.conf
fi
if ! grep -q 'rpcpassword' $HOME/.zen/zen.conf ; then
    echo "rpcpassword=`head -c 32 /dev/urandom | base64`" >> $HOME/.zen/zen.conf
fi
if ! grep -q 'rpcpassword' $HOME/.zen/testnet3/zen.conf ; then
    echo "rpcpassword=`head -c 32 /dev/urandom | base64`" >> $HOME/.zen/testnet3/zen.conf
fi

# Prepend some default command line options to OPTS, user provided values will be appended and take precedence.
export OPTS="-listenonion=0 $OPTS"

# Logging to stdout or debug.log
if [[ -v LOG ]] && [ "$LOG" == "STDOUT" ]; then
    export OPTS="-printtoconsole $OPTS"
fi

# If RPC settings were provided, update zen.conf files with them.
if [[ -v RPC_USER ]]; then
    sed -i '/^rpcuser/d' $HOME/.zen/zen.conf $HOME/.zen/testnet3/zen.conf
    echo "rpcuser="$RPC_USER | tee -a $HOME/.zen/zen.conf >> $HOME/.zen/testnet3/zen.conf
fi
if [[ -v RPC_PASSWORD ]]; then
    sed -i '/^rpcpassword/d' $HOME/.zen/zen.conf $HOME/.zen/testnet3/zen.conf
    echo "rpcpassword="$RPC_PASSWORD | tee -a $HOME/.zen/zen.conf >> $HOME/.zen/testnet3/zen.conf
fi
if [[ -v RPC_PORT ]]; then
    sed -i '/^rpcport/d' $HOME/.zen/zen.conf $HOME/.zen/testnet3/zen.conf
    echo "rpcport="$RPC_PORT | tee -a $HOME/.zen/zen.conf >> $HOME/.zen/testnet3/zen.conf
fi

# Allow changing of P2P port via "-e PORT="
if [[ -v PORT ]]; then
    sed -i '/^port/d' $HOME/.zen/zen.conf $HOME/.zen/testnet3/zen.conf
    echo "port="$PORT | tee -a $HOME/.zen/zen.conf >> $HOME/.zen/testnet3/zen.conf
fi

# RPC_ALLOWIP_PRESET one of ANY|SUBNET|LOCALHOST, default ANY, example: "-e RPC_ALLOWIP_PRESET=SUBNET"

# Default to ANY to keep existring behavior, NOTE default will change to LOCALHOST in a future release
if [[ ! -v RPC_ALLOWIP_PRESET ]]; then
    export RPC_ALLOWIP_PRESET=ANY
fi

TO_ALLOW=()

if [ "$RPC_ALLOWIP_PRESET" == "ANY" ]; then
    # Any v4 and v6
    TO_ALLOW+=("0.0.0.0/0")
    TO_ALLOW+=("::/0")
elif [ "$RPC_ALLOWIP_PRESET" == "SUBNET" ]; then
    IP4=( $(ip -o -f inet route show | awk '/scope link/ {print $1}' || true) )
    IP6=( $(ip -o -f inet6 route show | awk '/proto kernel/ {print $1}' | grep "/" || true) )
    if (( ${#IP4[@]} )); then
        for net in "${IP4[@]}"; do
            # only add local subnets
            if ipv6calc -qim "$net" | grep "IPV4_TYPE" | grep -q "local"; then
                TO_ALLOW+=( "$net" )
            fi
        done
    fi
    if (( ${#IP6[@]} )); then
        for net in "${IP6[@]}"; do
            # only add local subnets
            if ipv6calc -qim "$net" | grep "IPV6_TYPE" | grep -q "local"; then
                TO_ALLOW+=( "$net" )
            fi
        done
    fi
fi

# RPC_ALLOWIP, comma separated string of one or more IPs/subnets, no spaces, valid are a single IP (e.g. 1.2.3.4),
# a network/netmask (e.g. 1.2.3.4/255.255.255.0) or a network/CIDR (e.g. 1.2.3.4/24).
# Example: -e RPC_ALLOWIP="10.10.10.1,192.168.0.1/24,192.168.1.1/255.255.255.0"
if [[ -v RPC_ALLOWIP ]]; then
    for net in $(echo "$RPC_ALLOWIP" | tr "," " "); do
        TO_ALLOW+=( "$net" )
    done
fi

# Set rpcallowip= in zen.conf
if (( ${#TO_ALLOW[@]} )); then
    sed -i '/^rpcallowip/d' $HOME/.zen/zen.conf $HOME/.zen/testnet3/zen.conf
    echo -e "Allowing RPC access from: ${TO_ALLOW[@]}\n"
    for net in "${TO_ALLOW[@]}"; do
        echo "rpcallowip=$net" | tee -a $HOME/.zen/zen.conf >> $HOME/.zen/testnet3/zen.conf
    done
fi

# EXTERNAL_IP, comma separated string of one or more of IPv4, IPv6 or the string "DETECT", no spaces.
# Example: -e EXTERNAL_IP="DETECT,1.1.1.1,2606:4700:4700::1111"
EXTERNAL=()
if [[ -v EXTERNAL_IP ]]; then
    for entry in $(echo "$EXTERNAL_IP" | tr "," " "); do
        if [ "$entry" == "DETECT" ]; then
            EXTERNAL+=( $(dig -4 +short +time=2 @resolver1.opendns.com A myip.opendns.com | grep -v ";" || true) )
            EXTERNAL+=( $(dig -6 +short +time=2 @resolver1.opendns.com AAAA myip.opendns.com  | grep -v ";" || true) )
        else
            EXTERNAL+=( "$entry" )
        fi
    done
fi

# Set externalip= in zen.conf
if (( ${#EXTERNAL[@]} )); then
    sed -i '/^externalip/d' $HOME/.zen/zen.conf $HOME/.zen/testnet3/zen.conf
    echo -e "Setting externalip to: ${EXTERNAL[@]}\n"
    for ip in "${EXTERNAL[@]}"; do
        echo "externalip=$ip" | tee -a $HOME/.zen/zen.conf >> $HOME/.zen/testnet3/zen.conf
    done
fi

# ADDNODE comma separated string of one or more nodes to try to connect to in format IPv4:PORT, [IPv6]:PORT or FQDN:PORT, no spaces.
# Example: ADDNODE="1.1.1.1:9033,[2606:4700:4700::1111]:9033,mainnet.horizen.global:9033"

# Set addnode= in zen.conf
if [[ ! -z "$ADDNODE" ]]; then
    sed -i '/^addnode/d' $HOME/.zen/zen.conf $HOME/.zen/testnet3/zen.conf
    echo -e "Adding addnode= for: $(echo "$ADDNODE" | tr "," " " )\n"
    for node in $(echo "$ADDNODE" | tr "," " "); do
        echo "addnode=$node" | tee -a $HOME/.zen/zen.conf >> $HOME/.zen/testnet3/zen.conf
    done
fi

# TLS_KEY_PATH path to SSL private key inside of the container
# Example: TLS_KEY_PATH="/home/user/.zen/ssl.key"

# Set tlskeypath= in zen.conf
if [[ ! -z "$TLS_KEY_PATH" ]]; then
    sed -i '/^tlskeypath/d' $HOME/.zen/zen.conf $HOME/.zen/testnet3/zen.conf
    echo "tlskeypath=${TLS_KEY_PATH}" | tee -a $HOME/.zen/zen.conf >> $HOME/.zen/testnet3/zen.conf
fi

# TLS_CERT_PATH path to SSL certificate inside of the container
# Example: TLS_CERT_PATH="/home/user/.zen/ssl.crt"

# Set tlscertpath= in zen.conf
if [[ ! -z "$TLS_CERT_PATH" ]]; then
    sed -i '/^tlscertpath/d' $HOME/.zen/zen.conf $HOME/.zen/testnet3/zen.conf
    echo "tlscertpath=${TLS_CERT_PATH}" | tee -a $HOME/.zen/zen.conf >> $HOME/.zen/testnet3/zen.conf
fi

# Fix ownership of the created files/folders
chown -R $USERNAME:$USERNAME $HOME /mnt/zen /mnt/zcash-params

# CUSTOM_SCRIPT, execute user provided script before starting zend, e.g. to backup wallets
if [[ ! -z "$CUSTOM_SCRIPT" ]]; then
    chmod +x "${CUSTOM_SCRIPT}"
    echo "Running custom script: ${CUSTOM_SCRIPT}"
    bash -c "${CUSTOM_SCRIPT}"
fi

if [ ! "$USER_ID" == "0"  ]; then
    if [[ "$1" == zend ]]; then
        /usr/local/bin/gosu user zen-fetch-params
        exec /usr/local/bin/gosu user /bin/bash -c "$@ $OPTS"
    fi
    exec /usr/local/bin/gosu user "$@"
else
    if [[ "$1" == zend ]]; then
        zen-fetch-params
        exec /bin/bash -c "$@ $OPTS"
    fi
    exec "$@"
fi

