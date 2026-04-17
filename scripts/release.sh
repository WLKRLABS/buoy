#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHANGELOG_FILE="$ROOT_DIR/CHANGELOG.md"
VERSION_FILE="$ROOT_DIR/VERSION"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/release.sh prepare <version> [--date YYYY-MM-DD] [--install] [--allow-dirty]
  ./scripts/release.sh tag

Commands:
  prepare  Move the current Unreleased changelog entries into a new release section,
           update VERSION, and run the release validation/build flow.
  tag      Validate the current release commit and create the annotated git tag for VERSION.

Options for prepare:
  --date YYYY-MM-DD  Override the release date. Defaults to today's local date.
  --install          Run ./install.sh after successful packaging.
  --allow-dirty      Allow a dirty worktree before release prep.
EOF
}

die() {
  echo "$*" >&2
  exit 1
}

ensure_git_repo() {
  git -C "$ROOT_DIR" rev-parse --git-dir >/dev/null 2>&1 || die "This command must be run from a git checkout."
}

require_clean_worktree() {
  local status_output
  status_output="$(git -C "$ROOT_DIR" status --short)"

  if [[ -n "$status_output" ]]; then
    echo "Worktree must be clean before running this command:" >&2
    printf '%s\n' "$status_output" >&2
    exit 1
  fi
}

ensure_semver() {
  local version="$1"
  [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "Version must be plain SemVer in X.Y.Z form."
}

ensure_valid_date() {
  local release_date="$1"
  date -j -f "%F" "$release_date" "+%F" >/dev/null 2>&1 || die "Date must be in YYYY-MM-DD form."
}

semver_gt() {
  local lhs_major lhs_minor lhs_patch rhs_major rhs_minor rhs_patch

  IFS=. read -r lhs_major lhs_minor lhs_patch <<<"$1"
  IFS=. read -r rhs_major rhs_minor rhs_patch <<<"$2"

  if (( lhs_major > rhs_major )); then
    return 0
  fi
  if (( lhs_major < rhs_major )); then
    return 1
  fi

  if (( lhs_minor > rhs_minor )); then
    return 0
  fi
  if (( lhs_minor < rhs_minor )); then
    return 1
  fi

  (( lhs_patch > rhs_patch ))
}

current_version() {
  "$ROOT_DIR/scripts/version.sh" version
}

ensure_tag_absent() {
  local tag_name="$1"
  if git -C "$ROOT_DIR" rev-parse -q --verify "refs/tags/$tag_name" >/dev/null 2>&1; then
    die "Tag $tag_name already exists."
  fi
}

print_changelog_head() {
  awk '
    { print }
    /^## \[Unreleased\]/ { exit }
  ' "$CHANGELOG_FILE"
}

print_unreleased_body() {
  awk '
    /^## \[Unreleased\]/ { in_unreleased=1; next }
    in_unreleased && /^## / { exit }
    in_unreleased { print }
  ' "$CHANGELOG_FILE"
}

print_trimmed_unreleased_body() {
  print_unreleased_body | awk '
    { lines[NR] = $0 }
    END {
      start = 1
      while (start <= NR && lines[start] ~ /^[[:space:]]*$/) {
        start++
      }

      end = NR
      while (end >= start && lines[end] ~ /^[[:space:]]*$/) {
        end--
      }

      for (i = start; i <= end; i++) {
        print lines[i]
      }
    }
  '
}

print_changelog_tail() {
  awk '
    /^## \[Unreleased\]/ { in_unreleased=1; next }
    in_unreleased && /^## / { printing=1 }
    printing { print }
  ' "$CHANGELOG_FILE"
}

ensure_changelog_ready() {
  [[ -f "$CHANGELOG_FILE" ]] || die "CHANGELOG.md is missing."
  grep -Eq '^## \[Unreleased\]' "$CHANGELOG_FILE" || die "CHANGELOG.md must contain an [Unreleased] section."
}

ensure_unreleased_has_entries() {
  print_unreleased_body | awk '
    /^[[:space:]]*$/ { next }
    /^### / { next }
    { found = 1 }
    END { exit found ? 0 : 1 }
  ' || die "The [Unreleased] section is empty. Add release notes before preparing a release."
}

write_release_changelog() {
  local version="$1"
  local release_date="$2"
  local temp_file

  temp_file="$(mktemp)"

  {
    print_changelog_head
    printf '\n'
    cat <<'EOF'
### Added

### Changed

### Fixed

### Removed
EOF
    printf '\n\n'
    printf '## [%s] - %s\n\n' "$version" "$release_date"
    print_trimmed_unreleased_body
    printf '\n\n'
    print_changelog_tail
  } > "$temp_file"

  mv "$temp_file" "$CHANGELOG_FILE"
}

write_version() {
  printf '%s\n' "$1" > "$VERSION_FILE"
}

run_step() {
  echo "==> $*"
  "$@"
}

prepare_release() {
  local version="${1:-}"
  shift || true

  local release_date
  local should_install=0
  local allow_dirty=0
  local current

  [[ -n "$version" ]] || die "prepare requires a target version."
  ensure_semver "$version"

  release_date="$(date +%F)"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --date)
        shift
        [[ $# -gt 0 ]] || die "--date requires a value."
        release_date="$1"
        ;;
      --install)
        should_install=1
        ;;
      --allow-dirty)
        allow_dirty=1
        ;;
      *)
        die "Unknown prepare option: $1"
        ;;
    esac
    shift
  done

  ensure_git_repo
  if [[ "$allow_dirty" != "1" ]]; then
    require_clean_worktree
  fi

  ensure_valid_date "$release_date"
  ensure_changelog_ready
  ensure_unreleased_has_entries

  current="$(current_version)"
  semver_gt "$version" "$current" || die "Release version $version must be greater than current version $current."

  grep -Eq "^## \\[$version\\]" "$CHANGELOG_FILE" && die "CHANGELOG.md already has a section for version $version."
  ensure_tag_absent "v$version"

  write_release_changelog "$version" "$release_date"
  write_version "$version"

  run_step bash "$ROOT_DIR/scripts/validate-versioning.sh"
  run_step "$ROOT_DIR/scripts/smoke-test.sh"
  run_step "$ROOT_DIR/scripts/build-cli.sh"
  run_step "$ROOT_DIR/scripts/build-app.sh"
  run_step "$ROOT_DIR/scripts/package-release.sh"
  run_step "$ROOT_DIR/scripts/render-release-notes.sh"

  if [[ "$should_install" == "1" ]]; then
    run_step "$ROOT_DIR/install.sh"
  fi

  cat <<EOF
