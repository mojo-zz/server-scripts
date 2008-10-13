#!/bin/bash

# TODO read these from argv
MYSQLDUMP_OPTS=/home/backup/conf/mysqldump.opts
BACKUP_DIR=/home/backup/mysql
MAX_BACKUPS=14

error() {
  echo "$@" >&2
  exit 1
}

# create new backup
umask 0027 || error "Failed to set umask"
timestamp=`date +%Y%m%d%H%M%S` \
  || error "Failed to compute timestamp"
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
  ls -cr "$BACKUP_DIR"/ | head -$excess | xargs rm -f \
    || error "Failed to delete $excess oldest backups"
fi

echo Backup complete.