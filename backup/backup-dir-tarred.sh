#!/bin/bash

error() { echo "$@" >&2; exit 1; }

src_dir="${1?First argument must be the directory to backup}"
test -d "$src_dir" || error "$src_dir is not a directory"
backup_dir="${2?Second argument must be path to backup directory}"
test -d "$backup_dir" || error "$backup_dir is not a directory"

umask 0027 || error "Failed to set umask"
timestamp=`date +%Y%m%d%H%M%S` || error "Failed to compute timestamp"
newbackup="$backup_dir"/"$timestamp".tar.gz

echo "Backing up $src_dir to $newbackup..."
# Reason for stderr redirection and sed is that tar spits out a warning on
# stderr if the source dir is an absolute path.  That warning is uninteresting,
# but we want to hear anything else tar might say on stderr.
tar czf "$newbackup" "$src_dir" 2>&1 | sed '/leading .\/./d' >&2 \
  || error "Failed to create new backup $newbackup"
echo "Backed up $src_dir to $newbackup."
