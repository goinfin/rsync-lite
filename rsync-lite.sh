#!/usr/bin/env bash
set -euo pipefail
# rsync-lite.sh - mirror + versions of changes throgh rsync --backup/--backup-dir
# Requirements: rsync 3.x, bash, coreutils, findutils

usage() {
  cat <<'EOF'
Usage:
  rsync-lite.sh -s /path/src -d /path/dest [-e excludes.txt] [-n] [-v]
    -s path to the source directory
    -d path to the directory-storage (_current and _version will be created)
    -e path to the exclusion file (patterns like in rsync --exclude-from)
    -n dry run (nothing change, only show the plan)
    -v detailed output
    -h help

Example:
    ./rsync-lite.sh -s ~/data -d /mnt/backup/myhost -x exclude.txt -v
EOF
}

log() { printf '[%(%F %T)T] %s\n' -1 "$*"; }
fatal() { log "ERROR: $*"; exit 1; }

SRC='' DEST='' EXCLUDES='' DRY=0 VERB=0

# parsing of script's arguments
while getopts ":s:d:x:nvh" opt; do
  case "$opt" in
    s) SRC="$OPTARG" ;;
    d) DEST="$OPTARG" ;;
    x) EXCLUDES="$OPTARG" ;;
    n) DRY=1 ;;
    v) VERB=1 ;;
    h) usage; exit 0 ;;
    \?) usage; fatal "unknown option -$OPTARG" ;;
    :) usage; fatal "option -$OPTARG requires an argument" ;;
  esac
done

# input validation
[[ -z "$SRC" || -z "$DEST" ]] && { usage; fatal "required -s and -d"; }
[[ -d "$SRC" ]] || fatal "SOURCE not a directory: $SRC"
command -v rsync >/dev/null || fatal "rsync not found"

# path normalization
SRC="$(realpath -e "$SRC")"
DEST="$(realpath -m "$DEST")"

# create snapshot's structure
STAMP="$(date +%F_%H-%M-%S)"
CUR="$DEST/current"
VERS="$DEST/_versions/$STAMP"

mkdir -p "$CUR" "$VERS"

# building rsync options
OPTS=(-a --delete --backup --backup-dir="$VERS" --human-readable --stats)
[[ -n "$EXCLUDES" ]] && OPTS+=(--exclude-from="$EXCLUDES")
(( VERB )) && OPTS+=(-v)
(( DRY )) && OPTS+=(-n)

log "Sync: $SRC -> $CUR"
rsync "${OPTS[@]}" "$SRC"/ "$CUR"/
log "Done. Mirror: $CUR ; changed/deleted stored in: $VERS"

