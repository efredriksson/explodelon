#!/usr/bin/env bash

# Place this script in /recalbox/share/system on your recal box system. It will
# then update explodelon to latest version at startup if it can connect to github.
# You have to restart recalbox for the new version to end up in the gamelist.xml.

TIMEOUT=180
while ! ping -c 1 -W 1 api.github.com; do
    echo "Waiting for api.github.com - network might not be connected"
    sleep 1

    TIMEOUT=$((TIMEOUT-1))
    if [ $TIMEOUT -eq 0 ]; then
        echo "timed out waiting for network connection"
        exit 1
    fi
done

echo "OK, network is up!"

ROM_DIR=/recalbox/share/roms/lutro
DOWNLOAD_LINK="$(curl -s https://api.github.com/repos/efredriksson/explodelon/releases/latest \
| grep "browser_download_url.*lutro" \
| cut -d : -f 2,3 \
| tr -d \" \
)"
GAME_NAME_AND_VERISON="$(echo ${DOWNLOAD_LINK} | xargs -- basename)"

# Download game to ROM folder:
mkdir -p ${ROM_DIR}
wget -O ${ROM_DIR}/${GAME_NAME_AND_VERISON} ${DOWNLOAD_LINK}
