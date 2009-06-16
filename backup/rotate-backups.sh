#!/bin/bash

error() { echo "$@" >&2; exit 1; }

max_backups="${1?First argument must be max number of backups to keep}"
test "$max_backups" -gt 0 || error "$max_backups must be a valid number of backups"
backup_dir="${2?Second argument must be path to backup directory}"
test -d "$backup_dir" || error "$backup_dir is not a directory"
backup_pat="${3?Third argument must be backup filename pattern (use 'single quotes')}"
backup_filetype="${4?Fourth argument must be backup filetype (as 'find -type')}"

function find_backups() {
  find "$backup_dir" -type "$backup_filetype" -name "$backup_pat" \
    || error "Failed to check number of current backups"
}

function num_backups() {
  find_backups | wc -l
}

function size_of_backups() {
  du -hs "$backup_dir" | awk '{print $1}' \
    || error "Failed to get total size of all backups in bytes"
}

echo "Rotating backups in $backup_dir; keeping max $max_backups."

# delete old backups if there are too many
current=`num_backups`
excess=$[current - max_backups]
echo $backup_dir contains $current backups, occupying `size_of_backups` bytes.
if [ $excess -gt 0 ]; then
  echo Deleting $excess oldest backups.
  find_backups | xargs ls -dcr | head -$excess | xargs rm -rf \
    || error "Failed to delete $excess oldest backups"
fi

echo `num_backups` backups remain in $backup_dir, occupying `size_of_backups` bytes.
