#!/bin/bash

error() { echo "$@" >&2; exit 1; }

s3_bucket="${1?First argument must be Amazon S3 bucket name}"
s3_prefix="${2?Second argument must be S3 prefix in which to store backups}"
backup_dir="${3?Third argument must be path to backup directory}"
test -d "$backup_dir" || error "$backup_dir is not a directory"

echo "Syncing $backup_dir to Amazon S3 ($s3_bucket:$s3_prefix)"...

# no --delete here, may as well keep older backups
s3sync --ssl --recursive "$backup_dir"/ "$s3_bucket":"$s3_prefix" \
  || error "Failed to sync to S3 ($backup_dir/ $S3_BUCKET:$s3_prefix)"

echo "Synced $backup_dir to Amazon S3 ($s3_bucket:$s3_prefix)."
