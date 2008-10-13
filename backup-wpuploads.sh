#!/bin/bash

SRC_DIR=/var/www/ovcblog/shared/uploads
BACKUP_DIR=/home/backup/wpuploads
BACKUP_BASENAME=backup
MAX_BACKUPS=14
S3_BUCKET=ovc-backup
S3_PREFIX=wpuploads

error() {
  echo "$@" >&2
  exit 1
}

backup_prefix="$BACKUP_DIR"/"$BACKUP_BASENAME"

echo Rotating backups...
oldest="$backup_prefix".$[MAX_BACKUPS - 1]
if [ -d "$oldest" ]; then
  echo Deleting "$oldest".
  rm -rf "$oldest" || error "Unable to delete oldest backup $oldest"
fi

working=$[MAX_BACKUPS - 2]
while [ $working -ge 0 ]; do
  if [ -d "$backup_prefix".$working ]; then
    mv "$backup_prefix".$working "$backup_prefix".$[working + 1] \
      || error "Unable to rename backup $working to " $[working + 1]
  fi
  working=$[working - 1]
done

echo Creating new backup "$backup_prefix".0...
rsync -a --delete --link-dest="$backup_prefix".1 "$SRC_DIR" "$backup_prefix".0 \
  || error "Unable to create new backup $backup_prefix.0"

echo Total disk space in bytes occupied by wpuploads backups: `du -hs "$BACKUP_DIR" | awk '{print $1}'`

echo Syncing to Amazon S3...
s3sync --delete --ssl --recursive "$BACKUP_DIR"/ "$S3_BUCKET":"$S3_PREFIX" \
  || error "Failed to sync to S3 ($BACKUP_DIR/ $S3_BUCKET:$S3_PREFIX)"

echo Backup complete.
