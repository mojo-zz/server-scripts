#!/bin/bash

BACKUP_BASENAME=backup
MAX_BACKUPS=14
S3_BUCKET=ovc-backup

error() {
  echo "$@" >&2
  exit 1
}


src_dir="${1?First argument must be the directory to backup}"
test -d "$src_dir" || error "$src_dir is not a directory"
backup_dir="${2?Second argument must be path to backup directory}"
test -d "$backup_dir" || error "$backup_dir is not a directory"
s3_prefix="${3?Third argument must be S3 prefix in which to store backups}"

backup_prefix="$backup_dir"/"$BACKUP_BASENAME"

timestamp=`date +%Y%m%d%H%M%S` || error "Failed to compute timestamp"
newbackup="$backup_prefix"."$timestamp"
prevbackup=`ls -c "$backup_dir"/ | head -1`
prevbackup_full="$backup_dir"/"$prevbackup"

rsync_opts="-a --delete"

echo Beginning backup of "$src_dir".

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

rsync $rsync_opts "$src_dir" "$newbackup" \
  || error "Unable to create new backup $newbackup"
echo Created new backup "$newbackup".

/usr/local/bin/rotate-backups.sh $MAX_BACKUPS "$backup_dir" "$BACKUP_BASENAME.*" d \
  || error "Rotating backups failed."

/usr/local/bin/sync-to-s3.sh "$S3_BUCKET" "$s3_prefix" "$backup_dir" \
  || error "Syncing to Amazon S3 failed."

echo Backup complete.
