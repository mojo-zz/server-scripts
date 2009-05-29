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

/usr/local/bin/rotate-backups.sh $MAX_BACKUPS "$backup_dir" "*.sql.gz" f \
  || error "Rotating backups failed."

/usr/local/bin/sync-to-s3.sh "$S3_BUCKET" "$s3_prefix" "$backup_dir" \
  || error "Syncing to Amazon S3 failed."

echo Backup complete.
