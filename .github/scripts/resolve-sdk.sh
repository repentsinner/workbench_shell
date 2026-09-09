#!/usr/bin/env bash
# Resolve the Flutter version for one `quality.yml` matrix leg.
#
# Neither version is written into the workflow. `floor` is the oldest SDK
# pubspec.yaml claims to support and `pinned` is the toolchain .fvmrc names,
# so each value keeps exactly one home and a bump to either file carries into
# CI with no second edit. An unreadable version fails the job rather than
# silently handing the action an empty input, which would resolve to the
# newest stable and quietly stop testing the floor.
set -euo pipefail

case "${MATRIX_SDK:?MATRIX_SDK not set}" in
  floor)
    source_file=pubspec.yaml
    # environment.flutter, e.g. `  flutter: ">=3.38.1"`. Matching on `>=`
    # anchors this to the constraint: the `dependencies:` entry and the
    # top-level `flutter:` section carry no version.
    version=$(sed -n \
      's/^[[:space:]]*flutter:[[:space:]]*"\{0,1\}>=[[:space:]]*\([0-9][0-9.]*\).*/\1/p' \
      "$source_file" | head -n1)
    ;;
  pinned)
    source_file=.fvmrc
    version=$(sed -n \
      's/.*"flutter"[[:space:]]*:[[:space:]]*"\([0-9][0-9.]*\)".*/\1/p' \
      "$source_file" | head -n1)
    ;;
  *)
    echo "::error::unknown matrix sdk '${MATRIX_SDK}'"
    exit 1
    ;;
esac

if [ -z "$version" ]; then
  echo "::error::no Flutter version found in ${source_file} for '${MATRIX_SDK}'"
  exit 1
fi

echo "${MATRIX_SDK} -> ${version} (from ${source_file})"
echo "version=${version}" >> "${GITHUB_OUTPUT:-/dev/stdout}"
