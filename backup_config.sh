#!/usr/bin/env bash

CONTAINER_NAME=unifi-trixie

BACKUP_FOLDER=$(dirname $0)/unifi_backup
mkdir -pv $BACKUP_FOLDER

TEMP_FOLDER=/tmp/$$
mkdir -pv $TEMP_FOLDER

incus file pull $CONTAINER_NAME/var/lib/unifi/backup/autobackup $TEMP_FOLDER -prv
cp -v $TEMP_FOLDER/autobackup/*.unf $BACKUP_FOLDER

rm -rfv $TEMP_FOLDER
