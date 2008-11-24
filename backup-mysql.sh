#!/bin/bash

# TODO read these from argv
MAX_BACKUPS=14
S3_BUCKET=ovc-backup

error() {
  echo "$@" >&2
  exit 1
}


mysqldump_opts="${1?First argument must be path to mysqldump options file}"
test -r "$mysqldump_opts" || error "$mysqldump_opts does not exist or is not readable"
backup_dir="${2?Second argument must be path to backup directory}"
test -d "$backup_dir" || error "$backup_dir is not a directory"
s3_prefix="${3?Third argument must be S3 prefix in which to store backups}"

# create new backup
umask 0027 || error "Failed to set umask"
timestamp=`date +%Y%m%d%H%M%S` || error "Failed to compute timestamp"
newbackup="$backup_dir"/"$timestamp".sql.gz
xargs mysqldump <"$mysqldump_opts" | gzip >"$newbackup" \
  || error "Failed to create new backup $newbackup"
echo Created new backup "$newbackup".

# delete old backups if there are too many
current=`find "$backup_dir" -type f -name '*.sql.gz' | wc -l` \
  || error "Failed to check number of current backups"
excess=$[current - MAX_BACKUPS]
echo Out of max $MAX_BACKUPS backups we have $current.
if [ $excess -gt 0 ]; then
  echo Deleting $excess oldest backups.
  pushd "$backup_dir" >/dev/null # shush
  ls -cr | head -$excess | xargs rm -f \
    || { popd >/dev/null; error "Failed to delete $excess oldest backups"; }
  popd >/dev/null
fi

echo Total disk space in bytes occupied by MySQL backups: `du -h "$backup_dir" | awk '{print $1}'`

echo Syncing to Amazon S3...
# no --delete here, may as well keep older backups
s3sync --ssl --recursive "$backup_dir"/ "$S3_BUCKET":"$s3_prefix" \
  || error "Failed to sync to S3 ($backup_dir/ $S3_BUCKET:$s3_prefix)"

echo Backup complete.
