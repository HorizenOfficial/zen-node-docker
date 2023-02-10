#!/bin/bash
set -eEuo pipefail

# check if this is an unsupported CPU, warn the user and bail
TAG="${TAG:-version_number}"
if ! [ -f "/LEGACY" ] && ! grep -iq adx /proc/cpuinfo && ! grep -iq bmi2 /proc/cpuinfo; then
  echo "Error: adx and bmi2 CPU flags are not supported on this host. Please use tags '${TAG}-legacy-cpu' for support of older CPUs."
  sleep 5
  exit 1
fi

# Add local user unless root
# Either use LOCAL_USER_ID/LOCAL_GRP_ID as provided by -e if present or fallback to 9001

USER_ID="${LOCAL_USER_ID:-9001}"
GRP_ID="${LOCAL_GRP_ID:-9001}"

if [ "${USER_ID}" -ne 0 ]; then
  getent group "${GRP_ID}" &> /dev/null || groupadd -g "${GRP_ID}" user
  id -u user &> /dev/null || useradd --shell /bin/bash -u "${USER_ID}" -g "${GRP_ID}" -o -c "" -m user
  CURRENT_UID="$(id -u user)"
  CURRENT_GID="$(id -g user)"
  if [ "${USER_ID}" != "${CURRENT_UID}" ] || [ "{$GRP_ID}" != "${CURRENT_GID}" ]; then
    echo -e "WARNING: User with differing UID ${USER_ID}/GID ${GRP_ID} already exists, most likely this container was started before with a different UID/GID. Re-create it to change UID/GID.\n"
  fi
else
  CURRENT_UID="${USER_ID}"
  CURRENT_GID="${GRP_ID}"
  echo -e "WARNING: Starting container processes as root. This has some security implications and goes against docker best practice.\n"
fi

echo -e "Starting with UID/GID : ${CURRENT_UID}/${CURRENT_GID}\n"

# set $HOME
if [ "${CURRENT_UID}" -ne 0 ]; then
  export USERNAME="user"
  export HOME="/home/${USERNAME}"
else
  export USERNAME="root"
  export HOME="/root"
fi

# check volume mounts are present, symlink to home dir
mountpoints=( "/mnt/zen" "/mnt/zcash-params" )
targets=( "${HOME}/.zen" "${HOME}/.zcash-params" )
for i in "${!mountpoints[@]}"; do
  while ! mountpoint "${mountpoints[i]}" &> /dev/null; do
    echo "Waiting for volume ${mountpoints[i]} to be mounted..."
    sleep 0.5
  done
  # ensure there isn't a directory present with the same name or symlink would be created inside of it
  if ! [ -L "${targets[i]}" ] && [ -d "${targets[i]}" ]; then
    rm -rf "${targets[i]}"
  fi
  ln -fsn "${mountpoints[i]}" "${targets[i]}"
done

# ensure we have minimal mainnet and testnet zen.conf files
mkdir -p "${HOME}/.zen/testnet3"
for file in "${HOME}/.zen/zen.conf" "${HOME}/.zen/testnet3/zen.conf"; do
  touch "${file}"
  grep -q 'rpcuser' "${file}" || echo 'rpcuser=user' >> "${file}"
  grep -q 'rpcpassword' "${file}" || echo "rpcpassword=$(head -c 32 /dev/urandom | base64)" >> "${file}"
done

# Prepend some default command line options to OPTS, user provided values will be appended and take precedence.
export OPTS="-listenonion=0 ${OPTS:-}"

# Logging to stdout or debug.log
if [ "${LOG:-}" = "STDOUT" ]; then
  export OPTS="-printtoconsole ${OPTS}"
fi

# If RPC settings were provided, update zen.conf files with them.
if [ -n "${RPC_USER:-}" ]; then
  sed -i '/^rpcuser/d' "${HOME}/.zen/zen.conf" "${HOME}/.zen/testnet3/zen.conf"
  echo "rpcuser=${RPC_USER}" | tee -a "${HOME}/.zen/zen.conf" >> "${HOME}/.zen/testnet3/zen.conf"
fi
if [ -n "${RPC_PASSWORD:-}" ]; then
  sed -i '/^rpcpassword/d' "${HOME}/.zen/zen.conf" "${HOME}/.zen/testnet3/zen.conf"
  echo "rpcpassword=${RPC_PASSWORD}" | tee -a "${HOME}/.zen/zen.conf" >> "${HOME}/.zen/testnet3/zen.conf"