Release prep complete for v$version.

Next steps:
  git add VERSION CHANGELOG.md
  git commit -m "release: v$version"
  ./scripts/release.sh tag
EOF
}

tag_release() {
  local version
  local tag_name
  local expected_subject
  local actual_subject
  local current_branch

  ensure_git_repo
  require_clean_worktree

  version="$(current_version)"
  tag_name="v$version"
  expected_subject="release: $tag_name"
  actual_subject="$(git -C "$ROOT_DIR" log -1 --pretty=%s)"

  run_step bash "$ROOT_DIR/scripts/validate-versioning.sh"
  ensure_tag_absent "$tag_name"

  [[ "$actual_subject" == "$expected_subject" ]] || die "HEAD commit subject must be '$expected_subject' before tagging. Found '$actual_subject'."

  run_step git -C "$ROOT_DIR" tag -a "$tag_name" -m "$tag_name"

  current_branch="$(git -C "$ROOT_DIR" branch --show-current)"

  cat <<EOF
Created tag $tag_name.

Next steps:
  git push origin ${current_branch:-HEAD}
  git push origin $tag_name
EOF
}

command="${1:-}"

case "$command" in
  prepare)
    shift || true
    prepare_release "$@"
    ;;
  tag)
    shift || true
    [[ $# -eq 0 ]] || die "tag does not accept extra arguments."
    tag_release
    ;;
  --help|-h|help)
    usage
    ;;
  *)
    usage >&2
    exit 1
    ;;
esac
