#!/bin/bash
set -e

# Add local user
# Either use the LOCAL_USER_ID if passed in at runtime or
# fallback

USER_ID=${LOCAL_USER_ID:-9001}
GRP_ID=${LOCAL_GRP_ID:-9001}

getent group user > /dev/null 2>&1 || groupadd -g $GRP_ID user
id -u user > /dev/null 2>&1 || useradd --shell /bin/bash -u $USER_ID -g $GRP_ID -o -c "" -m user

LOCAL_UID=$(id -u user)
LOCAL_GID=$(getent group user | cut -d ":" -f 3)

if [ ! "$USER_ID" == "$LOCAL_UID" ] || [ ! "$GRP_ID" == "$LOCAL_GID" ]; then
    echo "Warning: User with differing UID "$LOCAL_UID"/GID "$LOCAL_GID" already exists, most likely this container was started before with a different UID/GID. Re-create it to change UID/GID."
fi

echo "Starting with UID/GID : "$(id -u user)"/"$(getent group user | cut -d ":" -f 3)

export HOME=/home/user

# If volumes for zen or zcash-params are present, symlink them to user's home, if not create folders.
if [ -d "/mnt/zen" ]; then
    if [ ! -L /home/user/.zen ]; then
        ln -s /mnt/zen /home/user/.zen > /dev/null 2>&1 || true
    fi
else
    mkdir -p /home/user/.zen
fi
if [ -d "/mnt/zcash-params" ]; then
    if [ ! -L /home/user/.zcash-params ]; then
        ln -s /mnt/zcash-params /home/user/.zcash-params > /dev/null 2>&1 || true
    fi
else
    mkdir -p /home/user/.zcash-params
fi

# Check if we have minimal mainnet and testnet zen.conf files, if not create them.
if [ ! -e "/home/user/.zen/zen.conf" ]; then
    touch /home/user/.zen/zen.conf
fi
if ! grep -q 'rpcuser' /home/user/.zen/zen.conf ; then
    echo 'rpcuser=user' >> /home/user/.zen/zen.conf
fi
if ! grep -q 'rpcpassword' /home/user/.zen/zen.conf ; then
    echo "rpcpassword=`head -c 32 /dev/urandom | base64`" >> /home/user/.zen/zen.conf
fi
if [ ! -d "/home/user/.zen/testnet3" ]; then
    mkdir -p /home/user/.zen/testnet3
fi
if [ ! -e "/home/user/.zen/testnet3/zen.conf" ]; then
    touch /home/user/.zen/testnet3/zen.conf
fi
if ! grep -q 'rpcuser' /home/user/.zen/testnet3/zen.conf ; then
    echo 'rpcuser=user' >> /home/user/.zen/testnet3/zen.conf
fi
if ! grep -q 'rpcpassword' /home/user/.zen/testnet3/zen.conf ; then
    echo "rpcpassword=`head -c 32 /dev/urandom | base64`" >> /home/user/.zen/testnet3/zen.conf
fi

# Prepend some default command line options to OPTS, user provided values will be appended and take precedence.
OPTS="-listenonion=0 -rpcallowip=0.0.0.0/0 $OPTS"

# If a RPC username/password were provided, update zen.conf files with them.
if [[ -v RPC_USER ]]; then
    sed -i '/^rpcuser/d' /home/user/.zen/zen.conf
    sed -i '/^rpcuser/d' /home/user/.zen/testnet3/zen.conf
    echo "rpcuser="$RPC_USER | tee -a /home/user/.zen/zen.conf >> /home/user/.zen/testnet3/zen.conf
fi
if [[ -v RPC_PASSWORD ]]; then
    sed -i '/^rpcpassword/d' /home/user/.zen/zen.conf
    sed -i '/^rpcpassword/d' /home/user/.zen/testnet3/zen.conf
    echo "rpcpassword="$RPC_PASSWORD | tee -a /home/user/.zen/zen.conf >> /home/user/.zen/testnet3/zen.conf
fi

# If an external IP was provided, update zen.conf files with it
if [[ -v EXTERNAL_IP ]]; then
    sed -i '/^externalip/d' /home/user/.zen/zen.conf
    sed -i '/^externalip/d' /home/user/.zen/testnet3/zen.conf
    echo "externalip="$EXTERNAL_IP | tee -a /home/user/.zen/zen.conf >> /home/user/.zen/testnet3/zen.conf
fi

# Fix ownership of the created files/folders
chown -R user:user /home/user /mnt/zen /mnt/zcash-params

/usr/local/bin/gosu user zen-fetch-params

if [[ "$1" == zend ]]; then
    exec /usr/local/bin/gosu user /bin/bash -c "$@ $OPTS"
fi

exec /usr/local/bin/gosu user "$@"