fi
if [ -n "${RPC_PORT:-}" ]; then
  sed -i '/^rpcport/d' "${HOME}/.zen/zen.conf" "${HOME}/.zen/testnet3/zen.conf"
  echo "rpcport=${RPC_PORT}" | tee -a "${HOME}/.zen/zen.conf" >> "${HOME}/.zen/testnet3/zen.conf"
fi

# Allow changing of P2P port via "-e PORT="
if [ -n "${PORT:-}" ]; then
  sed -i '/^port/d' "${HOME}/.zen/zen.conf" "${HOME}/.zen/testnet3/zen.conf"
  echo "port=${PORT}" | tee -a "${HOME}/.zen/zen.conf" >> "${HOME}/.zen/testnet3/zen.conf"
fi

# RPC_ALLOWIP_PRESET one of ANY|SUBNET|LOCALHOST, default ANY, example: "-e RPC_ALLOWIP_PRESET=SUBNET"

# Default to ANY to keep existring behavior, NOTE default will change to LOCALHOST in a future release
if [ -z "${RPC_ALLOWIP_PRESET:-}" ]; then
    export RPC_ALLOWIP_PRESET="ANY"
fi

to_allow=()
ip4=()
ip6=()

if [ "${RPC_ALLOWIP_PRESET}" = "ANY" ]; then
  # Any v4 and v6
  to_allow+=("0.0.0.0/0")
  to_allow+=("::/0")
