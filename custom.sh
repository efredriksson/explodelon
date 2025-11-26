#!/usr/bin/env bash

# Place this script in /recalbox/share/system on your recal box system. It will
# then update explodelon to latest version at startup if it can connect to github.
# You have to restart recalbox for the new version to end up in the gamelist.xml.

ROM_DIR=/recalbox/share/roms/lutro
GITHUB_LATEST_RELEASE_URL=https://api.github.com/repos/efredriksson/explodelon/releases/latest
mkdir -p ${ROM_DIR}
LOG_FILE=${ROM_DIR}/update_log.txt

if [[ ! $1 =~ "start" ]]; then
    echo "Will do nothing, only do updates at startup" >> $LOG_FILE
    exit 0
fi

TIMEOUT=180
while ! curl -s ${GITHUB_LATEST_RELEASE_URL}; do
    echo "Waiting for api.github.com - network might not be connected" >> $LOG_FILE
    sleep 1

    TIMEOUT=$((TIMEOUT-1))
    if [ $TIMEOUT -eq 0 ]; then
        echo "timed out waiting for network connection" >> $LOG_FILE
        exit 1
    fi
done

echo "OK, network is up!" >> $LOG_FILE


GITHUB_RELEASE_INFO="$(curl -s ${GITHUB_LATEST_RELEASE_URL})"
DOWNLOAD_LINK="$(curl -s ${GITHUB_LATEST_RELEASE_URL} \
| grep "browser_download_url.*lutro" \
| cut -d : -f 2,3 \
| tr -d \" \
)"
GAME_NAME_AND_VERISON="$(echo ${DOWNLOAD_LINK} | xargs -- basename)"
echo "Game filename is ${GAME_NAME_AND_VERISON}" >> $LOG_FILE

echo "Github info is ${GITHUB_RELEASE_INFO}" >> $LOG_FILE

# Download game to ROM folder:
echo "Will download it from ${DOWNLOAD_LINK} to ${ROM_DIR}/${GAME_NAME_AND_VERISON}" >> $LOG_FILE
wget -O ${ROM_DIR}/${GAME_NAME_AND_VERISON} ${DOWNLOAD_LINK}

echo "Update done!" >> $LOG_FILE
