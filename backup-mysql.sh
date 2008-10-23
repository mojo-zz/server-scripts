#!/bin/bash

# TODO read these from argv
MYSQLDUMP_OPTS=/home/backup/conf/mysqldump.opts
BACKUP_DIR=/home/backup/mysql
MAX_BACKUPS=14
S3_BUCKET=ovc-backup
S3_PREFIX=mysql

error() {
  echo "$@" >&2
  exit 1
}

# create new backup
umask 0027 || error "Failed to set umask"
timestamp=`date +%Y%m%d%H%M%S` || error "Failed to compute timestamp"
newbackup="$BACKUP_DIR"/"$timestamp".sql.gz
xargs mysqldump <"$MYSQLDUMP_OPTS" | gzip >"$newbackup" \
  || error "Failed to create new backup $newbackup"
echo Created new backup "$newbackup".

# delete old backups if there are too many
current=`find "$BACKUP_DIR" -type f -name '*.sql.gz' | wc -l` \
  || error "Failed to check number of current backups"
excess=$[current - MAX_BACKUPS]
echo Out of max $MAX_BACKUPS backups we have $current.
if [ $excess -gt 0 ]; then
  echo Deleting $excess oldest backups.
  pushd "$BACKUP_DIR" >/dev/null # shush
  ls -cr | head -$excess | xargs rm -f \
    || { popd >/dev/null; error "Failed to delete $excess oldest backups"; }
  popd >/dev/null
fi

echo Total disk space in bytes occupied by MySQL backups: `du -h "$BACKUP_DIR" | awk '{print $1}'`

echo Syncing to Amazon S3...
# no --delete here, may as well keep older backups
s3sync --ssl --recursive "$BACKUP_DIR"/ "$S3_BUCKET":"$S3_PREFIX" \
  || error "Failed to sync to S3 ($BACKUP_DIR/ $S3_BUCKET:$S3_PREFIX)"

echo Backup complete.