elif [ "${RPC_ALLOWIP_PRESET}" = "SUBNET" ]; then
  mapfile -t ip4 < <(ip -o -f inet route show | awk '/scope link/ {print $1}' || true)
  mapfile -t ip6 < <(ip -o -f inet6 route show | awk '/proto kernel/ {print $1}' | grep "/" || true)
  if (( ${#ip4[@]} )); then
    for net in "${ip4[@]}"; do
      # only add local subnets
      if ipv6calc -qim "${net}" | grep "IPV4_TYPE" | grep -q "local"; then
        to_allow+=( "${net}" )
      fi
    done
  fi
  if (( ${#ip6[@]} )); then
    for net in "${ip6[@]}"; do
      # only add local subnets
      if ipv6calc -qim "${net}" | grep "IPV6_TYPE" | grep -q "local"; then
        to_allow+=( "${net}" )
      fi
    done
  fi
fi

# RPC_ALLOWIP, comma separated string of one or more IPs/subnets, no spaces, valid are a single IP (e.g. 1.2.3.4),
# a network/netmask (e.g. 1.2.3.4/255.255.255.0) or a network/CIDR (e.g. 1.2.3.4/24).
# Example: -e RPC_ALLOWIP="10.10.10.1,192.168.0.1/24,192.168.1.1/255.255.255.0"
to_append=()
if [ -n "${RPC_ALLOWIP:-}" ]; then
  mapfile -t to_append <<< "$(tr ',' '\n' <<< "${RPC_ALLOWIP}")"
  to_allow+=( "${to_append[@]}" )
fi

# Set rpcallowip= in zen.conf
if (( ${#to_allow[@]} )); then
  sed -i '/^rpcallowip/d' "${HOME}/.zen/zen.conf" "${HOME}/.zen/testnet3/zen.conf"
  echo -e "Allowing RPC access from: ${to_allow[*]}\n"
  for net in "${to_allow[@]}"; do
    echo "rpcallowip=${net}" | tee -a "${HOME}/.zen/zen.conf" >> "${HOME}/.zen/testnet3/zen.conf"
  done
fi

# EXTERNAL_IP, comma separated string of one or more of IPv4, IPv6 or the string "DETECT", no spaces.
# Example: -e EXTERNAL_IP="DETECT,1.1.1.1,2606:4700:4700::1111"
external=()
if [ -n "${EXTERNAL_IP:-}" ]; then
  mapfile -t external <<< "$(tr ',' '\n' <<< "${EXTERNAL_IP}")"
  for i in "${!external[@]}"; do
    if [ "${external[i]}" = "DETECT" ]; then
      unset 'external[i]'
      mapfile -t -O "${#external[@]}" external < <(dig -4 +short +time=2 @resolver1.opendns.com A myip.opendns.com | grep -v ";" || true)
      mapfile -t -O "${#external[@]}" external < <(dig -6 +short +time=2 @resolver1.opendns.com AAAA myip.opendns.com  | grep -v ";" || true)
    fi
  done
fi

# Set externalip= in zen.conf
if (( ${#external[@]} )); then
  sed -i '/^externalip/d' "${HOME}/.zen/zen.conf" "${HOME}/.zen/testnet3/zen.conf"
  echo -e "Setting externalip to: ${external[*]}\n"
  for ip in "${external[@]}"; do
    echo "externalip=${ip}" | tee -a "${HOME}/.zen/zen.conf" >> "${HOME}/.zen/testnet3/zen.conf"
  done
fi

# ADDNODE comma separated string of one or more nodes to try to connect to in format IPv4:PORT, [IPv6]:PORT or FQDN:PORT, no spaces.
# Example: ADDNODE="1.1.1.1:9033,[2606:4700:4700::1111]:9033,mainnet.horizen.global:9033"

# Set addnode= in zen.conf
addnode=()
if [ -n "${ADDNODE:-}" ]; then
  sed -i '/^addnode/d' "${HOME}/.zen/zen.conf" "${HOME}/.zen/testnet3/zen.conf"
  mapfile -t addnode <<< "$(tr ',' '\n' <<< "${ADDNODE}")"
  echo -e "Adding addnode= for: ${addnode[*]}\n"
  for node in "${addnode[@]}"; do
    echo "addnode=${node}" | tee -a "${HOME}/.zen/zen.conf" >> "${HOME}/.zen/testnet3/zen.conf"
  done
fi

# TLS_KEY_PATH path to SSL private key inside of the container
# Example: TLS_KEY_PATH="/home/user/.zen/ssl.key"

# Set tlskeypath= in zen.conf
if [ -n "${TLS_KEY_PATH:-}" ]; then
  [ -f "${TLS_KEY_PATH}" ] || { echo "Error: no TLS key file found at ${TLS_KEY_PATH}"; sleep 5; exit 1; }
  sed -i '/^tlskeypath/d' "${HOME}/.zen/zen.conf" "${HOME}/.zen/testnet3/zen.conf"
  echo "tlskeypath=${TLS_KEY_PATH}" | tee -a "${HOME}/.zen/zen.conf" >> "${HOME}/.zen/testnet3/zen.conf"
fi

# TLS_CERT_PATH path to SSL certificate inside of the container
# Example: TLS_CERT_PATH="/home/user/.zen/ssl.crt"

# Set tlscertpath= in zen.conf
if [ -n "${TLS_CERT_PATH:-}" ]; then
  [ -f "${TLS_CERT_PATH}" ] || { echo "Error: no TLS cert file found at ${TLS_CERT_PATH}"; sleep 5; exit 1; }
  sed -i '/^tlscertpath/d' "${HOME}/.zen/zen.conf" "${HOME}/.zen/testnet3/zen.conf"
  echo "tlscertpath=${TLS_CERT_PATH}" | tee -a "${HOME}/.zen/zen.conf" >> "${HOME}/.zen/testnet3/zen.conf"
fi

# Fix ownership of the created files/folders
find "${mountpoints[@]}" -writable -print0 | xargs -0 -I{} -P64 -n1 chown -f "${CURRENT_UID}":"${CURRENT_GID}" "{}"

# CUSTOM_SCRIPT, execute user provided script before starting zend, e.g. to backup wallets
if [ -n "${CUSTOM_SCRIPT:-}" ]; then
  chmod +x "${CUSTOM_SCRIPT}"
  echo "Running custom script: ${CUSTOM_SCRIPT}"
  bash -c "${CUSTOM_SCRIPT}"
fi

# convert $OPTS into array
mapfile -t OPTS < <(sed 's/  */ /g; s/ $//g' <<< "${OPTS}" | tr ' ' '\n')

gosu_cmd=""
[ "${CURRENT_UID}" -ne 0 ] && gosu_cmd="/usr/local/bin/gosu user"
if [ "$1" = "zend" ]; then
  $gosu_cmd zen-fetch-params
  for arg in "${OPTS[@]}"; do
    set -- "$@" "${arg}"
  done
fi
exec $gosu_cmd "$@"
