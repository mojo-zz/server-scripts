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

timestamp=`date +%Y%m%d%H%M%S` || error "Failed to compute timestamp"
newbackup="$backup_prefix"."$timestamp"
prevbackup=`ls -c "$BACKUP_DIR"/ | head -1`
prevbackup_full="$BACKUP_DIR"/"$prevbackup"

rsync_opts="-a --delete"

if [ -z "$prevbackup" ]; then
  echo WARNING: no previous backup found. >&2
  echo This backup will be a full copy. >&2
elif [ ! -d "$prevbackup_full" ]; then
  echo WARNING: previous backup $prevbackup_full not a directory. >&2
  echo This backup will be a full copy. >&2
else
  echo Using hard links from previous backup $prevbackup_full where possible.
  rsync_opts="$rsync_opts --link-dest=$prevbackup_full"
fi

rsync $rsync_opts "$SRC_DIR" "$newbackup" \
  || error "Unable to create new backup $newbackup"
echo Created new backup "$newbackup".

# delete old backups if there are too many
current=`find "$BACKUP_DIR" -type d -name "$BACKUP_BASENAME.*" | wc -l` \
  || error "Failed to check number of current backups"
excess=$[current - MAX_BACKUPS]
echo Out of max $MAX_BACKUPS backups we have $current.
if [ $excess -gt 0 ]; then
  echo Deleting $excess oldest backups.
  pushd "$BACKUP_DIR" >/dev/null # shush
  ls -cr | head -$excess | xargs rm -rf \
    || { popd >/dev/null; error "Failed to delete $excess oldest backups"; }
  popd >/dev/null
fi

echo Total disk space in bytes occupied by wpuploads backups: `du -hs "$BACKUP_DIR" | awk '{print $1}'`

echo Syncing to Amazon S3...
# no --delete here, may as well keep older backups
s3sync --ssl --recursive "$BACKUP_DIR"/ "$S3_BUCKET":"$S3_PREFIX" \
  || error "Failed to sync to S3 ($BACKUP_DIR/ $S3_BUCKET:$S3_PREFIX)"

echo Backup complete.
